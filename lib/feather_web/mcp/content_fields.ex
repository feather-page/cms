defmodule FeatherWeb.MCP.ContentFields do
  @moduledoc """
  What the post tools share with tools for other content: the content as
  JSON blocks (`Feather.Content.BlockValidator`), images named by public
  id, the message for a failed save and the link to the preview.
  """

  import Phoenix.VerifiedRoutes, only: [unverified_url: 2]

  alias Feather.Accounts.Scope
  alias Feather.{Books, Media}
  alias Feather.Content.{Blocks, BlockValidator}
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

  @doc "The schemas the content property refers to, as the input schema's `$defs`."
  @spec definitions() :: map()
  def definitions, do: BlockValidator.definitions()

  @doc "The input schema property of an image: the id of one of the site's images."
  @spec image_property(String.t()) :: map()
  def image_property(description),
    do: %{"type" => ["string", "null"], "description" => description}

  @doc """
  The arguments with `content` checked by the block validator and with the
  public ids of `header_image` and `thumbnail_image` replaced by the
  `header_image_id` and `thumbnail_image_id` of the site's images. Image and
  book blocks must name the site's images and books.
  """
  @spec cast(Scope.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def cast(%Scope{} = scope, arguments) do
    with {:ok, arguments} <- cast_content(scope, arguments),
         {:ok, arguments} <- cast_image(scope, arguments, "header_image") do
      cast_image(scope, arguments, "thumbnail_image")
    end
  end

  # The argument check passes anyOf over, so the block validator's messages say what is wrong.
  defp cast_content(scope, %{"content" => content} = arguments) do
    with {:ok, blocks} <- validate_blocks(content),
         :ok <- check_references(scope, blocks) do
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

  defp check_references(%Scope{site: site} = scope, blocks) do
    known = known_references(scope, blocks)

    messages =
      for {block, index} <- Enum.with_index(blocks),
          {type, id} = reference <- [reference(block)],
          reference not in known,
          do: "Block #{index} (#{type}): there is no #{type} #{id} on #{site.domain}"

    if messages == [], do: :ok, else: {:error, "Invalid content: " <> Enum.join(messages, "; ")}
  end

  defp known_references(scope, blocks) do
    images = Media.site_image_ids(scope, Blocks.image_ids(blocks))
    books = Map.keys(Books.books_by_public_id(scope, Blocks.book_ids(blocks)))
    MapSet.new(Enum.map(images, &{"image", &1}) ++ Enum.map(books, &{"book", &1}))
  end

  defp reference(%{"type" => "image", "image_id" => id}), do: {"image", id}
  defp reference(%{"type" => "book", "book_public_id" => id}), do: {"book", id}
  defp reference(_block), do: nil

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
