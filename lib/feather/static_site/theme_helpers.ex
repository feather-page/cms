defmodule Feather.StaticSite.ThemeHelpers do
  @moduledoc """
  What every theme's templates share: formatting of dates, ratings,
  projects and copyright notices, the `<head>` meta tags and the rules
  for `@font-face`. Imported into each theme by
  `use Feather.StaticSite.Theme`; every function runs in the site's
  language (`Feather.StaticSite.Gettext`).
  """

  use Gettext, backend: Feather.StaticSite.Gettext

  import Phoenix.HTML, only: [raw: 1]

  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Content.{HTML, Project}
  alias Feather.Media.Image
  alias Feather.Sites.SocialMediaService
  alias Feather.StaticSite.{Hue, Routes, SiteData}

  require EEx

  @jetbrains_mono_faces [{400, "normal"}, {700, "normal"}, {400, "italic"}]

  @doc """
  The meta tags of a page (title, robots, description, canonical URL,
  Open Graph), from the assigns `Feather.StaticSite.Renderer` builds.
  """
  EEx.function_from_file(
    :def,
    :head_meta,
    Path.join([__DIR__, "templates", "head_meta.html.eex"]),
    [:assigns],
    engine: Phoenix.HTML.Engine,
    trim: true
  )

  @doc """
  An `@font-face` rule for a font file of the theme, addressed from the
  site root (stylesheets are inlined, so relative URLs would depend on the
  page's depth). `weight` is a number, or a range like `"400 600"` for a
  variable font.
  """
  @spec font_face(
          Routes.t(),
          String.t(),
          pos_integer() | String.t(),
          [String.t()],
          String.t(),
          String.t()
        ) :: iodata()
  def font_face(%Routes{} = routes, family, weight, local_names, file, style \\ "normal") do
    locals = Enum.map(local_names, &~s[local("#{&1}"), ])
    url = routes |> Routes.font_url(file) |> css_string()

    [
      ~s[@font-face { font-family: "#{family}"; font-style: #{style}; font-weight: #{weight}; ],
      ~s[font-display: swap; src: ],
      locals,
      ~s[url("#{url}") format("woff2"); }\n]
    ]
  end

  @doc """
  The `@font-face` rules of JetBrains Mono, the code font every theme
  ships (see `jetbrains_mono_fonts/0`).
  """
  @spec jetbrains_mono_faces(Routes.t()) :: iodata()
  def jetbrains_mono_faces(%Routes{} = routes) do
    for {weight, style} <- @jetbrains_mono_faces,
        do:
          font_face(
            routes,
            "JetBrains Mono",
            weight,
            [],
            jetbrains_mono_file(weight, style),
            style
          )
  end

  @doc """
  The files of JetBrains Mono with their content types, for a theme's
  `fonts/0`: regular, bold and italic, Latin subset of
  @fontsource/jetbrains-mono 5.3.0, SIL Open Font License.
  """
  @spec jetbrains_mono_fonts() :: %{String.t() => String.t()}
  def jetbrains_mono_fonts do
    @jetbrains_mono_faces
    |> Map.new(fn {weight, style} -> {jetbrains_mono_file(weight, style), "font/woff2"} end)
    |> Map.put("OFL-JetBrains-Mono.txt", "text/plain")
  end

  defp jetbrains_mono_file(weight, style), do: "jetbrains-mono-latin-#{weight}-#{style}.woff2"

  # HTML escaping does not apply inside <style>; a CSS escape keeps the URL inside its string.
  defp css_string(text), do: String.replace(text, ~r/["\\<>\n]/, &"\\#{Base.encode16(&1)} ")

  @doc """
  The page numbers of the pagination: all pages up to 7, otherwise the
  first, the last, the current one and its neighbours (the first or last
  four near the ends), with `:gap` where numbers are left out.
  """
  @spec pagination_page_numbers(pos_integer(), pos_integer()) :: [pos_integer() | :gap]
  def pagination_page_numbers(_current, total) when total <= 7, do: Enum.to_list(1..total)

  def pagination_page_numbers(current, total) do
    ([1, total, current, current - 1, current + 1] ++ pages_near_end(current, total))
    |> Enum.filter(&(&1 >= 1 and &1 <= total))
    |> Enum.uniq()
    |> Enum.sort()
    |> insert_gaps()
  end

  defp pages_near_end(current, _total) when current <= 3, do: Enum.to_list(1..4)

  defp pages_near_end(current, total) when current >= total - 2,
    do: Enum.to_list((total - 3)..total)

  defp pages_near_end(_current, _total), do: []

  defp insert_gaps(pages) do
    pages
    |> Enum.reduce([], fn
      page, [previous | _] = acc when is_integer(previous) and page > previous + 1 ->
        [page, :gap | acc]

      page, acc ->
        [page | acc]
    end)
    |> Enum.reverse()
  end

  @doc ~s(A date in the long format of the current language: `"May 6, 2025"`, `"6. Mai 2025"`.)
  @spec format_date(DateTime.t() | Date.t() | nil) :: String.t()
  def format_date(date) do
    gettext_comment("Calendar.strftime format of a long date")
    strftime(date, gettext("%B %-d, %Y"))
  end

  @doc ~s(A date in the short format of the current language: `"Aug 12, 2026"`, `"12.08.2026"`.)
  @spec format_short_date(DateTime.t() | Date.t() | nil) :: String.t()
  def format_short_date(date) do
    gettext_comment("Calendar.strftime format of a short date, unambiguous in the language")
    strftime(date, gettext("%b %-d, %Y"))
  end

  @doc "A month and year in the current language: `\"Mar 2024\"`."
  @spec format_month(DateTime.t() | Date.t() | nil) :: String.t()
  def format_month(date) do
    gettext_comment("Calendar.strftime format of a month and year")
    strftime(date, gettext("%b %Y"))
  end

  defp strftime(nil, _format), do: ""

  defp strftime(%DateTime{} = datetime, format),
    do: datetime |> DateTime.to_date() |> strftime(format)

  defp strftime(%Date{} = date, format) do
    Calendar.strftime(date, format,
      month_names: &month_name/1,
      abbreviated_month_names: &abbreviated_month_name/1
    )
  end

  @doc "A date as a `<time>` element, formatted by `format` (`:long` or `:short`)."
  @spec time_tag(DateTime.t() | Date.t() | nil, :long | :short) :: Phoenix.HTML.safe()
  def time_tag(date, format \\ :long)
  def time_tag(nil, _format), do: {:safe, ""}

  def time_tag(%DateTime{} = datetime, format),
    do: datetime |> DateTime.to_date() |> time_tag(format)

  def time_tag(%Date{} = date, format) do
    text = if format == :short, do: format_short_date(date), else: format_date(date)

    {:safe, [~s(<time datetime="), Date.to_iso8601(date), ~s(">), escape(text), "</time>"]}
  end

  defp month_name(1), do: pgettext("month", "January")
  defp month_name(2), do: pgettext("month", "February")
  defp month_name(3), do: pgettext("month", "March")
  defp month_name(4), do: pgettext("month", "April")
  defp month_name(5), do: pgettext("month", "May")
  defp month_name(6), do: pgettext("month", "June")
  defp month_name(7), do: pgettext("month", "July")
  defp month_name(8), do: pgettext("month", "August")
  defp month_name(9), do: pgettext("month", "September")
  defp month_name(10), do: pgettext("month", "October")
  defp month_name(11), do: pgettext("month", "November")
  defp month_name(12), do: pgettext("month", "December")

  defp abbreviated_month_name(1), do: pgettext("abbreviated month", "Jan")
  defp abbreviated_month_name(2), do: pgettext("abbreviated month", "Feb")
  defp abbreviated_month_name(3), do: pgettext("abbreviated month", "Mar")
  defp abbreviated_month_name(4), do: pgettext("abbreviated month", "Apr")
  defp abbreviated_month_name(5), do: pgettext("abbreviated month", "May")
  defp abbreviated_month_name(6), do: pgettext("abbreviated month", "Jun")
  defp abbreviated_month_name(7), do: pgettext("abbreviated month", "Jul")
  defp abbreviated_month_name(8), do: pgettext("abbreviated month", "Aug")
  defp abbreviated_month_name(9), do: pgettext("abbreviated month", "Sep")
  defp abbreviated_month_name(10), do: pgettext("abbreviated month", "Oct")
  defp abbreviated_month_name(11), do: pgettext("abbreviated month", "Nov")
  defp abbreviated_month_name(12), do: pgettext("abbreviated month", "Dec")

  @doc "A rating of 1 to 5 as stars: `\"★★★☆☆\"`."
  @spec rating_stars(integer() | nil) :: String.t() | nil
  def rating_stars(nil), do: nil

  def rating_stars(rating) when is_integer(rating) do
    rating = rating |> max(0) |> min(5)
    String.duplicate("★", rating) <> String.duplicate("☆", 5 - rating)
  end

  @doc "A rating for screen readers: `\"4 of 5 stars\"`."
  @spec rating_label(integer()) :: String.t()
  def rating_label(rating) when is_integer(rating),
    do: gettext("%{rating} of 5 stars", rating: rating |> max(0) |> min(5))

  @doc "A rating as stars with a label for screen readers, in a span of `class`."
  @spec rating(integer(), String.t()) :: Phoenix.HTML.safe()
  def rating(rating, class) do
    {:safe,
     [
       ~s(<span class="),
       class,
       ~s(" role="img" aria-label="),
       rating_label(rating),
       ~s("><span aria-hidden="true">),
       rating_stars(rating),
       "</span></span>"
     ]}
  end

  @doc "The inline SVG of a social media icon, hidden from screen readers."
  @spec social_icon(String.t()) :: Phoenix.HTML.safe() | String.t()
  def social_icon(icon) do
    case SocialMediaService.svg(icon) do
      nil ->
        ""

      svg ->
        raw(
          String.replace(svg, "<svg ", ~s(<svg aria-hidden="true" focusable="false" ),
            global: false
          )
        )
    end
  end

  @doc """
  The copyright notice with `{{CurrentYear}}` replaced. Inline HTML is
  allowed, sanitized like content.
  """
  @spec copyright(String.t() | nil, integer()) :: Phoenix.HTML.safe()
  def copyright(text, year \\ Date.utc_today().year) do
    {:safe,
     (text || "")
     |> String.replace("{{CurrentYear}}", Integer.to_string(year))
     |> HTML.sanitize()}
  end

  @doc """
  Text as HTML paragraphs: blank lines separate paragraphs, single line
  breaks become `<br />`. Inline HTML is sanitized like content.
  """
  @spec simple_format(String.t() | nil) :: Phoenix.HTML.safe()
  def simple_format(text) do
    paragraphs =
      (text || "")
      |> String.replace(~r/\r\n?/, "\n")
      |> String.split(~r/\n\n+/)
      |> Enum.map(fn paragraph ->
        html =
          paragraph
          |> HTML.sanitize()
          |> String.replace(~r/([^\n]\n)(?=[^\n])/, "\\1<br />")

        ["<p>", html, "</p>"]
      end)

    {:safe, Enum.intersperse(paragraphs, "\n\n")}
  end

  @doc "Returns true if the image is an Unsplash photo whose photographer can be credited."
  @spec unsplash_credit?(Image.t() | nil) :: boolean()
  def unsplash_credit?(%Image{} = image),
    do: Image.unsplash?(image) and HTML.safe_url?(Image.unsplash_photographer_url(image))

  def unsplash_credit?(_image), do: false

  @doc "The Unsplash credit of a photo, linking the photographer and Unsplash."
  @spec photo_credit(Image.t()) :: Phoenix.HTML.safe()
  def photo_credit(%Image{} = image) do
    link = fn url, text ->
      IO.iodata_to_binary([
        ~s(<a href="),
        escape(url),
        ~s(" target="_blank" rel="noopener">),
        escape(text),
        "</a>"
      ])
    end

    raw(
      gettext("Photo by %{photographer} on %{unsplash}",
        photographer:
          link.(Image.unsplash_photographer_url(image), Image.unsplash_photographer_name(image)),
        unsplash: link.("https://unsplash.com", "Unsplash")
      )
    )
  end

  @doc ~s(` width="…" height="…"` for an `<img>` of the image, if its size is known.)
  @spec dimensions(Image.t() | nil) :: Phoenix.HTML.safe()
  def dimensions(%Image{width: width, height: height})
      when is_integer(width) and is_integer(height),
      do: raw(~s( width="#{width}" height="#{height}"))

  def dimensions(_image), do: {:safe, ""}

  # Open Graph wants language_TERRITORY; languages not listed here go without.
  @og_locales ~w(ar_AR cs_CZ da_DK de_DE el_GR en_US es_ES fi_FI fr_FR he_IL hu_HU it_IT ja_JP
                 ko_KR nl_NL pl_PL pt_PT ru_RU sv_SE tr_TR uk_UA zh_CN)
  @og_locale_by_language Map.new(@og_locales, &{binary_part(&1, 0, 2), &1})

  @doc "The Open Graph locale of a language, or nil."
  @spec og_locale(String.t() | nil) :: String.t() | nil
  def og_locale(language_code), do: Map.get(@og_locale_by_language, language_code)

  @doc "The hue of the site's colours, derived from its emoji (`Feather.StaticSite.Hue`)."
  @spec hue(Feather.Sites.Site.t()) :: integer()
  def hue(site), do: Hue.for_emoji(site.emoji)

  @doc "The book a post reviews, or nil."
  @spec book(Content.Post.t() | map()) :: Book.t() | nil
  def book(%{book: %Book{} = book}), do: book
  def book(_post), do: nil

  @doc "Returns true if the book's review is a post the exported site shows, titled or not."
  @spec review_linked?(SiteData.t(), Book.t()) :: boolean()
  def review_linked?(data, %Book{post: %Content.Post{} = post}),
    do: SiteData.published?(data, post)

  def review_linked?(_data, _book), do: false

  @doc "The read books grouped by the year they were read, newest first: `[{year, books}]`."
  @spec books_by_year([Book.t()]) :: [{integer(), [Book.t()]}]
  def books_by_year(books) do
    books
    |> Enum.filter(& &1.read_at)
    |> Enum.sort_by(& &1.read_at, {:desc, Date})
    |> Enum.chunk_by(& &1.read_at.year)
    |> Enum.map(fn [first | _] = group -> {first.read_at.year, group} end)
  end

  @doc "Ongoing projects first (latest started first), then the others by their end."
  @spec sort_projects([Project.t()]) :: [Project.t()]
  def sort_projects(projects) do
    {ongoing, other} = Enum.split_with(projects, &(&1.status == "ongoing"))

    Enum.sort_by(ongoing, & &1.started_at, {:desc, Date}) ++
      Enum.sort_by(other, &(&1.ended_at || &1.started_at), {:desc, Date})
  end

  @doc "The links of a project that have a safe URL."
  @spec project_links(Project.t() | nil) :: [Project.Link.t()]
  def project_links(%Project{links: links}) when is_list(links),
    do: Enum.filter(links, &(present?(&1.url) and HTML.safe_url?(&1.url)))

  def project_links(_project), do: []

  @doc "The label of a project status in the current language."
  @spec project_status_label(String.t() | nil) :: String.t()
  def project_status_label("ongoing"), do: pgettext("project status", "Ongoing")
  def project_status_label("completed"), do: pgettext("project status", "Completed")
  def project_status_label("paused"), do: pgettext("project status", "Paused")
  def project_status_label("abandoned"), do: pgettext("project status", "Abandoned")
  def project_status_label(status), do: titleize(status)

  @doc "The label of a project type in the current language."
  @spec project_type_label(String.t() | nil) :: String.t()
  def project_type_label("professional"), do: pgettext("project type", "Professional")
  def project_type_label("personal"), do: pgettext("project type", "Personal")
  def project_type_label("open_source"), do: pgettext("project type", "Open Source")
  def project_type_label("freelance"), do: pgettext("project type", "Freelance")
  def project_type_label(type), do: titleize(type)

  @doc "The period of a project: its own text, or start month to end month (or today)."
  @spec project_period(Project.t()) :: String.t()
  def project_period(%Project{period: period} = project) do
    if present?(period) do
      period
    else
      finish = if project.ended_at, do: format_month(project.ended_at), else: gettext("today")
      gettext("%{start} – %{finish}", start: format_month(project.started_at), finish: finish)
    end
  end

  @doc "Link text with an optional emoji in front, hidden from screen readers."
  @spec emoji_label(String.t() | nil, String.t()) :: Phoenix.HTML.safe()
  def emoji_label(emoji, text) do
    mark =
      if present?(emoji),
        do: [~s(<span class="link-emoji" aria-hidden="true">), escape(emoji), "</span>"],
        else: []

    {:safe, [mark, escape(text)]}
  end

  @label_words 7

  @doc """
  What links and page titles name a post by: its title, the title of the
  book an untitled review is about, or the first words of any other
  untitled post (its date if it has no text).
  """
  @spec post_label(Content.Post.t()) :: String.t()
  def post_label(post) do
    cond do
      present?(post.title) -> post.title
      book(post) -> book(post).title
      true -> untitled_label(post)
    end
  end

  defp untitled_label(post) do
    case post.content |> ContentBlocks.excerpt() |> String.split() do
      [] ->
        format_date(post.publish_at)

      words when length(words) <= @label_words ->
        Enum.join(words, " ")

      words ->
        words
        |> Enum.take(@label_words)
        |> Enum.join(" ")
        |> String.replace(~r/[[:punct:]]+\z/u, "")
        |> Kernel.<>("…")
    end
  end

  @doc "Returns true if the assigns render that page."
  @spec current_page?(map(), Content.Page.t()) :: boolean()
  def current_page?(%{page: %Content.Page{id: id}}, %Content.Page{id: id}), do: true
  def current_page?(_assigns, _page), do: false

  @doc "A value as escaped HTML iodata."
  @spec escape(term()) :: iodata()
  def escape(value), do: value |> to_string() |> Phoenix.HTML.html_escape() |> elem(1)

  @doc ~s(`"open_source"` as `"Open Source"`.)
  @spec titleize(String.t() | nil) :: String.t()
  def titleize(nil), do: ""

  def titleize(text) do
    text
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc "Returns true for a string that is not blank."
  @spec present?(term()) :: boolean()
  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(_value), do: false

  @doc "Returns true for nil and blank strings."
  @spec blank?(term()) :: boolean()
  def blank?(value), do: not present?(value)
end
