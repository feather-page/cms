defmodule Feather.Content.Blocks do
  @moduledoc """
  The block data layer: pure functions over the content of posts, pages and
  projects. (Rendering blocks to HTML lives elsewhere.)

  Content is a list of blocks. Each block is a map with string keys, an
  `"id"`, a `"type"` and the fields of its type. This is the stored format
  and the format of the content API (the Rails internal format):

    * `paragraph` - `text`
    * `header` - `level` (2, 3 or 4; anything else becomes 2), `text`
    * `list` - `style` (`"ul"` or `"ol"`), `items` (`[%{"content", "items"}]`, nested)
    * `quote` - `text`, `caption`
    * `code` - `code`, `language` (default `"plaintext"`)
    * `image` - `image_id` (the image's public id), `caption`
    * `table` - `content` (rows of cells), `with_headings`
    * `embed` - `service`, `source`, `embed`, `width`, `height`, `caption`
    * `book` - `book_public_id`, `title`, `author`, `cover_url`, `emoji`

  Inline HTML (paragraph, header and quote text, quote, image and embed
  captions, list items, table cells) is sanitized with
  `Feather.Content.HTML.sanitize(html, :editor)` and embed URLs that are
  not safe link targets are dropped whenever content is normalized: before
  it is stored (admin editor, content API, import) and before it is handed
  to the admin editor. Content stored before this was in place is
  therefore sanitized on its way to the editor as well.

  Blocks of unknown types are dropped. `Feather.Content.ProseMirror`
  converts from and to the ProseMirror JSON of the admin editor.
  """

  alias Feather.Content.HTML

  @type block :: %{required(String.t()) => term()}

  @types ~w(paragraph header list quote code image table embed book)
  @header_levels [2, 3, 4]
  @text_types ~w(paragraph header quote)

  @doc "The known block types."
  @spec types() :: [String.t()]
  def types, do: @types

  @doc """
  Normalizes content in the internal format: string keys, known types only,
  defaults filled in, missing ids generated. Accepts nil (empty content).
  """
  @spec normalize(nil | [map()]) :: [block()]
  def normalize(nil), do: []

  def normalize(blocks) when is_list(blocks) do
    blocks
    |> Enum.filter(&is_map/1)
    |> Enum.map(&stringify_keys/1)
    |> Enum.flat_map(fn block ->
      case normalize_block(block["type"], block) do
        nil -> []
        normalized -> [Map.put(normalized, "id", block["id"] || generate_id())]
      end
    end)
  end

  defp normalize_block("paragraph", b), do: %{"type" => "paragraph", "text" => inline(b["text"])}

  defp normalize_block("header", b),
    do: %{"type" => "header", "level" => header_level(b["level"]), "text" => inline(b["text"])}

  defp normalize_block("list", b),
    do: %{"type" => "list", "style" => list_style(b["style"]), "items" => list_items(b["items"])}

  defp normalize_block("quote", b),
    do: %{"type" => "quote", "text" => inline(b["text"]), "caption" => inline(b["caption"])}

  defp normalize_block("code", b),
    do: %{"type" => "code", "code" => code(b["code"]), "language" => code_language(b["language"])}

  defp normalize_block("image", b) do
    if is_binary(b["image_id"]) do
      %{"type" => "image", "image_id" => b["image_id"], "caption" => inline(b["caption"]) || ""}
    end
  end

  defp normalize_block("table", b) do
    %{
      "type" => "table",
      "content" => table_content(b["content"]),
      "with_headings" => b["with_headings"]
    }
  end

  defp normalize_block("embed", b) do
    %{
      "type" => "embed",
      "service" => b["service"],
      "source" => safe_url(b["source"]),
      "embed" => safe_url(b["embed"]),
      "width" => b["width"],
      "height" => b["height"],
      "caption" => inline(b["caption"]) || ""
    }
  end

  defp normalize_block("book", b) do
    %{
      "type" => "book",
      "book_public_id" => b["book_public_id"],
      "title" => b["title"],
      "author" => b["author"],
      "cover_url" => b["cover_url"],
      "emoji" => b["emoji"]
    }
  end

  defp normalize_block(_type, _block), do: nil

  @doc """
  Takes title, author and emoji of a book block from `books` (a map of
  book public id to a map or struct with those fields) when the book is in
  it, like Rails did: the bookshelf is the source of truth.
  """
  @spec put_book(block(), map()) :: block()
  def put_book(%{"type" => "book"} = block, books) do
    case Map.get(books, block["book_public_id"]) do
      nil ->
        block

      book ->
        Enum.reduce(~w(title author emoji)a, block, fn field, block ->
          Map.put(block, to_string(field), book_field(book, field) || block[to_string(field)])
        end)
    end
  end

  defp book_field(%{} = book, field), do: Map.get(book, field) || Map.get(book, to_string(field))

  @doc """
  The admin URL of an image as used in the editor.
  """
  @spec image_url(%{public_id: String.t()}, String.t()) :: String.t()
  def image_url(%{public_id: site_public_id}, image_public_id) do
    "/sites/#{site_public_id}/images/#{image_public_id}"
  end

  @doc """
  The public ids of all images referenced by image blocks.
  """
  @spec image_ids([block()] | nil) :: [String.t()]
  def image_ids(blocks) do
    blocks
    |> normalize()
    |> Enum.filter(&(&1["type"] == "image"))
    |> Enum.map(& &1["image_id"])
    |> Enum.uniq()
  end

  @doc """
  The public ids of all books referenced by book blocks.
  """
  @spec book_ids([block()] | nil) :: [String.t()]
  def book_ids(blocks) do
    blocks
    |> normalize()
    |> Enum.filter(&(&1["type"] == "book"))
    |> Enum.map(& &1["book_public_id"])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  The plain text of all text blocks (paragraphs, headers, quotes), with
  HTML tags removed, truncated to `length` characters including a trailing
  "..." (like Rails' `String#truncate`).
  """
  @spec excerpt([block()] | nil, pos_integer()) :: String.t()
  def excerpt(blocks, length \\ 300) do
    blocks
    |> normalize()
    |> Enum.filter(&(&1["type"] in @text_types))
    |> Enum.map(&(&1["text"] || ""))
    |> Enum.join(" ")
    |> strip_tags()
    |> truncate(length)
  end

  @doc """
  The length of the content as the admin counts it to tell short posts
  (no title needed) from long ones, ported from Rails'
  `EditorJsContentLengthCalculator`: the raw text (HTML included) of
  paragraphs, headers, quotes (text and caption), code, table cells, list
  items (nested) and image captions. Book and embed blocks count 0.
  """
  @spec content_length([block()] | nil) :: non_neg_integer()
  def content_length(blocks) do
    blocks
    |> normalize()
    |> Enum.map(&block_length/1)
    |> Enum.sum()
  end

  defp block_length(%{"type" => type, "text" => text}) when type in ~w(paragraph header),
    do: text_length(text)

  defp block_length(%{"type" => "quote"} = b),
    do: text_length(b["text"]) + text_length(b["caption"])

  defp block_length(%{"type" => "code"} = b), do: text_length(b["code"])
  defp block_length(%{"type" => "image"} = b), do: text_length(b["caption"])
  defp block_length(%{"type" => "list"} = b), do: list_length(b["items"])

  defp block_length(%{"type" => "table", "content" => rows}) when is_list(rows) do
    for row <- rows, is_list(row), cell <- row, reduce: 0 do
      sum -> sum + text_length(cell)
    end
  end

  defp block_length(_block), do: 0

  defp list_length(items) when is_list(items) do
    Enum.reduce(items, 0, fn item, sum ->
      sum + text_length(item["content"]) + list_length(item["items"])
    end)
  end

  defp list_length(_items), do: 0

  defp text_length(text) when is_binary(text), do: String.length(text)
  defp text_length(_text), do: 0

  @doc """
  Removes HTML tags from a string and decodes entities. Whitespace between
  tags is kept (`"<b>a</b> <i>b</i>"` becomes `"a b"`), a `<br>` becomes a
  space and the content of `<script>` and `<style>` is dropped.

  Uses Floki's mochiweb tokenizer directly: `Floki.parse_fragment/1` drops
  whitespace-only text nodes, which glued words together.
  """
  @spec strip_tags(String.t()) :: String.t()
  def strip_tags(html) when is_binary(html) do
    html
    |> :floki_mochi_html.tokens()
    |> text_of_tokens(nil, [])
  rescue
    _exception -> html
  end

  @dropped_content ~w(script style)

  defp text_of_tokens([], _dropping, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp text_of_tokens([{:end_tag, tag} | rest], tag, acc), do: text_of_tokens(rest, nil, acc)

  defp text_of_tokens([_token | rest], dropping, acc) when is_binary(dropping),
    do: text_of_tokens(rest, dropping, acc)

  defp text_of_tokens([{:data, text, _whitespace?} | rest], nil, acc),
    do: text_of_tokens(rest, nil, [text | acc])

  defp text_of_tokens([{:start_tag, tag, _attributes, self_closing?} | rest], nil, acc)
       when tag in @dropped_content and not self_closing?,
       do: text_of_tokens(rest, tag, acc)

  defp text_of_tokens([{:start_tag, "br", _attributes, _self_closing?} | rest], nil, acc),
    do: text_of_tokens(rest, nil, [" " | acc])

  defp text_of_tokens([_token | rest], nil, acc), do: text_of_tokens(rest, nil, acc)

  @doc """
  Truncates a string to `length` characters, ending in "..." when cut.
  """
  @spec truncate(String.t(), pos_integer()) :: String.t()
  def truncate(text, length) do
    if String.length(text) > length do
      String.slice(text, 0, max(length - 3, 0)) <> "..."
    else
      text
    end
  end

  defp header_level(level) when level in @header_levels, do: level

  defp header_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {int, ""} -> header_level(int)
      _ -> 2
    end
  end

  defp header_level(_level), do: 2

  defp list_style("ol"), do: "ol"
  defp list_style(_style), do: "ul"

  defp code(code) when is_binary(code), do: code
  defp code(_code), do: ""

  defp code_language(language) when is_binary(language) and language != "", do: language
  defp code_language(_language), do: "plaintext"

  defp list_items(items) when is_list(items) do
    Enum.map(items, fn
      item when is_binary(item) ->
        %{"content" => inline(item), "items" => []}

      %{} = item ->
        item = stringify_keys(item)
        %{"content" => inline(item["content"]) || "", "items" => list_items(item["items"])}

      other ->
        %{"content" => inline(other) || "", "items" => []}
    end)
  end

  defp list_items(_items), do: []

  # Inline HTML of stored content and of the admin editor: sanitized.
  defp inline(nil), do: nil
  defp inline(html) when is_binary(html), do: HTML.sanitize(html, :editor)
  defp inline(value) when is_number(value) or is_boolean(value), do: to_string(value)
  defp inline(_value), do: nil

  defp table_content(rows) when is_list(rows) do
    for row <- rows, is_list(row), do: Enum.map(row, &(inline(&1) || ""))
  end

  defp table_content(_rows), do: nil

  # Embed URLs end up in an iframe's src.
  defp safe_url(url) when is_binary(url), do: if(HTML.safe_url?(url), do: url)
  defp safe_url(_url), do: nil

  defp stringify_keys(%{} = map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  @id_alphabet ~c"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  defp generate_id do
    for <<byte <- :crypto.strong_rand_bytes(10)>>, into: "" do
      <<Enum.at(@id_alphabet, rem(byte, length(@id_alphabet)))>>
    end
  end
end
