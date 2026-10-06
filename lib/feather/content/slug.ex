defmodule Feather.Content.Slug do
  @moduledoc """
  Slugs address posts, pages and projects in the exported site.

  A slug is normalized to `/x/y` (leading slash, no trailing slash) and
  must match `#{inspect(~r{\A/([a-z0-9-]+(/[a-z0-9-]+)*)?\z})}`. Only the
  homepage may own the site root `/`. Paths the export generates itself
  are reserved: everything under `images/`, `page/`, `posts/` and
  `projects/`, plus `feed.xml`, `robots.txt` and `sitemap.xml`. Projects
  live under `projects/`, so their slugs are exempt from the reservation.
  """

  import Ecto.Changeset

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
