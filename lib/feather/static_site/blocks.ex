defmodule Feather.StaticSite.Blocks do
  @moduledoc """
  Renders content blocks (see `Feather.Content.Blocks`) to the HTML of the
  static site. The markup follows the Rails renderers so exported sites
  look the same.

  Inline HTML (paragraphs, headers, list items, quotes, captions, table
  cells) goes through `Feather.StaticSite.Sanitizer`; everything else is
  escaped. Image and book blocks look their records up in the maps given
  in the context (by public id) and render nothing when the record is
  missing.
  """

  alias Feather.Books.Book
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Media.Image
  alias Feather.StaticSite.{Routes, Sanitizer}

  @enforce_keys [:routes]
  defstruct [:routes, images: %{}, books: %{}]

  @typedoc """
  What rendering needs besides the blocks: the routes, and the site's
  images and books by public id (books with `cover_image` preloaded).
  """
  @type context :: %__MODULE__{
          routes: Routes.t(),
          images: %{String.t() => Image.t()},
          books: %{String.t() => Book.t()}
        }

  @doc "Builds a rendering context."
  @spec context(Routes.t(), map(), map()) :: context()
  def context(%Routes{} = routes, images \\ %{}, books \\ %{}),
    do: %__MODULE__{routes: routes, images: images, books: books}

  @doc """
  Renders a list of blocks. Returns safe HTML for templates.
  """
  @spec render([map()] | nil, context()) :: Phoenix.HTML.safe()
  def render(blocks, %__MODULE__{} = context) do
    {:safe, blocks |> ContentBlocks.normalize() |> Enum.map(&render_block(&1, context))}
  end

  @doc "Renders a list of blocks to a string."
  @spec to_html([map()] | nil, context()) :: String.t()
  def to_html(blocks, context) do
    {:safe, iodata} = render(blocks, context)
    IO.iodata_to_binary(iodata)
  end

  @doc "Renders one (normalized) block to iodata."
  @spec render_block(map(), context()) :: iodata()
  def render_block(%{"type" => "paragraph", "text" => text}, _context),
    do: ["<p>", sanitize(text), "</p>"]

  def render_block(%{"type" => "header", "level" => level, "text" => text}, _context) do
    tag = "h#{level}"
    ["<", tag, ">", sanitize(text), "</", tag, ">"]
  end

  def render_block(%{"type" => "list", "style" => style, "items" => items}, _context),
    do: list(style, items)

  def render_block(%{"type" => "quote", "text" => text, "caption" => caption}, _context) do
    cite = if present?(caption), do: ["<cite>", sanitize(caption), "</cite>"], else: []
    ["<blockquote><p>", sanitize(text), "</p>", cite, "</blockquote>"]
  end

  def render_block(%{"type" => "code", "code" => code}, _context),
    do: ["<pre><code>", escape(code), "</code></pre>"]

  def render_block(%{"type" => "image", "image_id" => image_id} = block, context) do
    case Map.get(context.images, image_id) do
      %Image{} = image -> image(image, block["caption"], context.routes)
      nil -> []
    end
  end

  def render_block(%{"type" => "table", "content" => rows} = block, _context) do
    rows = if is_list(rows), do: Enum.filter(rows, &is_list/1), else: []

    {head, body} =
      case {block["with_headings"], rows} do
        {true, [first | rest]} -> {["<thead>", row(first), "</thead>"], rest}
        _ -> {[], rows}
      end

    ["<table>", head, "<tbody>", Enum.map(body, &row/1), "</tbody></table>"]
  end

  def render_block(%{"type" => "embed"} = block, _context) do
    if is_binary(block["embed"]) and Sanitizer.safe_url?(block["embed"]) do
      src = String.replace(block["embed"], "youtube.com/embed/", "youtube-nocookie.com/embed/")

      caption =
        if present?(block["caption"]),
          do: ["<figcaption>", sanitize(block["caption"]), "</figcaption>"],
          else: []

      [
        "<figure><iframe src=\"",
        escape(src),
        "\"",
        size_attribute("width", block["width"]),
        size_attribute("height", block["height"]),
        " frameborder=\"0\" allowfullscreen></iframe>",
        caption,
        "</figure>"
      ]
    else
      []
    end
  end

  def render_block(%{"type" => "book", "book_public_id" => public_id}, context) do
    case Map.get(context.books, public_id) do
      %Book{} = book -> book(book, context.routes)
      nil -> []
    end
  end

  def render_block(_block, _context), do: []

  defp list(_style, []), do: []

  defp list(style, items) when is_list(items) do
    tag = if style == "ol", do: "ol", else: "ul"

    # Nested lists keep the style of the block, like Rails.
    items =
      Enum.map(items, fn item ->
        ["<li>", sanitize(item["content"]), list(tag, item["items"] || []), "</li>"]
      end)

    ["<", tag, ">", items, "</", tag, ">"]
  end

  defp row(cells) do
    ["<tr>", Enum.map(cells, &["<td>", sanitize(&1), "</td>"]), "</tr>"]
  end

  defp image(%Image{} = image, caption, routes) do
    caption = caption || ""

    figcaption =
      if present?(caption), do: ["<figcaption>", sanitize(caption), "</figcaption>"], else: []

    [
      "<picture><source srcset=\"",
      escape(Routes.image_srcset(routes, image)),
      "\" type=\"image/webp\"><img loading=\"lazy\"",
      optional_attribute("height", image.height),
      optional_attribute("width", image.width),
      " src=\"",
      escape(Routes.image_url(routes, image, :desktop_x1_jpg)),
      "\" alt=\"",
      escape(ContentBlocks.strip_tags(caption)),
      "\" />",
      figcaption,
      "</picture>"
    ]
  end

  defp book(%Book{} = book, routes) do
    cover =
      cond do
        match?(%Image{}, book.cover_image) ->
          [
            "<img src=\"",
            escape(Routes.image_url(routes, book.cover_image, :mobile_x1_webp)),
            "\" alt=\"",
            escape(book.title),
            "\" class=\"book-cover\">"
          ]

        present?(book.emoji) ->
          ["<span class=\"book-emoji\">", escape(book.emoji), "</span>"]

        true ->
          []
      end

    [
      "<div class=\"book-card book-card--detail\"><div class=\"book-card-header\">",
      cover,
      "<div class=\"book-info\"><div class=\"book-title\">",
      escape(book.title),
      "</div><div class=\"book-author\">",
      escape(book.author),
      "</div></div></div></div>"
    ]
  end

  defp size_attribute(name, value) do
    case size(value) do
      nil -> []
      size -> [" ", name, "=\"", size, "\""]
    end
  end

  # Embed sizes are numbers (or numeric strings); anything else is dropped.
  defp size(value) when is_integer(value) and value >= 0, do: Integer.to_string(value)

  defp size(value) when is_binary(value) do
    if value =~ ~r/\A\d{1,5}%?\z/, do: value
  end

  defp size(_value), do: nil

  defp optional_attribute(_name, nil), do: []
  defp optional_attribute(name, value), do: [" ", name, "=\"", escape(value), "\""]

  defp sanitize(html), do: Sanitizer.sanitize(html)

  defp escape(nil), do: ""

  defp escape(value),
    do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
