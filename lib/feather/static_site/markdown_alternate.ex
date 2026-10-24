defmodule Feather.StaticSite.MarkdownAlternate do
  @moduledoc """
  The Markdown alternate of the home page, a post, page or project: the
  page's content without the theme's markup, for clients that ask for
  `text/markdown` (ADR 0030). YAML front matter with the title (the name
  in the page's `<title>`: a short post's meta title,
  `Feather.StaticSite.ThemeHelpers.post_meta_title/1`), the canonical
  URL, the publish date (posts) and the tags; then the title as a
  level-one heading, the book a review is about, a project's description,
  the content and a project's links. The home page holds the homepage's
  content and all posts, each with its title, date and excerpt; a books
  page adds the bookshelf by year, a projects page the projects with their
  description and links.

  Blocks (see `Feather.Content.Blocks`) render here with the context of
  `Feather.StaticSite.Blocks`, independently of the HTML: inline HTML
  converts with `Feather.Content.HTML.to_markdown/2`, images link their
  largest content variant, code and diagrams show their source unhighlighted.
  Links and images use the absolute URLs of the context's routes, which
  should be canonical.
  """

  use Gettext, backend: Feather.StaticSite.Gettext

  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Content.{HTML, Markdown, Page, Post, Project}
  alias Feather.Media.Image
  alias Feather.StaticSite.{Blocks, Routes, SiteData, ThemeHelpers}

  @yaml_unsafe ~r/[\x00-\x08\x0B-\x1F\x7F-\x9F\x{FFFE}\x{FFFF}]/u

  @typedoc "What has a Markdown alternate: the home page or a post, page or project."
  @type target :: :home | Post.t() | Page.t() | Project.t()

  @doc """
  Renders the Markdown alternate of the home page or of a post (its book
  preloaded), page or project of the site `data`, addressed by `routes`
  (canonical) and its blocks rendered with `context`.
  """
  @spec render(SiteData.t(), Routes.t(), target(), Blocks.context()) :: iodata()
  def render(%SiteData{} = data, %Routes{} = routes, :home, context) do
    url = Routes.home_url(routes)
    content = if data.homepage, do: data.homepage.content, else: []

    document(
      [title: data.site.title, url: url],
      [render_blocks(content, context, url), post_list(data.posts, routes)]
    )
  end

  def render(%SiteData{}, %Routes{} = routes, %Post{} = post, context) do
    url = Routes.post_url(routes, post)

    document(
      [
        title: ThemeHelpers.post_meta_title(post),
        url: url,
        date: DateTime.to_date(post.publish_at),
        tags: Content.tag_list(post)
      ],
      [review(post), render_blocks(post.content, context, url)]
    )
  end

  def render(%SiteData{} = data, %Routes{} = routes, %Page{} = page, context) do
    url = Routes.page_url(routes, page)

    document(
      [title: ThemeHelpers.page_label(data.site, page), url: url, tags: Content.tag_list(page)],
      [render_blocks(page.content, context, url), page_list(data, routes, page)]
    )
  end

  def render(%SiteData{}, %Routes{} = routes, %Project{} = project, context) do
    url = Routes.project_url(routes, project)

    document(
      [title: project.title, url: url, tags: Content.tag_list(project)],
      [
        project_summary(project, url),
        render_blocks(project.content, context, url),
        project_links(project, url)
      ]
    )
  end

  defp document(front_matter, sections) do
    [
      "---\n",
      Enum.map(front_matter, fn {key, value} -> yaml_field(Atom.to_string(key), value) end),
      "---\n\n",
      paragraphs([title_heading(front_matter[:title]) | sections]),
      "\n"
    ]
  end

  defp yaml_field(_key, []), do: []

  defp yaml_field(key, values) when is_list(values),
    do: [key, ":\n", Enum.map(values, &["  - ", yaml_string(&1), "\n"])]

  defp yaml_field(key, %Date{} = date), do: [key, ": ", Date.to_iso8601(date), "\n"]
  defp yaml_field(key, text), do: [key, ": ", yaml_string(text), "\n"]

  # A JSON string is a YAML string in double quotes; YAML readers reject the control
  # characters and noncharacters JSON leaves as they are.
  defp yaml_string(text),
    do: Jason.encode!(String.replace(text || "", @yaml_unsafe, ""))

  defp title_heading(title) do
    case Markdown.escape(title) do
      "" -> ""
      markdown -> Markdown.heading(1, markdown)
    end
  end

  defp post_list([], _routes), do: ""

  defp post_list(posts, routes) do
    heading = Markdown.heading(2, Markdown.escape(gettext("Posts")))
    paragraphs([heading | Enum.map(posts, &post_entry(&1, routes))])
  end

  defp post_entry(post, routes) do
    paragraphs([
      linked_heading(3, ThemeHelpers.post_meta_title(post), Routes.post_url(routes, post)),
      Date.to_iso8601(DateTime.to_date(post.publish_at)),
      Markdown.escape(ContentBlocks.excerpt(post.content))
    ])
  end

  defp page_list(data, routes, %Page{page_type: "books"}) do
    data.books
    |> ThemeHelpers.books_by_year()
    |> Enum.map_join("\n\n", fn {year, books} ->
      lines = Enum.map_join(books, "\n", &("- " <> shelf_line(routes, &1)))
      Markdown.heading(2, Integer.to_string(year)) <> "\n\n" <> lines
    end)
  end

  defp page_list(data, routes, %Page{page_type: "projects"}) do
    data.projects
    |> ThemeHelpers.sort_projects()
    |> Enum.map(fn project ->
      url = Routes.project_url(routes, project)

      paragraphs([
        linked_heading(2, project.title, url),
        project_summary(project, url),
        link_items(project, url)
      ])
    end)
    |> paragraphs()
  end

  defp page_list(_data, _routes, _page), do: ""

  defp linked_heading(level, title, url),
    do: Markdown.heading(level, Markdown.link(Markdown.escape(title), url))

  defp shelf_line(routes, book), do: book_line(book, review_url(routes, book), book.read_at)

  defp review_url(routes, book),
    do: if(ThemeHelpers.review_linked?(book), do: Routes.post_url(routes, book.post))

  defp review(post) do
    case ThemeHelpers.book(post) do
      %Book{} = book -> book_line(book, nil)
      nil -> ""
    end
  end

  defp project_summary(%Project{short_description: text}, url) do
    text
    |> ThemeHelpers.simple_paragraphs()
    |> Enum.map(&HTML.to_markdown(&1, url))
    |> paragraphs()
  end

  defp project_links(project, url) do
    case link_items(project, url) do
      "" -> ""
      items -> Markdown.heading(2, Markdown.escape(gettext("Links"))) <> "\n\n" <> items
    end
  end

  defp link_items(project, base_url) do
    project
    |> ThemeHelpers.project_links()
    |> Enum.map_join("\n", fn link ->
      url = Markdown.absolute_url(link.url, base_url)
      label = if ThemeHelpers.present?(link.label), do: link.label, else: url
      "- " <> Markdown.link(Markdown.escape(label), url)
    end)
  end

  @doc """
  Renders blocks to Markdown, separated by blank lines; relative links in
  their inline HTML are resolved against `base_url`, the URL of the page.
  """
  @spec render_blocks([map()] | nil, Blocks.context(), String.t()) :: String.t()
  def render_blocks(blocks, %Blocks{} = context, base_url) do
    {markdowns, _last_list} =
      blocks
      |> ContentBlocks.normalize()
      |> Enum.map_reduce(nil, &render_next(&1, &2, context, base_url))

    paragraphs(markdowns)
  end

  # A list right after a list of its style takes the other markers (`*`, `1)`), or
  # CommonMark would continue that list.
  defp render_next(%{"type" => "list"} = block, last_list, _context, base_url) do
    %{"style" => style, "items" => items} = block
    markers = if last_list == {style, :first}, do: :second, else: :first

    case list(style, markers, items, base_url) do
      "" -> {"", last_list}
      markdown -> {markdown, {style, markers}}
    end
  end

  defp render_next(block, last_list, context, base_url) do
    case render_block(block, context, base_url) do
      "" -> {"", last_list}
      markdown -> {markdown, nil}
    end
  end

  defp paragraphs(markdowns), do: markdowns |> Enum.reject(&(&1 == "")) |> Enum.join("\n\n")

  defp render_block(%{"type" => "paragraph", "text" => text}, _context, base_url),
    do: HTML.to_markdown(text, base_url)

  defp render_block(%{"type" => "header", "level" => level, "text" => text}, _context, base_url) do
    case text |> HTML.to_markdown(base_url) |> one_line() do
      "" -> ""
      markdown -> Markdown.heading(level, markdown)
    end
  end

  defp render_block(%{"type" => "quote"} = block, _context, base_url) do
    source =
      case HTML.to_markdown(block["caption"], base_url) do
        "" -> ""
        caption -> "— " <> caption
      end

    case paragraphs([HTML.to_markdown(block["text"], base_url), source]) do
      "" ->
        ""

      quoted ->
        quoted |> String.split("\n") |> Enum.map_join("\n", &String.trim_trailing("> " <> &1))
    end
  end

  defp render_block(%{"type" => "code", "code" => code} = block, _context, _base_url) do
    if ThemeHelpers.present?(code),
      do: Markdown.code_block(code, Blocks.code_language(block["language"])),
      else: ""
  end

  defp render_block(%{"type" => "image", "image_id" => image_id} = block, context, _base_url) do
    with %Image{} = image <- Map.get(context.images, image_id),
         %{} = variant <- Blocks.largest_content_variant(image, context) do
      Markdown.image(plain(block["caption"]), Routes.image_url(context.routes, image, variant))
    else
      _missing -> ""
    end
  end

  defp render_block(%{"type" => "table", "content" => rows} = block, _context, base_url),
    do: table(rows, block["with_headings"] == true, base_url)

  defp render_block(%{"type" => "embed"} = block, _context, base_url) do
    case embed_url(block) do
      nil -> ""
      url -> Markdown.link(embed_label(block["caption"]), url, base_url)
    end
  end

  defp render_block(%{"type" => "book", "book_public_id" => public_id}, context, _base_url) do
    case Map.get(context.books, public_id) do
      %Book{} = book -> book_line(book, review_url(context.routes, book))
      nil -> ""
    end
  end

  defp render_block(%{"type" => "diagram", "code" => code} = block, _context, base_url) do
    if ThemeHelpers.present?(code) do
      paragraphs([Markdown.code_block(code, "d2"), HTML.to_markdown(block["caption"], base_url)])
    else
      ""
    end
  end

  defp render_block(_block, _context, _base_url), do: ""

  defp one_line(markdown), do: String.replace(markdown, "\\\n", " ")

  defp plain(html), do: Markdown.escape(ContentBlocks.strip_tags(html || ""))

  # A bare marker under text would make it a setext heading, so blank items are left out; one
  # with only nested items starts with its list (`- - b`).
  defp list(style, markers, items, base_url) do
    items
    |> Enum.map(fn item ->
      [HTML.to_markdown(item["content"], base_url), list(style, markers, item["items"], base_url)]
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.join("\n")
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {body, number} ->
      marker = list_marker(style, markers, number)
      indent = "\n" <> String.duplicate(" ", String.length(marker) + 1)
      marker <> " " <> String.replace(body, "\n", indent)
    end)
  end

  defp list_marker("ol", :first, number), do: "#{number}."
  defp list_marker("ol", :second, number), do: "#{number})"
  defp list_marker(_ul, :first, _number), do: "-"
  defp list_marker(_ul, :second, _number), do: "*"

  # Tables need a header row; one without headings gets an empty one.
  defp table(rows, with_headings?, base_url) do
    columns = (rows || []) |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    rows = Enum.map(rows || [], &table_row(&1, columns, base_url))

    cond do
      columns == 0 -> ""
      with_headings? -> table_lines(hd(rows), columns, tl(rows))
      true -> table_lines(List.duplicate("", columns), columns, rows)
    end
  end

  defp table_row(cells, columns, base_url) do
    cells
    |> Enum.map(&table_cell(&1, base_url))
    |> Kernel.++(List.duplicate("", columns - length(cells)))
  end

  defp table_cell(html, base_url) do
    html
    |> HTML.to_markdown(base_url)
    |> String.replace("\\\n", "<br>")
    |> String.replace("|", "\\|")
  end

  defp table_lines(head, columns, body) do
    Enum.map_join(
      [head, List.duplicate("---", columns) | body],
      "\n",
      &("| " <> Enum.join(&1, " | ") <> " |")
    )
  end

  defp embed_url(block) do
    Enum.find(
      [block["source"], block["embed"]],
      &(ThemeHelpers.present?(&1) and HTML.safe_url?(&1))
    )
  end

  defp embed_label(caption) do
    case plain(caption) do
      "" -> Markdown.escape(gettext("Embedded content"))
      label -> label
    end
  end

  defp book_line(%Book{} = book, review_url, read_at \\ nil) do
    rating = if book.rating, do: ThemeHelpers.rating_label(book.rating)
    date = if read_at, do: Date.to_iso8601(read_at), else: ""

    [
      book_title(book.title, review_url),
      Markdown.escape(book.author),
      Markdown.escape(rating),
      date
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
  end

  defp book_title(title, review_url) do
    cond do
      ThemeHelpers.blank?(title) -> ""
      review_url -> Markdown.link("*" <> Markdown.escape(title) <> "*", review_url)
      true -> "*" <> Markdown.escape(title) <> "*"
    end
  end
end
