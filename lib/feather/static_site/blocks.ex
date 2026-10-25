defmodule Feather.StaticSite.Blocks do
  @moduledoc """
  Renders content blocks (see `Feather.Content.Blocks`) to the HTML of the
  static site.

  Inline HTML (paragraphs, headers, list items, quotes, captions, table
  cells) goes through `Feather.Content.HTML.sanitize/3`, its relative links
  resolved against the context's `base_url` when it has one; everything
  else is escaped. Image and book blocks look their records up in the maps given
  in the context (by public id) and render nothing when the record is
  missing; an image's alt text is its own, else its caption. Diagram
  blocks look their SVG file up by their source (see
  `Feather.Diagrams.render_all/2`) and show the source as d2 code when the
  diagram was not rendered. Code blocks look their highlighted HTML up
  by code and language (see `Feather.Highlighting.highlight_all/2`) and
  show the escaped code when there is none. Without inline images, image
  blocks render nothing and a book block is one paragraph of emoji, title,
  author and rating, without cover.
  """

  use Gettext, backend: Feather.StaticSite.Gettext

  alias Feather.Books.Book
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Content.HTML
  alias Feather.Media.{Image, Variants}
  alias Feather.StaticSite.{Routes, ThemeHelpers}

  @enforce_keys [:routes, :content_image_sizes]
  defstruct [
    :routes,
    :content_image_sizes,
    image_variants: %{},
    book_cover_sizes: "80px",
    inline_images: true,
    base_url: nil,
    images: %{},
    books: %{},
    diagrams: %{},
    highlights: %{}
  ]

  @typedoc """
  What rendering needs besides the blocks: the routes, the `sizes`
  attribute of content images
  (`c:Feather.StaticSite.Theme.content_image_sizes/0`) and of the cover in
  a book block (`c:Feather.StaticSite.Theme.book_cover_sizes/0`), the
  theme's variant sizes per image role
  (`c:Feather.StaticSite.Theme.image_variants/0`), whether images render
  inline (the fediverse documents carry them as attachments instead, so
  they do not change with the theme), the URL relative links resolve
  against (nil keeps them relative), the site's images and books by
  public id (books with `cover_image` preloaded and their
  review as `post` where the site shows it), the file names of the
  rendered diagrams by source and the highlighted HTML of the code blocks
  by `{code, language}`.
  """
  @type context :: %__MODULE__{
          routes: Routes.t(),
          content_image_sizes: String.t(),
          image_variants: %{atom() => [pos_integer()]},
          book_cover_sizes: String.t(),
          inline_images: boolean(),
          base_url: String.t() | nil,
          images: %{String.t() => Image.t()},
          books: %{String.t() => Book.t()},
          diagrams: %{String.t() => String.t()},
          highlights: %{{String.t(), term()} => String.t()}
        }

  @doc """
  Builds a rendering context. Options: `:content_image_sizes` (required),
  `:image_variants`, `:book_cover_sizes`, `:inline_images` (default:
  true), `:base_url`, `:images`, `:books`, `:diagrams` and `:highlights`
  (see `t:context/0`, default: none).
  """
  @spec context(Routes.t(), keyword()) :: context()
  def context(%Routes{} = routes, opts), do: struct!(__MODULE__, [routes: routes] ++ opts)

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

  @doc "Whether a (normalized) block shows anything: an empty paragraph does not."
  @spec visible?(map()) :: boolean()
  def visible?(%{"type" => "paragraph", "text" => text}),
    do: present?(ContentBlocks.strip_tags(text || ""))

  def visible?(_block), do: true

  @doc "Renders one (normalized) block to iodata."
  @spec render_block(map(), context()) :: iodata()
  def render_block(%{"type" => "paragraph", "text" => text} = block, context),
    do: if(visible?(block), do: ["<p>", sanitize(text, context), "</p>"], else: [])

  def render_block(%{"type" => "header", "level" => level, "text" => text}, context) do
    tag = "h#{level}"
    ["<", tag, ">", sanitize(text, context), "</", tag, ">"]
  end

  def render_block(%{"type" => "list", "style" => style, "items" => items}, context),
    do: list(style, items, context)

  def render_block(%{"type" => "quote", "text" => text, "caption" => caption}, context) do
    cite = if present?(caption), do: ["<cite>", sanitize(caption, context), "</cite>"], else: []
    ["<blockquote><p>", sanitize(text, context), "</p>", cite, "</blockquote>"]
  end

  def render_block(%{"type" => "code", "code" => code} = block, context) do
    case Map.get(context.highlights, {code, block["language"]}) do
      nil -> code_block(code, code_language(block["language"]))
      html -> code_block({:safe, html}, code_language(block["language"]))
    end
  end

  def render_block(%{"type" => "image"}, %{inline_images: false}), do: []

  def render_block(%{"type" => "image", "image_id" => image_id} = block, context) do
    case Map.get(context.images, image_id) do
      %Image{} = image -> image(image, block["caption"], context)
      nil -> []
    end
  end

  def render_block(%{"type" => "table", "content" => rows} = block, context) do
    rows = if is_list(rows), do: Enum.filter(rows, &is_list/1), else: []

    {head, body} =
      case {block["with_headings"], rows} do
        {true, [first | rest]} -> {["<thead>", row(first, "th", context), "</thead>"], rest}
        _ -> {[], rows}
      end

    ["<table>", head, "<tbody>", Enum.map(body, &row(&1, "td", context)), "</tbody></table>"]
  end

  def render_block(%{"type" => "embed"} = block, context) do
    if is_binary(block["embed"]) and HTML.safe_url?(block["embed"]),
      do: embed(block, context),
      else: []
  end

  def render_block(%{"type" => "book", "book_public_id" => public_id}, context) do
    case Map.get(context.books, public_id) do
      %Book{} = book -> book(book, context)
      nil -> []
    end
  end

  def render_block(%{"type" => "diagram", "code" => code} = block, context) do
    case Map.get(context.diagrams, code) do
      nil -> if present?(code), do: code_block(code, "d2"), else: []
      name -> diagram(name, block["caption"], context)
    end
  end

  def render_block(_block, _context), do: []

  @doc "The alt text of a content image: its own, else the caption of its block as text."
  @spec image_alt(Image.t(), String.t() | nil) :: String.t()
  def image_alt(%Image{alt: alt}, caption) do
    if present?(alt), do: alt, else: ContentBlocks.strip_tags(caption || "")
  end

  @doc "The largest variant the theme gives a content image, nil if it gives none."
  @spec largest_content_variant(Image.t(), context()) :: Variants.variant() | nil
  def largest_content_variant(%Image{width: width, height: height}, %__MODULE__{} = context) do
    context.image_variants
    |> Map.get(:content, [])
    |> Variants.for_image(width, height)
    |> List.last()
  end

  @doc """
  The language a code block is labelled with: its name, nil for plain text
  and for what is no name (imported content carries code fragments there).
  """
  @spec code_language(term()) :: String.t() | nil
  def code_language(language) when is_binary(language) do
    language = String.trim(language)

    if language not in ["plaintext", "text"] and language =~ ~r/\A[A-Za-z0-9+#._-]{1,20}\z/,
      do: language
  end

  def code_language(_language), do: nil

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

  defp embed(block, context) do
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
      figcaption(block["caption"], context),
      "</figure>"
    ]
  end

  defp embed_title(caption) do
    title = if present?(caption), do: ContentBlocks.strip_tags(caption), else: ""
    if String.trim(title) == "", do: gettext("Embedded content"), else: title
  end

  defp diagram(name, caption, context) do
    alt = ContentBlocks.strip_tags(caption)
    alt = if present?(alt), do: alt, else: gettext("Diagram")

    [
      "<figure class=\"diagram\"><img loading=\"lazy\" src=\"",
      escape(Routes.diagram_url(context.routes, name)),
      "\" alt=\"",
      escape(alt),
      "\">",
      figcaption(caption, context),
      "</figure>"
    ]
  end

  defp list(_style, [], _context), do: []

  defp list(style, items, context) when is_list(items) do
    tag = if style == "ol", do: "ol", else: "ul"

    items =
      Enum.map(items, fn item ->
        [
          "<li>",
          sanitize(item["content"], context),
          list(tag, item["items"] || [], context),
          "</li>"
        ]
      end)

    ["<", tag, ">", items, "</", tag, ">"]
  end

  defp row(cells, tag, context) do
    ["<tr>", Enum.map(cells, &["<", tag, ">", sanitize(&1, context), "</", tag, ">"]), "</tr>"]
  end

  defp image(%Image{} = image, caption, context) do
    [
      "<figure><img loading=\"lazy\"",
      optional_attribute("height", image.height),
      optional_attribute("width", image.width),
      sources(image, :content, context.content_image_sizes, context),
      " alt=\"",
      escape(image_alt(image, caption)),
      "\" />",
      figcaption(caption, context),
      "</figure>"
    ]
  end

  defp sources(image, role, sizes, %{routes: routes, image_variants: variants}) do
    {:safe, attributes} =
      ThemeHelpers.image_sources(routes, image, Map.get(variants, role, []), sizes)

    attributes
  end

  # Fediverse servers keep little more than paragraphs, links and emphasis
  # of a post's markup, so the book card turns into one line there.
  defp book(%Book{} = book, %{inline_images: false}) do
    [
      "<p>",
      if(present?(book.emoji), do: [escape(book.emoji), " "], else: []),
      "<strong>",
      escape(book.title),
      "</strong> – ",
      escape(book.author),
      rating_stars(book.rating),
      "</p>"
    ]
  end

  defp book(%Book{} = book, context) do
    [
      "<figure class=\"book-card book-card--detail\">",
      book_mark(book, context),
      "<figcaption class=\"book-info\"><cite class=\"book-title\">",
      escape(book.title),
      "</cite><span class=\"book-author\">",
      escape(book.author),
      "</span></figcaption></figure>"
    ]
  end

  defp book_mark(%Book{cover_image: %Image{} = cover}, context) do
    [
      "<img",
      sources(cover, :book_cover, context.book_cover_sizes, context),
      " alt=\"\" class=\"book-cover\"",
      optional_attribute("width", cover.width),
      optional_attribute("height", cover.height),
      " loading=\"lazy\">"
    ]
  end

  defp book_mark(%Book{emoji: emoji}, _context) do
    if present?(emoji), do: ["<span class=\"book-emoji\">", escape(emoji), "</span>"], else: []
  end

  defp rating_stars(rating) when is_integer(rating) do
    stars = rating |> max(0) |> min(5)
    [" · ", String.duplicate("★", stars), String.duplicate("☆", 5 - stars)]
  end

  defp rating_stars(nil), do: []

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

  defp size(value) when is_integer(value) and value >= 0, do: Integer.to_string(value)

  defp size(value) when is_binary(value) do
    if value =~ ~r/\A\d{1,5}%?\z/, do: value
  end

  defp size(_value), do: nil

  defp optional_attribute(_name, nil), do: []
  defp optional_attribute(name, value), do: [" ", name, "=\"", escape(value), "\""]

  defp figcaption(caption, context) do
    if present?(caption),
      do: ["<figcaption>", sanitize(caption, context), "</figcaption>"],
      else: []
  end

  defp sanitize(html, context), do: HTML.sanitize(html, :published, base_url: context.base_url)

  defp escape(nil), do: ""

  defp escape(value),
    do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
