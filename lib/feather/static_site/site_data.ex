defmodule Feather.StaticSite.SiteData do
  @moduledoc """
  Everything a static export or the preview renders, loaded once up front
  with the associations the templates use, and its diagrams rendered up
  front (`render_diagrams/2`). Rendering then works on this data alone,
  without touching the database or running d2, so it can run in parallel.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content, Diagrams, Media, Sites}
  alias Feather.Books.Book
  alias Feather.Content.{Blocks, Page, Post, Project}
  alias Feather.Media.Image
  alias Feather.Repo
  alias Feather.Sites.{NavigationItem, Site, SocialMediaLink}
  alias Feather.StaticSite.Themes

  defstruct [
    :site,
    :homepage,
    :now,
    posts: [],
    pages: [],
    projects: [],
    books: [],
    navigation: [],
    social_links: [],
    images: %{},
    books_by_public_id: %{},
    diagrams: %{}
  ]

  @type t :: %__MODULE__{
          site: Site.t(),
          homepage: Page.t() | nil,
          now: DateTime.t(),
          posts: [Post.t()],
          pages: [Page.t()],
          projects: [Project.t()],
          books: [Book.t()],
          navigation: [NavigationItem.t()],
          social_links: [SocialMediaLink.t()],
          images: %{String.t() => Image.t()},
          books_by_public_id: %{String.t() => Book.t()},
          diagrams: %{String.t() => String.t()}
        }

  @post_preloads [:header_image, :thumbnail_image, book: [:cover_image, :post]]
  @page_preloads [:header_image]
  @project_preloads [:header_image, :thumbnail_image]
  @book_preloads [:cover_image, :post]

  @doc """
  Loads the data of a site. `posts` are the posts whose `publish_at` has
  passed, newest first; `pages` are all pages, the homepage included; the
  navigation leaves out pages that are not among them; `now` is the time
  the site is exported at.

  ## Options

    * `:content` - `:published` (the default) shows each post, page and
      project as its published version and leaves drafts out (the
      export); `:current` shows the records as they are, unpublished
      changes and drafts included (the preview)
    * `:now` - the time that decides which posts are due and how old they
      are (default: now)
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
      site: Sites.preload_images(site),
      now: now,
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

  @doc """
  Renders the diagrams in the content of the posts, pages and projects and
  of `records` (`Feather.Diagrams.render_all/2`) into `diagrams`, the SVG
  file names by source. Diagrams that fail are left out and render as
  their source.
  """
  @spec render_diagrams(t(), [Post.t() | Page.t() | Project.t()]) :: t()
  def render_diagrams(%__MODULE__{} = data, records \\ []) do
    codes =
      Enum.flat_map(data.posts ++ data.pages ++ data.projects ++ records, fn record ->
        Blocks.diagram_codes(record.content)
      end)

    %{data | diagrams: Diagrams.render_all(codes)}
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
  The posts next to a post in the post list (newest first): `{newer, older}`,
  `nil` at either end and for posts not in the list.
  """
  @spec neighbours(t(), Post.t()) :: {Post.t() | nil, Post.t() | nil}
  def neighbours(%__MODULE__{posts: posts}, %Post{id: id}) do
    case Enum.find_index(posts, &(&1.id == id)) do
      nil -> {nil, nil}
      0 -> {nil, Enum.at(posts, 1)}
      index -> {Enum.at(posts, index - 1), Enum.at(posts, index + 1)}
    end
  end

  @doc """
  The images the exported site uses, without duplicates: the images
  embedded in the content of its posts, pages and projects, their header
  and thumbnail images, the book covers and the site images its theme
  renders (`c:Feather.StaticSite.Theme.site_image_fields/0`).
  """
  @spec images_in_use(t()) :: [Image.t()]
  def images_in_use(%__MODULE__{site: %Site{id: site_id}} = data) do
    records = data.posts ++ data.pages ++ data.projects
    embedded_ids = Enum.flat_map(records, &Blocks.image_ids(&1.content))

    referenced_ids =
      [
        Enum.map(records, &[&1.header_image_id, &1.thumbnail_image_id]),
        Enum.map(data.books, & &1.cover_image_id),
        site_image_ids(data.site)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Repo.all(
      from i in Image,
        where:
          i.site_id == ^site_id and
            (i.public_id in ^embedded_ids or i.id in ^referenced_ids)
    )
  end

  defp site_image_ids(%Site{} = site),
    do: Enum.map(Themes.module(site).site_image_fields(), &Map.fetch!(site, &1))
end
