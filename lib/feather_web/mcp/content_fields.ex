defmodule FeatherWeb.MCP.ContentFields do
  @moduledoc """
  What the post and page tools share: the content as JSON blocks
  (`Feather.Content.BlockValidator`), images named by public id, tags as a
  list, the message for a failed save and the link to the preview.
  """

  import Phoenix.VerifiedRoutes, only: [unverified_url: 2]

  alias Feather.Accounts.Scope
  alias Feather.{Content, Media}
  alias Feather.Content.{Blocks, BlockValidator, Tags}
  alias Feather.Media.Image
  alias Feather.StaticSite.Routes
  alias FeatherWeb.MCP.Tool

  @doc "The input schema property of the content."
  @spec content_property() :: map()
  def content_property do
    Map.put(
      BlockValidator.content_schema(),
      "description",
      "The content as JSON blocks; replaces all of it. Text is inline HTML with only <b>, " <>
        "<i>, <u>, <code>, <br> and <a href>. Image blocks name one of the site's images " <>
        "by id, book blocks a book from list_books."
    )
  end

  @doc """
  The input schema property of an image: the id of one of the site's
  images, `description` saying where it is shown.
  """
  @spec image_property(String.t()) :: map()
  def image_property(description) do
    %{
      "type" => ["string", "null"],
      "description" => description <> "; an id from list_images or add_image_from_url"
    }
  end

  @doc "The input schema property of the tags."
  @spec tags_property() :: map()
  def tags_property, do: %{"type" => ["array", "null"], "items" => %{"type" => "string"}}

  @doc """
  The arguments with `content` checked by the block validator, the public
  ids of `header_image` and `thumbnail_image` replaced by the
  `header_image_id` and `thumbnail_image_id` of the site's images and
  `tags` joined as `Feather.Content` takes them. Image and book blocks must
  name the site's images and books (`Feather.Content.resolve_references/2`).
  """
  @spec cast(Scope.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def cast(%Scope{} = scope, arguments) do
    with {:ok, arguments} <- cast_content(scope, arguments),
         {:ok, arguments} <- cast_image(scope, arguments, "header_image"),
         {:ok, arguments} <- cast_image(scope, arguments, "thumbnail_image") do
      {:ok, Map.replace_lazy(arguments, "tags", &Tags.from_list(List.wrap(&1)))}
    end
  end

  # The argument check passes anyOf over, so the block validator's messages say what is wrong.
  defp cast_content(scope, %{"content" => content} = arguments) do
    with {:ok, blocks} <- validate_blocks(content),
         {:ok, blocks} <- resolve_references(scope, blocks) do
      {:ok, Map.put(arguments, "content", blocks)}
    end
  end

  defp cast_content(_scope, arguments), do: {:ok, arguments}

  defp validate_blocks(content) do
    case BlockValidator.validate(content) do
      {:ok, blocks} -> {:ok, blocks}
      {:error, messages} -> {:error, "Invalid content: " <> Enum.join(messages, "; ")}
    end
  end

  defp resolve_references(%Scope{site: site} = scope, blocks) do
    case Content.resolve_references(scope, blocks) do
      {:ok, blocks} ->
        {:ok, blocks}

      {:error, unknown} ->
        messages =
          for {index, type, id} <- unknown,
              do: "Block #{index} (#{type}): there is no #{type} #{id} on #{site.domain}"

        {:error, "Invalid content: " <> Enum.join(messages, "; ")}
    end
  end

  defp cast_image(scope, arguments, field) do
    case Map.fetch(arguments, field) do
      {:ok, public_id} ->
        with {:ok, id} <- image_id(scope, field, public_id) do
          {:ok, arguments |> Map.delete(field) |> Map.put(field <> "_id", id)}
        end

      :error ->
        {:ok, arguments}
    end
  end

  defp image_id(_scope, _field, nil), do: {:ok, nil}

  defp image_id(%Scope{site: site} = scope, field, public_id) do
    case Media.get_image(scope, public_id) do
      %Image{id: id} -> {:ok, id}
      nil -> {:error, "#{field}: there is no image #{public_id} on #{site.domain}."}
    end
  end

  @doc "The arguments with the slug suggested from the title when they give a title but no slug."
  @spec put_suggested_slug(Scope.t(), map()) :: map()
  def put_suggested_slug(%Scope{} = scope, %{"title" => title} = arguments)
      when is_binary(title) and not is_map_key(arguments, "slug"),
      do: Map.put(arguments, "slug", Content.suggest_slug(scope, title))

  def put_suggested_slug(%Scope{}, arguments), do: arguments

  @doc """
  The message for a save that failed, `noun` naming the record: that it was
  changed elsewhere since the lock version the agent read, or the
  validation errors.
  """
  @spec save_error(Ecto.Changeset.t(), String.t()) :: String.t()
  def save_error(%Ecto.Changeset{errors: errors} = changeset, noun) do
    if Keyword.has_key?(errors, :lock_version) do
      "The #{noun} was changed elsewhere since lock_version #{changeset.data.lock_version}, " <>
        "so nothing was saved. get_#{noun} gives it as it is now."
    else
      "Invalid #{noun}: " <> Tool.errors(changeset)
    end
  end

  @doc """
  The content of a post, page or project as a result: its blocks without
  the fields that have no value, so it can be sent back as it is.
  """
  @spec content(%{content: [Blocks.block()]}) :: [Blocks.block()]
  def content(%{content: blocks}),
    do: Enum.map(blocks, &Map.reject(&1, fn {_key, value} -> is_nil(value) end))

  @doc "The public id of a loaded image or book, or nil."
  @spec public_id(%{public_id: String.t()} | nil) :: String.t() | nil
  def public_id(%{public_id: public_id}), do: public_id
  def public_id(nil), do: nil

  @doc "The URL of the record's preview once it has a slug, else nil."
  @spec preview_url(Scope.t(), map()) :: String.t() | nil
  def preview_url(%Scope{}, %{slug: nil}), do: nil

  def preview_url(%Scope{site: site}, record),
    do: unverified_url(FeatherWeb.Endpoint, Routes.record_url(Routes.preview(site), record))
end
