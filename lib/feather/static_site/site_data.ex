defmodule Feather.StaticSite.SiteData do
  @moduledoc """
  Everything a static export renders, loaded once up front with the
  associations the templates use. Rendering then works on this data
  alone, without touching the database, so it can run in parallel.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Books.Book
  alias Feather.Content.{Blocks, Page, Post, Project}
  alias Feather.Media.Image
  alias Feather.Repo
  alias Feather.Sites.{NavigationItem, Site, SocialMediaLink}
  alias Feather.{Books, Content, Media, Sites}

  defstruct [
    :site,
    :homepage,
    content: :published,
    posts: [],
    pages: [],
    projects: [],
    books: [],
    navigation: [],
    social_links: [],
    images: %{},
    books_by_public_id: %{}
  ]

  @type t :: %__MODULE__{
          site: Site.t(),
          homepage: Page.t() | nil,
          content: :published | :current,
          posts: [Post.t()],
          pages: [Page.t()],
          projects: [Project.t()],
          books: [Book.t()],
          navigation: [NavigationItem.t()],
          social_links: [SocialMediaLink.t()],
          images: %{String.t() => Image.t()},
          books_by_public_id: %{String.t() => Book.t()}
        }

  @post_preloads [:header_image, :thumbnail_image, book: [:cover_image, :post]]
  @page_preloads [:header_image]
  @project_preloads [:header_image, :thumbnail_image]
  @book_preloads [:cover_image, :post]

  @doc """
  Loads the data of a site. `posts` are the posts whose `publish_at` has
  passed, newest first; `pages` are all pages, the homepage included; the
  navigation leaves out pages that are not among them.

  ## Options

    * `:content` - `:published` (the default) shows each post, page and
      project as its published version and leaves drafts out (production
      and backup targets); `:current` shows the records as they are,
      unpublished changes and drafts included (staging and the preview)
    * `:now` - the time that decides which posts are due (default: now)
  """
  @spec load(Site.t(), keyword()) :: t()
  def load(%Site{} = site, opts \\ []) do
    content = Keyword.get(opts, :content, :published)
    now = Keyword.get(opts, :now, DateTime.utc_now())
    scope = Scope.for_site(site)

    posts =
      scope
      |> Content.list_posts()
      |> in_state(content)
      |> Enum.filter(&due?(&1, now))
      |> Enum.sort_by(& &1.publish_at, {:desc, DateTime})
      |> Repo.preload(@post_preloads)

    pages = scope |> Content.list_pages() |> in_state(content) |> Repo.preload(@page_preloads)

    projects =
      scope
      |> Content.list_projects()
      |> in_state(content)
      |> Enum.sort_by(&project_order/1)
      |> Repo.preload(@project_preloads)

    books =
      scope
      |> Books.list_books()
      |> Repo.preload(@book_preloads)
      |> Enum.map(&put_review(&1, posts))

    %__MODULE__{
      site: site,
      content: content,
      homepage: Enum.find(pages, &Page.homepage?/1),
      posts: posts,
      pages: pages,
      projects: projects,
      books: books,
      navigation: scope |> Sites.list_navigation_items() |> put_pages(pages),
      social_links: Sites.list_social_media_links(scope),
      images: scope |> Media.list_images() |> Map.new(&{&1.public_id, &1}),
      books_by_public_id: Map.new(books, &{&1.public_id, &1})
    }
  end

  defp in_state(records, :current), do: records
  defp in_state(records, :published), do: Content.as_published(records)

  # Like Content.list_projects/1, also for the published versions' fields:
  # most recently started first, then by title.
  defp project_order(%Project{started_at: nil, title: title}), do: {1, 0, title}

  defp project_order(%Project{started_at: started_at, title: title}),
    do: {0, -Date.to_gregorian_days(started_at), title}

  defp due?(%Post{publish_at: nil}, _now), do: false
  defp due?(%Post{publish_at: publish_at}, now), do: DateTime.compare(publish_at, now) != :gt

  # The review as the export shows it, if it is shown.
  defp put_review(%Book{post_id: post_id} = book, posts) do
    case Enum.find(posts, &(&1.id == post_id)) do
      nil -> book
      post -> %{book | post: post}
    end
  end

  defp put_pages(navigation, pages) do
    pages_by_id = Map.new(pages, &{&1.id, &1})

    for item <- navigation,
        Map.has_key?(pages_by_id, item.page_id),
        do: %{item | page: Map.fetch!(pages_by_id, item.page_id)}
  end

  @doc "Preloads what the templates need on a post, page or project."
  @spec preload(Post.t() | Page.t() | Project.t()) :: Post.t() | Page.t() | Project.t()
  def preload(%Post{} = post), do: Repo.preload(post, @post_preloads)
  def preload(%Page{} = page), do: Repo.preload(page, @page_preloads)
  def preload(%Project{} = project), do: Repo.preload(project, @project_preloads)

  @doc """
  Returns true if the post is one of the published posts of the data.
  """
  @spec published?(t(), Post.t()) :: boolean()
  def published?(%__MODULE__{posts: posts}, %Post{id: id}), do: Enum.any?(posts, &(&1.id == id))

  @doc """
  The images the exported site uses, without duplicates: the images
  embedded in the content of its posts, pages and projects, their header
  and thumbnail images, and the book covers.

  With `content: :current` (staging, preview) it also includes every image
  owned by a record and the header and thumbnail images of all posts,
  drafts included, like Rails.
  """
  @spec images_in_use(t()) :: [Image.t()]
  def images_in_use(%__MODULE__{site: %Site{id: site_id}} = data) do
    records = data.posts ++ data.pages ++ data.projects
    embedded_ids = Enum.flat_map(records, &Blocks.image_ids(&1.content))

    referenced_ids =
      [
        Enum.map(records, &[&1.header_image_id, &1.thumbnail_image_id]),
        Enum.map(data.books, & &1.cover_image_id)
        | current_only_ids(data)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Repo.all(
      from i in Image,
        where:
          i.site_id == ^site_id and
            (i.public_id in ^embedded_ids or i.id in ^referenced_ids or
               (^(data.content == :current) and
                  (not is_nil(i.post_id) or not is_nil(i.page_id) or not is_nil(i.project_id))))
    )
  end

  defp current_only_ids(%__MODULE__{content: :published}), do: []

  defp current_only_ids(%__MODULE__{content: :current, site: %Site{id: site_id}}) do
    Repo.all(
      from p in Post,
        where: p.site_id == ^site_id,
        select: [p.header_image_id, p.thumbnail_image_id]
    )
  end
end
