defmodule Feather.Content.Suggestions do
  @moduledoc """
  What the model suggests for a post or page, called through
  `Feather.Content`: its description (`Feather.Content.Description`) and a
  short post's meta title and slug (`Feather.Content.ShortPost`), asked
  for at publish (`Feather.Content.publish/2`), by the backfill and by the
  "Suggest" button.
  """

  import Ecto.Query, warn: false
  import Feather.Content.Versions, only: [lock: 1, put_navigation_flag: 1, stale_error: 1]

  alias Feather.Accounts.Scope
  alias Feather.Content.{Description, Page, Post, ShortPost, Slug, Versions}
  alias Feather.Repo
  alias Feather.Sites.Site
  alias Feather.Validations

  @lock_opts Versions.lock_opts()

  @doc false
  # The changes the model suggests for the record as it would be published.
  def publish_suggestions(scope, %schema{} = record) when schema in [Post, Page] do
    if Versions.publication_status(record) == :published do
      %{}
    else
      newest_version = Versions.newest_version(scope, record)

      ask_model(scope, record,
        description?: Description.needed?(record, newest_version),
        short_post?: ShortPost.needed?(record, newest_version)
      )
    end
  end

  def publish_suggestions(_scope, _project), do: %{}

  @doc false
  # Asks for the wanted suggestions concurrently.
  def ask_model(scope, record, wanted) do
    language_code = scope.site.language_code

    [
      wanted[:description?] && fn -> description_suggestion(record, language_code) end,
      wanted[:short_post?] && fn -> short_post_suggestion(record, language_code) end
    ]
    |> Enum.filter(& &1)
    |> Enum.map(&Task.async/1)
    |> Task.await_many(:infinity)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp description_suggestion(record, language_code) do
    case Description.generate(record, language_code) do
      {:ok, description} -> %{description: description, description_generated: true}
      {:error, _reason} -> %{}
    end
  end

  # A meta title or slug the post already has stays.
  defp short_post_suggestion(post, language_code) do
    case ShortPost.generate(post, language_code) do
      {:ok, suggestion} ->
        suggestion
        |> Map.reject(fn {_field, value} -> value == "" end)
        |> Map.drop(if Validations.blank?(post.meta_title), do: [], else: [:meta_title])
        |> Map.drop(if is_nil(post.slug), do: [], else: [:slug])

      {:error, _reason} ->
        %{}
    end
  end

  @doc false
  def put_suggestions(record, suggestions) when suggestions == %{}, do: record

  # update_all keeps the record's updated_at and lock_version, like publishing does.
  def put_suggestions(%schema{id: id} = record, suggestions) do
    suggestions = put_free_slug(record, suggestions)
    Repo.update_all(from(r in schema, where: r.id == ^id), set: Map.to_list(suggestions))
    struct(record, suggestions)
  end

  # The suggested slug base becomes a slug no record, redirect or published version holds.
  defp put_free_slug(%schema{id: id, site_id: site_id}, %{slug: base} = suggestions) do
    taken? =
      &(Slug.taken?(schema, site_id, &1, id) or
          Versions.published_with_slug?(schema, site_id, &1, id))

    case Slug.suggest(base, taken?) do
      "" -> Map.delete(suggestions, :slug)
      slug -> %{suggestions | slug: slug}
    end
  end

  defp put_free_slug(_record, suggestions), do: suggestions

  @doc """
  Asks the model for a description of a post or page as it is (the
  "Suggest" button). Returns `{:error, reason}` without a model, when it
  fails or for a record without text.
  """
  @spec suggest_description(Scope.t(), Post.t() | Page.t()) ::
          {:ok, String.t()} | {:error, term()}
  def suggest_description(
        %Scope{site: %Site{id: site_id} = site},
        %schema{site_id: site_id} = record
      )
      when schema in [Post, Page],
      do: Description.generate(record, site.language_code)

  @doc """
  Stores a suggested description in the unpublished changes of a post or
  page, marked as generated. Fails with `{:error, :stale}` when the record
  was changed elsewhere since the given one.
  """
  @spec put_suggested_description(Scope.t(), record, String.t()) ::
          {:ok, record} | {:error, :stale}
        when record: Post.t() | Page.t()
  def put_suggested_description(
        %Scope{site: %Site{id: site_id}},
        %schema{site_id: site_id} = record,
        description
      )
      when schema in [Post, Page] and is_binary(description) do
    changeset =
      record
      |> Ecto.Changeset.change(description: description, description_generated: true)
      |> lock()

    with {:ok, saved} <- changeset |> Repo.update([force: true] ++ @lock_opts) |> stale_error(),
         do: {:ok, put_navigation_flag(saved)}
  end
end
