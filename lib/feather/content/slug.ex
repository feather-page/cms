defmodule Feather.Content.Slug do
  @moduledoc """
  Slugs address posts, pages and projects in the exported site.

  A slug is normalized to `/x/y` (leading slash, no trailing slash) and
  must match `#{inspect(~r{\A/([a-z0-9-]+(/[a-z0-9-]+)*)?\z})}`. Only the
  homepage may own the site root `/`. Paths the export generates itself
  are reserved: everything under `images/`, `page/`, `posts/` and
  `projects/`, plus `feed.xml`, `robots.txt` and `sitemap.xml`. Projects
  live under `projects/`, so their slugs are exempt from the reservation.

  Posts and pages share the site root, so a slug is unique among the
  posts and pages of a site, see `url_space/1`.
  """

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, where: 3]

  alias Feather.Content.{Page, Post, Project}

  @format ~r{\A/([a-z0-9-]+(/[a-z0-9-]+)*)?\z}
  @reserved_prefixes ~w(images page posts projects)
  @artifacts ~w(feed.xml robots.txt sitemap.xml)

  @doc "Top-level path segments the export generates."
  @spec reserved_prefixes() :: [String.t()]
  def reserved_prefixes, do: @reserved_prefixes

  @doc "Files the export generates at the site root."
  @spec artifacts() :: [String.t()]
  def artifacts, do: @artifacts

  @doc """
  Normalizes a slug: blank becomes nil, otherwise exactly one leading and
  no trailing slash (`"about/"` -> `"/about"`, `"/"` -> `"/"`).
  """
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(nil), do: nil

  def normalize(slug) when is_binary(slug) do
    case String.trim(slug) do
      "" ->
        nil

      slug ->
        slug = slug |> String.replace_prefix("/", "") |> String.replace_suffix("/", "")
        "/" <> slug
    end
  end

  @doc """
  Returns true if the slug claims a path the export generates itself.
  """
  @spec reserved?(String.t() | nil) :: boolean()
  def reserved?(nil), do: false

  def reserved?(slug) do
    path = String.replace_prefix(slug, "/", "")
    first_segment = path |> String.split("/") |> List.first()

    first_segment in @reserved_prefixes or path in @artifacts
  end

  @doc """
  Normalizes and validates the `:slug` field of a changeset.

  ## Options

    * `:required` - the slug must be present (default `false`)
    * `:allow_root` - the slug may be `/` (default `false`)
    * `:own_namespace` - skip the reserved path check (default `false`)
  """
  @spec cast_slug(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def cast_slug(changeset, opts \\ []) do
    changeset = update_change(changeset, :slug, &normalize/1)

    changeset =
      if opts[:required], do: validate_required(changeset, [:slug]), else: changeset

    changeset
    |> validate_format(:slug, @format,
      message: "may only contain lowercase letters, digits, dashes and slashes"
    )
    |> validate_change(:slug, fn :slug, slug ->
      cond do
        slug == "/" and not Keyword.get(opts, :allow_root, false) ->
          [slug: "is reserved for the homepage"]

        slug != "/" and not Keyword.get(opts, :own_namespace, false) and reserved?(slug) ->
          [slug: "is reserved"]

        true ->
          []
      end
    end)
  end

  @doc """
  The schemas whose records share the URL space of `schema`'s records:
  posts and pages are exported at the site root, projects under
  `projects/`.
  """
  @spec url_space(module()) :: [module()]
  def url_space(schema) when schema in [Post, Page], do: [Post, Page]
  def url_space(Project), do: [Project]

  @doc """
  Adds "has already been taken" to a changed `:slug` that another record
  of the site's URL space (`url_space/1`) has. The unique index of a
  table only covers its own records. Like
  `Ecto.Changeset.unsafe_validate_unique/4` it checks without a lock.
  """
  @spec unsafe_validate_unique(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def unsafe_validate_unique(%Ecto.Changeset{data: %schema{id: id}} = changeset) do
    slug = get_change(changeset, :slug)
    site_id = get_field(changeset, :site_id)

    if is_binary(slug) and not is_nil(site_id) and not Keyword.has_key?(changeset.errors, :slug) and
         taken?(schema, site_id, slug, id) do
      add_error(changeset, :slug, "has already been taken",
        validation: :unsafe_unique,
        fields: [:site_id, :slug]
      )
    else
      changeset
    end
  end

  @doc """
  Returns true if a record of the site's URL space of `schema`
  (`url_space/1`) has the slug. The `schema` record with id `except_id`
  does not count.
  """
  @spec taken?(module(), Ecto.UUID.t(), String.t(), Ecto.UUID.t() | nil) :: boolean()
  def taken?(schema, site_id, slug, except_id \\ nil) do
    Enum.any?(url_space(schema), fn other ->
      query = from r in other, where: r.site_id == ^site_id and r.slug == ^slug

      query =
        if other == schema and except_id,
          do: where(query, [r], r.id != ^except_id),
          else: query

      Feather.Repo.exists?(query)
    end)
  end

  @doc """
  Turns a title into a slug candidate the way Rails' `SlugGenerator` did:
  slashes removed, lowercased, trimmed, every character other than `a-z`,
  `0-9` and `-` replaced by a dash, repeated dashes squeezed. Returns `""`
  for blank input, otherwise `"/candidate"`.
  """
  @spec from_title(String.t()) :: String.t()
  def from_title(title) when is_binary(title) do
    candidate =
      title
      |> String.replace("/", "")
      |> String.downcase()
      |> String.trim()
      |> String.replace(~r/[^a-z0-9-]/u, "-")
      |> String.replace(~r/-+/, "-")

    if candidate == "", do: "", else: "/" <> candidate
  end

  @doc """
  Suggests a free slug for the title. `taken?` is called with candidates
  (`/x`, `/x1`, `/x2`, ...) until it returns false; reserved slugs are
  never suggested.
  """
  @spec suggest(String.t(), (String.t() -> boolean())) :: String.t()
  def suggest(title, taken?) when is_function(taken?, 1) do
    case from_title(title) do
      "" -> ""
      base -> find_free(base, 0, taken?)
    end
  end

  defp find_free(base, attempt, taken?) do
    candidate = if attempt == 0, do: base, else: "#{base}#{attempt}"

    if reserved?(candidate) or taken?.(candidate) do
      find_free(base, attempt + 1, taken?)
    else
      candidate
    end
  end
end
