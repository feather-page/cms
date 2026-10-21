defmodule Feather.Content do
  @moduledoc """
  Posts, pages and projects of a site.

  Every function takes a `%Scope{}` whose `site` is set (see
  `Feather.Accounts.Scope.put_site/2`) and only sees that site's records.
  Records are looked up by public id.

  Saving content assigns the images referenced by its image blocks to the
  record (`images.post_id` / `page_id` / `project_id`), like Rails did.
  Deleting a record deletes the images embedded in it.

  A record holds its unpublished changes: saving it does not change what
  the site shows. Publishing copies its fields into a new, numbered version
  (`PostVersion`, `PageVersion`, `ProjectVersion`) and points
  `published_version_id` at it. Versions copy the header and
  thumbnail image ids, not image rows: images stay owned by the record.
  Deleting a record deletes its versions. Deleting or unpublishing a
  published record moves the site's `updated_at`
  (`Feather.Sites.touch_site/1`): no version records that change.

  ## Saving

  Creating or updating a record only stores it; publishing is a step of
  its own (`publish/2`). Posts and pages also take the option `draft:`
  (the content API's field), applied in the same transaction as the save:
  `draft: false` publishes the saved record, `draft: true` makes it a draft
  (unpublishing it if it was published) that keeps the saved changes.
  Where `publish/2` refuses the slug, the save fails with "has already
  been taken" on `:slug`.

  Every save that changes a record's fields (forms, the content API,
  `sync_content/4`, `discard_changes/2`, `restore_version/3`) increments
  its `lock_version`, and a save based on an older `lock_version` fails
  with the error "was changed elsewhere" on `:lock_version`. So an editor
  open in two tabs cannot overwrite the other tab's changes unnoticed.
  Publishing and unpublishing only move the published version and leave
  the counter.
  """

  alias Feather.Accounts.Scope
  alias Feather.Books
  alias Feather.Content.{Backfill, Blocks, Page, Pages, Post, Posts, Project, Projects}
  alias Feather.Content.{ProseMirror, Saving, Slug, Suggestions, Sync, Tags, Versions}
  alias Feather.Repo
  alias Feather.Sites.Site

  @type sync :: Sync.sync()

  defdelegate versioned_schemas(), to: Versions

  ## Posts

  defdelegate list_posts(scope), to: Posts
  defdelegate get_post!(scope, public_id), to: Posts
  defdelegate get_post(scope, public_id), to: Posts
  defdelegate paginate_posts(scope, page), to: Posts
  defdelegate paginate_admin_posts(scope, page), to: Posts
  defdelegate get_post_by_slug(scope, slug), to: Posts
  defdelegate create_post(scope, attrs, opts \\ []), to: Posts
  defdelegate update_post(scope, post, attrs, opts \\ []), to: Posts
  defdelegate delete_post(scope, post), to: Posts
  defdelegate change_post(scope, post, attrs \\ %{}), to: Posts

  ## Pages

  defdelegate list_pages(scope), to: Pages
  defdelegate get_page!(scope, public_id), to: Pages
  defdelegate get_page(scope, public_id), to: Pages
  defdelegate paginate_pages(scope, page), to: Pages
  defdelegate paginate_pages_outside_navigation(scope, page), to: Pages
  defdelegate get_page_by_slug(scope, slug), to: Pages
  defdelegate get_homepage(scope), to: Pages
  defdelegate create_page(scope, attrs, opts \\ []), to: Pages
  defdelegate update_page(scope, page, attrs, opts \\ []), to: Pages
  defdelegate delete_page(scope, page), to: Pages
  defdelegate change_page(scope, page, attrs \\ %{}), to: Pages

  ## Projects

  defdelegate list_projects(scope), to: Projects
  defdelegate get_project!(scope, public_id), to: Projects
  defdelegate get_project(scope, public_id), to: Projects
  defdelegate create_project(scope, attrs), to: Projects
  defdelegate update_project(scope, project, attrs), to: Projects
  defdelegate delete_project(scope, project), to: Projects
  defdelegate change_project(scope, project, attrs \\ %{}), to: Projects

  ## Autosave

  defdelegate autosave(scope, record, attrs, opts \\ []), to: Sync
  defdelegate sync_content(scope, record, sync, opts \\ []), to: Sync
  defdelegate synced_doc(sync), to: Sync

  ## Publishing

  defdelegate publish(scope, record), to: Saving
  defdelegate unpublish(scope, record), to: Versions
  defdelegate backfill_suggestions(scope), to: Backfill
  defdelegate suggest_description(scope, record), to: Suggestions
  defdelegate put_suggested_description(scope, record, description), to: Suggestions
  defdelegate published_slug?(scope, schema, slug, except_id \\ nil), to: Versions
  defdelegate draft?(record), to: Versions
  defdelegate due?(post, now), to: Versions
  defdelegate stored_published?(record), to: Versions
  defdelegate publication_status(record), to: Versions
  defdelegate last_changed_at(record), to: Versions
  defdelegate last_changed_or_updated_at(record), to: Versions
  defdelegate discard_changes(scope, record), to: Versions
  defdelegate restore_version(scope, record, version), to: Versions
  defdelegate get_version(scope, record, number), to: Versions
  defdelegate get_version!(scope, record, number), to: Versions
  defdelegate list_versions(scope, record), to: Versions
  defdelegate as_published(records), to: Versions
  defdelegate preload_published_version(record), to: Versions

  ## Shared

  @doc """
  Suggests a free slug for a title in the scope's site, like Rails'
  `SlugGenerator`: `/my-title`, then `/my-title1`, `/my-title2`, ...
  Returns `""` for a blank title. The slug is free in the URL space of
  `except`, the record being edited (`Feather.Content.Slug.url_space/1`,
  posts and pages without it), and not reserved unless `except` is a
  project. The slug of `except` itself counts as free.
  """
  @spec suggest_slug(Scope.t(), String.t(), Post.t() | Page.t() | Project.t() | nil) ::
          String.t()
  def suggest_slug(%Scope{site: %Site{id: site_id}}, title, except \\ nil)
      when is_binary(title) do
    {schema, except_id} =
      case except do
        %schema{id: id} -> {schema, id}
        nil -> {Post, nil}
      end

    Slug.suggest(title, &Slug.taken?(schema, site_id, &1, except_id),
      own_namespace: schema == Project
    )
  end

  @doc """
  The plain text excerpt of a post, page or project: the text of its
  paragraphs, headers and quotes without HTML, at most `length` characters.
  """
  @spec content_excerpt(Post.t() | Page.t() | Project.t(), pos_integer()) :: String.t()
  def content_excerpt(%{content: content}, length \\ 300) do
    Blocks.excerpt(content, length)
  end

  @doc """
  The tags of a post, page or project as a list.
  """
  @spec tag_list(Post.t() | Page.t() | Project.t()) :: [String.t()]
  def tag_list(record), do: Tags.tag_list(record)

  @doc """
  The content of a post, page or project as a ProseMirror document for the
  admin editor, with book nodes refreshed from the site's books.
  """
  @spec editor_doc(Scope.t(), Post.t() | Page.t() | Project.t()) :: ProseMirror.doc()
  def editor_doc(%Scope{site: %Site{} = site} = scope, %{content: content}) do
    books = Books.books_by_public_id(scope, Blocks.book_ids(content))
    ProseMirror.to_doc(content, site, books)
  end

  @doc """
  Preloads the header and thumbnail image of a post, page or project.
  """
  @spec preload_images(record) :: record when record: Post.t() | Page.t() | Project.t()
  def preload_images(record), do: Repo.preload(record, [:header_image, :thumbnail_image])
end
