defmodule Feather.StaticSite.Blocks do
  @moduledoc """
  Renders content blocks (see `Feather.Content.Blocks`) to the HTML of the
  static site.

  Inline HTML (paragraphs, headers, list items, quotes, captions, table
  cells) goes through `Feather.Content.HTML.sanitize/1`; everything else is
  escaped. Image and book blocks look their records up in the maps given
  in the context (by public id) and render nothing when the record is
  missing. Diagram blocks look their SVG file up by their source (see
  `Feather.Diagrams.render_all/2`) and show the source as d2 code when
  the diagram was not rendered. Code blocks look their highlighted HTML up
  by code and language (see `Feather.Highlighting.highlight_all/2`) and
  show the escaped code when there is none.
  """

  use Gettext, backend: Feather.StaticSite.Gettext

  alias Feather.Books.Book
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Content.HTML
  alias Feather.Media.Image
  alias Feather.StaticSite.Routes

  # The text column of the feather theme: 35rem, or the viewport less two clamp(1rem, 4vw, 1.5rem) gutters.
  @content_image_sizes "(min-width: 38rem) 35rem, (min-width: 25rem) 92vw, calc(100vw - 2rem)"

  @enforce_keys [:routes]
  defstruct [:routes, images: %{}, books: %{}, diagrams: %{}, highlights: %{}]

  @typedoc """
  What rendering needs besides the blocks: the routes, the site's images
  and books by public id (books with `cover_image` preloaded), the file
  names of the rendered diagrams by source and the highlighted HTML of the
  code blocks by `{code, language}`.
  """
  @type context :: %__MODULE__{
          routes: Routes.t(),
          images: %{String.t() => Image.t()},
          books: %{String.t() => Book.t()},
          diagrams: %{String.t() => String.t()},
          highlights: %{{String.t(), term()} => String.t()}
        }

  @doc """
  Builds a rendering context. Options: `:images`, `:books`, `:diagrams`
  and `:highlights` (see `t:context/0`, default: none).
  """
  @spec context(Routes.t(), keyword()) :: context()
  def context(%Routes{} = routes, opts \\ []),
    do: struct!(%__MODULE__{routes: routes}, opts)

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

  def render_block(%{"type" => "code", "code" => code} = block, context) do
    case Map.get(context.highlights, {code, block["language"]}) do
      nil -> code_block(code, code_language(block["language"]))
      html -> code_block({:safe, html}, code_language(block["language"]))
    end
  end

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
        {true, [first | rest]} -> {["<thead>", row(first, "th"), "</thead>"], rest}
        _ -> {[], rows}
      end

    ["<table>", head, "<tbody>", Enum.map(body, &row(&1, "td")), "</tbody></table>"]
  end

  def render_block(%{"type" => "embed"} = block, _context) do
    if is_binary(block["embed"]) and HTML.safe_url?(block["embed"]), do: embed(block), else: []
  end

  def render_block(%{"type" => "book", "book_public_id" => public_id}, context) do
    case Map.get(context.books, public_id) do
      %Book{} = book -> book(book, context.routes)
      nil -> []
    end
  end

  def render_block(%{"type" => "diagram", "code" => code} = block, context) do
    case Map.get(context.diagrams, code) do
      nil -> if present?(code), do: code_block(code, "d2"), else: []
      name -> diagram(name, block["caption"], context.routes)
    end
  end

  def render_block(_block, _context), do: []

  defp code_block(code, nil), do: ["<pre><code>", code_html(code), "</code></pre>"]

  defp code_block(code, language) do
    [
      "<pre data-language=\"",
      language,
      "\"><code class=\"language-",
      language,
      "\">",
      code_html(code),
      "</code></pre>"
    ]
  end

  defp code_html({:safe, html}), do: html
  defp code_html(code), do: escape(code)

  defp embed(block) do
    src = String.replace(block["embed"], "youtube.com/embed/", "youtube-nocookie.com/embed/")

    [
      "<figure class=\"embed\"><iframe src=\"",
      escape(src),
      "\" title=\"",
      escape(embed_title(block["caption"])),
      "\"",
      size_attribute("width", block["width"]),
      size_attribute("height", block["height"]),
      aspect_ratio(block["width"], block["height"]),
      " allowfullscreen></iframe>",
      figcaption(block["caption"]),
      "</figure>"
    ]
  end

  defp embed_title(caption) do
    title = if present?(caption), do: ContentBlocks.strip_tags(caption), else: ""
    if String.trim(title) == "", do: gettext("Embedded content"), else: title
  end

  defp diagram(name, caption, routes) do
    alt = ContentBlocks.strip_tags(caption)
    alt = if present?(alt), do: alt, else: gettext("Diagram")

    [
      "<figure class=\"diagram\"><img loading=\"lazy\" src=\"",
      escape(Routes.diagram_url(routes, name)),
      "\" alt=\"",
      escape(alt),
      "\">",
      figcaption(caption),
      "</figure>"
    ]
  end

  defp list(_style, []), do: []

  defp list(style, items) when is_list(items) do
    tag = if style == "ol", do: "ol", else: "ul"

    # Nested lists keep the style of the block.
    items =
      Enum.map(items, fn item ->
        ["<li>", sanitize(item["content"]), list(tag, item["items"] || []), "</li>"]
      end)

    ["<", tag, ">", items, "</", tag, ">"]
  end

  defp row(cells, tag) do
    ["<tr>", Enum.map(cells, &["<", tag, ">", sanitize(&1), "</", tag, ">"]), "</tr>"]
  end

  defp image(%Image{} = image, caption, routes) do
    [
      "<figure><picture><source srcset=\"",
      escape(Routes.image_srcset(routes, image)),
      "\" sizes=\"",
      @content_image_sizes,
      "\" type=\"image/webp\"><img loading=\"lazy\"",
      optional_attribute("height", image.height),
      optional_attribute("width", image.width),
      " src=\"",
      escape(Routes.image_url(routes, image, :desktop_x1_jpg)),
      "\" alt=\"",
      escape(ContentBlocks.strip_tags(caption)),
      "\" /></picture>",
      figcaption(caption),
      "</figure>"
    ]
  end

  defp book(%Book{} = book, routes) do
    cover =
      cond do
        match?(%Image{}, book.cover_image) ->
          [
            "<img src=\"",
            escape(Routes.image_url(routes, book.cover_image, :mobile_x1_webp)),
            "\" alt=\"\" class=\"book-cover\">"
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

  defp aspect_ratio(width, height) do
    case {pixels(width), pixels(height)} do
      {w, h} when is_integer(w) and is_integer(h) ->
        [" style=\"aspect-ratio: ", Integer.to_string(w), " / ", Integer.to_string(h), "\""]

      _ ->
        []
    end
  end

  defp pixels(value) do
    with size when is_binary(size) <- size(value),
         {pixels, ""} when pixels > 0 <- Integer.parse(size) do
      pixels
    else
      _ -> nil
    end
  end

  # Embed sizes are numbers (or numeric strings); anything else is dropped.
  defp size(value) when is_integer(value) and value >= 0, do: Integer.to_string(value)

  defp size(value) when is_binary(value) do
    if value =~ ~r/\A\d{1,5}%?\z/, do: value
  end

  defp size(_value), do: nil

  # Imported content carries code fragments as languages; only names make a label.
  defp code_language(language) when is_binary(language) do
    language = String.trim(language)

    if language not in ["plaintext", "text"] and language =~ ~r/\A[A-Za-z0-9+#._-]{1,20}\z/,
      do: language
  end

  defp code_language(_language), do: nil

  defp optional_attribute(_name, nil), do: []
  defp optional_attribute(name, value), do: [" ", name, "=\"", escape(value), "\""]

  defp figcaption(caption) do
    if present?(caption), do: ["<figcaption>", sanitize(caption), "</figcaption>"], else: []
  end

  defp sanitize(html), do: HTML.sanitize(html)

  defp escape(nil), do: ""

  defp escape(value),
    do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
