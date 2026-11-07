defmodule Feather.StaticSite.SiteData do
  @moduledoc """
  Everything a static export or the preview renders, loaded once up front
  with the associations the templates use, and its diagrams rendered and
  code highlighted up front (`prerender/2`). Rendering then works on this
  data alone, without touching the database or running d2 or chroma, so it
  can run in parallel.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content, Diagrams, Fediverse, Highlighting, Media, Ollama, Redirects}
  alias Feather.Books.Book
  alias Feather.Content.{Blocks, Page, Post, Project, RelatedPosts}
  alias Feather.Media.Image
  alias Feather.Redirects.Redirect
  alias Feather.Repo
  alias Feather.Sites
  alias Feather.Sites.{NavigationItem, Site, SocialMediaLink}
  alias Feather.StaticSite.Themes

  defstruct [
    :site,
    :homepage,
    :now,
    follower_count: 0,
    following_count: 0,
    posts: [],
    related: nil,
    replies: %{},
    member_replies: [],
    pages: [],
    projects: [],
    books: [],
    navigation: [],
    social_links: [],
    images: %{},
    books_by_public_id: %{},
    diagrams: %{},
    highlights: %{}
  ]

  @type t :: %__MODULE__{
          site: Site.t(),
          homepage: Page.t() | nil,
          now: DateTime.t(),
          follower_count: non_neg_integer(),
          following_count: non_neg_integer(),
          posts: [Post.t()],
          related: %{Ecto.UUID.t() => [Ecto.UUID.t()]} | nil,
          replies: %{Ecto.UUID.t() => [Feather.Fediverse.Mention.t()]},
          member_replies: [Feather.Fediverse.MemberReply.t()],
          pages: [Page.t()],
          projects: [Project.t()],
          books: [Book.t()],
          navigation: [NavigationItem.t()],
          social_links: [SocialMediaLink.t()],
          images: %{String.t() => Image.t()},
          books_by_public_id: %{String.t() => Book.t()},
          diagrams: %{String.t() => String.t()},
          highlights: %{{String.t(), term()} => String.t()}
        }

  @post_preloads [:header_image, :thumbnail_image, book: [:cover_image, :post]]
  @page_preloads [:header_image]
  @project_preloads [:header_image, :thumbnail_image]
  @book_preloads [:cover_image]

  @related_count 3
  # Enough to still show three after leaving out the newer and the older post.
  @ranked_count @related_count + 2

  @doc """
  Loads the data of a site. `posts` are the posts whose `publish_at` has
  passed, newest first; `related` is nil until `put_related_posts/1`;
  `pages` are all pages, the homepage included; a book's `post` is its
  review among `posts`, nil if it is none of them; the
  navigation leaves out pages that are not among them; `now` is the time
  the site is exported at; `follower_count` counts the followers of the
  site's fediverse account, `following_count` the accounts that accepted
  its follow; `replies` are the approved replies to the
  posts by post id, oldest first, with their authors and the members'
  public replies to them (`Feather.Fediverse.approved_replies/2`);
  `member_replies` are all public replies of members, which have a
  document.

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
    posts = load_posts(scope, content, now)
    pages = load_pages(scope, content)
    books = load_books(scope, posts)

    struct!(
      %__MODULE__{
        site: Sites.preload_images(site),
        now: now,
        homepage: Enum.find(pages, &Page.homepage?/1),
        posts: posts,
        pages: pages,
        projects: load_projects(scope, content),
        books: books,
        navigation: load_navigation(scope, pages),
        social_links: Sites.list_social_media_links(scope),
        images: load_images(scope),
        books_by_public_id: Map.new(books, &{&1.public_id, &1})
      },
      load_fediverse(scope, posts)
    )
  end

  defp load_fediverse(%Scope{site: site} = scope, posts) do
    if Fediverse.account?(site),
      do: %{
        follower_count: Fediverse.count_followers(scope),
        following_count: Fediverse.count_following(scope),
        replies: Fediverse.approved_replies(site, posts),
        member_replies: Fediverse.public_member_replies(site)
      },
      else: %{}
  end

  defp load_posts(scope, content, now) do
    scope
    |> Content.list_posts()
    |> in_state(content)
    |> Enum.filter(&Content.due?(&1, now))
    |> Enum.sort_by(& &1.publish_at, {:desc, DateTime})
    |> Repo.preload(@post_preloads)
  end

  defp load_pages(scope, content),
    do: scope |> Content.list_pages() |> in_state(content) |> Repo.preload(@page_preloads)

  defp load_projects(scope, content) do
    scope
    |> Content.list_projects()
    |> in_state(content)
    |> Enum.sort_by(&project_order/1)
    |> Repo.preload(@project_preloads)
  end

  defp load_books(scope, posts) do
    scope
    |> Books.list_books()
    |> Repo.preload(@book_preloads)
    |> Enum.map(&put_review(&1, posts))
  end

  defp load_navigation(scope, pages),
    do: scope |> Sites.list_navigation_items() |> put_pages(pages)

  @doc """
  The active redirects of the site of the data, each with the post, page
  or project of the data it leads to or its target path. One to a record
  the data leaves out is left out too.
  """
  @spec redirects(t()) :: [{Redirect.t(), Post.t() | Page.t() | Project.t() | String.t()}]
  def redirects(%__MODULE__{site: site} = data) do
    scope = Scope.for_site(site)
    records_by_id = Map.new(data.posts ++ data.pages ++ data.projects, &{&1.id, &1})

    scope
    |> Redirects.list_redirects()
    |> Enum.flat_map(fn redirect ->
      case shown_target(scope, redirect, records_by_id) do
        nil -> []
        target -> [{redirect, target}]
      end
    end)
  end

  defp shown_target(_scope, %Redirect{target_path: nil} = redirect, records_by_id),
    do: Map.get(records_by_id, Redirect.target_record(redirect).id)

  defp shown_target(scope, %Redirect{target_path: path} = redirect, _records_by_id),
    do: if(Redirects.active?(scope, redirect), do: path)

  defp load_images(scope), do: scope |> Media.list_images() |> Map.new(&{&1.public_id, &1})

  defp in_state(records, :current), do: Repo.preload(records, :published_version)
  defp in_state(records, :published), do: Content.as_published(records)

  # Like Content.list_projects/1, also for the published versions' fields:
  # most recently started first, then by title.
  defp project_order(%Project{started_at: nil, title: title}), do: {1, 0, title}

  defp project_order(%Project{started_at: started_at, title: title}),
    do: {0, -Date.to_gregorian_days(started_at), title}

  # The review as the data shows it, nil if it shows none.
  defp put_review(%Book{post_id: post_id} = book, posts),
    do: %{book | post: Enum.find(posts, &(&1.id == post_id))}

  defp put_pages(navigation, pages) do
    pages_by_id = Map.new(pages, &{&1.id, &1})

    for item <- navigation,
        Map.has_key?(pages_by_id, item.page_id),
        do: %{item | page: Map.fetch!(pages_by_id, item.page_id)}
  end

  @doc """
  Renders the diagrams and highlights the code blocks in the content of the
  posts, pages and projects and of `records`: `diagrams` gets the SVG file
  names by source (`Feather.Diagrams.render_all/2`), `highlights` the
  highlighted HTML by code and language
  (`Feather.Highlighting.highlight_all/2`). Diagrams that fail render as
  their source, code that is not highlighted as plain text.
  """
  @spec prerender(t(), [Post.t() | Page.t() | Project.t()]) :: t()
  def prerender(%__MODULE__{} = data, records \\ []) do
    contents = Enum.map(data.posts ++ data.pages ++ data.projects ++ records, & &1.content)

    %{
      data
      | diagrams: Diagrams.render_all(Enum.flat_map(contents, &Blocks.diagram_codes/1)),
        highlights: Highlighting.highlight_all(Enum.flat_map(contents, &Blocks.code_blocks/1))
    }
  end

  @doc "Preloads what the templates need on a post, page or project."
  @spec preload(Post.t() | Page.t() | Project.t()) :: Post.t() | Page.t() | Project.t()
  def preload(%Post{} = post), do: Repo.preload(post, @post_preloads)
  def preload(%Page{} = page), do: Repo.preload(page, @page_preloads)
  def preload(%Project{} = project), do: Repo.preload(project, @project_preloads)

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
  Ranks all posts once (`Feather.Content.RelatedPosts.all/3`) and keeps
  the ids of each post's best related posts in `related`, for an export
  that renders every post. The vectors themselves stay out of the data,
  which every render job gets a copy of.
  """
  @spec put_related_posts(t()) :: t()
  def put_related_posts(%__MODULE__{posts: posts} = data),
    do: %{data | related: RelatedPosts.all(posts, Ollama.embedding_model(), @ranked_count)}

  @doc """
  Up to three related posts of a post among the posts, best first, by the
  published versions (`Feather.Content.RelatedPosts`). The preview ranks
  the same versions among the posts it shows, so drafts and changed
  publish dates can change its list. Its newer and older post (`neighbours/2`),
  which the post navigation shows anyway, are left out. Without
  `put_related_posts/1` it ranks just this post. None for a draft, a post
  without an embedding and posts not in the list.
  """
  @spec related_posts(t(), Post.t()) :: [Post.t()]
  def related_posts(%__MODULE__{posts: posts} = data, %Post{} = post) do
    posts_by_id = Map.new(posts, &{&1.id, &1})
    {newer, older} = neighbours(data, post)
    shown = for %Post{id: id} <- [newer, older], do: id

    data
    |> ranked_ids(post)
    |> Enum.reject(&(&1 in shown))
    |> Enum.take(@related_count)
    |> Enum.map(&Map.fetch!(posts_by_id, &1))
  end

  defp ranked_ids(%__MODULE__{related: nil, posts: posts}, post),
    do: RelatedPosts.of(posts, post, Ollama.embedding_model(), @ranked_count)

  defp ranked_ids(%__MODULE__{related: related}, %Post{id: id}), do: Map.get(related, id, [])

  @doc """
  The images the exported site uses, without duplicates: the images
  embedded in the content of its posts, pages and projects, their header
  and thumbnail images, the book covers, the site images its theme
  renders (`c:Feather.StaticSite.Theme.site_image_fields/0`) and, for a
  site with a fediverse name, the portrait as its account's picture.
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

  defp site_image_ids(%Site{} = site) do
    theme_ids = Enum.map(Themes.module(site).site_image_fields(), &Map.fetch!(site, &1))
    if site.fediverse_name, do: [site.portrait_image_id | theme_ids], else: theme_ids
  end
end
