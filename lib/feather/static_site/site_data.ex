defmodule Feather.StaticSite.SiteData do
  @moduledoc """
  Everything a static export renders, loaded once up front with the
  associations the templates use. Rendering then works on this data
  alone, without touching the database, so it can run in parallel.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Books.Book
  alias Feather.Content.{Page, Post, Project}
  alias Feather.Media.Image
  alias Feather.Repo
  alias Feather.Sites.{NavigationItem, Site, SocialMediaLink}
  alias Feather.{Books, Content, Media, Sites}

  defstruct [
    :site,
    :homepage,
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
  Loads the data of a site. `posts` are the published posts (as of `now`),
  newest first; `pages` are all pages, the homepage included.
  """
  @spec load(Site.t(), DateTime.t()) :: t()
  def load(%Site{} = site, now \\ DateTime.utc_now()) do
    scope = Scope.for_site(site)
    pages = scope |> Content.list_pages() |> Repo.preload(@page_preloads)
    books = scope |> Books.list_books() |> Repo.preload(@book_preloads)

    %__MODULE__{
      site: site,
      homepage: Enum.find(pages, &Page.homepage?/1),
      posts: scope |> Content.list_published_posts(now) |> Repo.preload(@post_preloads),
      pages: pages,
      projects: scope |> Content.list_projects() |> Repo.preload(@project_preloads),
      books: books,
      navigation: Sites.list_navigation_items(scope),
      social_links: Sites.list_social_media_links(scope),
      images: scope |> Media.list_images() |> Map.new(&{&1.public_id, &1}),
      books_by_public_id: Map.new(books, &{&1.public_id, &1})
    }
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
  The images the exported site uses: images embedded in content, header
  and thumbnail images of posts, pages and projects (drafts included, like
  Rails), and book covers. Without duplicates.
  """
  @spec images_in_use(t()) :: [Image.t()]
  def images_in_use(%__MODULE__{site: %Site{id: site_id}} = data) do
    embedded =
      Repo.all(
        from i in Image,
          where:
            i.site_id == ^site_id and
              (not is_nil(i.post_id) or not is_nil(i.page_id) or not is_nil(i.project_id))
      )

    post_images =
      Repo.all(
        from p in Post,
          where: p.site_id == ^site_id,
          select: [p.header_image_id, p.thumbnail_image_id]
      )

    referenced_ids =
      List.flatten([
        post_images,
        Enum.map(data.pages, &[&1.header_image_id, &1.thumbnail_image_id]),
        Enum.map(data.projects, &[&1.header_image_id, &1.thumbnail_image_id]),
        Enum.map(data.books, & &1.cover_image_id)
      ])
      |> Enum.reject(&is_nil/1)

    referenced =
      Repo.all(from i in Image, where: i.site_id == ^site_id and i.id in ^referenced_ids)

    Enum.uniq_by(embedded ++ referenced, & &1.id)
  end
end
