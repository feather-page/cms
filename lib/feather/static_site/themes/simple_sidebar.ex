defmodule Feather.StaticSite.Themes.SimpleSidebar do
  @moduledoc """
  The `simple_sidebar` theme, first made for rocu.de: a panel on the left says
  who the site belongs to (title, portrait, the first paragraph of the
  homepage) and lists the navigation; the reading column beside it starts
  with the posts. Portrait and intro appear on the home pages only, every
  other page gets the slim panel. Text in Schibsted Grotesk, code in
  JetBrains Mono. Below 52rem the panel becomes a compact header; on inner
  pages a one-line bar whose navigation folds into a menu. Templates in
  `simple_sidebar/*.html.eex`, stylesheet and fonts in
  `priv/static_site/themes/simple_sidebar/`.
  """

  use Feather.StaticSite.Theme

  alias Feather.Content
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Media.Image
  alias Feather.StaticSite.{Blocks, Routes, SiteData}
  alias Phoenix.HTML.Safe

  @priv_dir Path.expand("../../../../priv/static_site/themes/simple_sidebar", __DIR__)
  @css_path Path.join(@priv_dir, "theme.css")
  @external_resource @css_path
  @css File.read!(@css_path)

  @font_file "schibsted-grotesk-latin-wght.woff2"
  @fonts %{@font_file => "font/woff2", "OFL.txt" => "text/plain"}

  @views ~w(layout home post page project not_found)a
  @partials ~w(meta entry header_image books_list projects_list tags site_nav)a

  for name <- @views ++ @partials do
    if name in @views, do: @impl(true)

    EEx.function_from_file(
      :def,
      name,
      Path.join([__DIR__, "simple_sidebar", "#{name}.html.eex"]),
      [:assigns],
      engine: Phoenix.HTML.Engine,
      trim: true
    )
  end

  @impl true
  def css, do: @css

  @impl true
  def font_faces(%Routes{} = routes) do
    {:safe,
     [
       font_face(routes, "Schibsted Grotesk", "400 700", [], @font_file),
       jetbrains_mono_faces(routes)
     ]}
  end

  # Schibsted Grotesk, variable weight axis, Latin subset, SIL Open Font License.
  @impl true
  def fonts, do: Map.merge(@fonts, jetbrains_mono_fonts())

  @impl true
  def font_path(name),
    do: Application.app_dir(:feather, "priv/static_site/themes/simple_sidebar/fonts/#{name}")

  # The text column beside the panel; panel, gap and --inset clamp in vw, so it is solved per range.
  @impl true
  def content_image_sizes,
    do:
      "(min-width: 58rem) 36rem, (min-width: 55.56rem) 62.1vw, " <>
        "(min-width: 52rem) calc(89.1vw - 15rem), calc(100vw - 2rem)"

  @impl true
  def site_image_fields, do: [:portrait_image_id]

  defp font_url(routes), do: Routes.font_url(routes, @font_file)

  defp show_domain?(site) do
    present?(site.domain) and
      String.downcase(String.trim(site.domain)) != String.downcase(String.trim(site.title || ""))
  end

  defp intro(%SiteData{homepage: %{content: content}}) do
    content
    |> ContentBlocks.normalize()
    |> Enum.find_value("", &paragraph_text/1)
    |> first_sentence()
  end

  defp intro(_data), do: nil

  defp paragraph_text(%{"type" => "paragraph", "text" => text}) when is_binary(text) do
    case text |> ContentBlocks.strip_tags() |> String.trim() do
      "" -> nil
      text -> text
    end
  end

  defp paragraph_text(_block), do: nil

  defp first_sentence(""), do: nil

  defp first_sentence(text) do
    sentence_end =
      ~r/(?<=[.!?…])\s+(?=\p{Lu})/u
      |> Regex.scan(text, return: :index)
      |> Enum.find(fn [{at, _length}] -> not abbreviation?(binary_part(text, 0, at)) end)

    case sentence_end do
      [{at, length}] ->
        {binary_part(text, 0, at), binary_part(text, at + length, byte_size(text) - at - length)}

      nil ->
        {text, nil}
    end
  end

  # Heuristic: a word of one or two letters before the period ("z. B.", "Dr.", "e.g.") is an abbreviation.
  defp abbreviation?(lead), do: Regex.match?(~r/(?<!\p{L})\p{L}{1,2}\.\z/u, lead)

  defp portrait(routes, %Image{} = image) do
    {:safe,
     [
       ~s(<img class="portrait" src="),
       escape(Routes.image_url(routes, image, :mobile_x1_webp)),
       ~s(" srcset="),
       escape(Routes.image_srcset(routes, image)),
       ~s{" sizes="(max-width: 52rem) 60px, 108px" width="96" height="96" alt="">}
     ]}
  end

  defp nav_link(assigns, page, url) do
    current =
      cond do
        current_page?(assigns, page) -> "page"
        Enum.any?(assigns.trail, &(&1.url == url)) -> "true"
        true -> nil
      end

    open =
      if current,
        do: [
          ~s(" aria-current="),
          current,
          ~s("><span class="nav-mark" aria-hidden="true"></span>)
        ],
        else: ~s(">)

    {:safe, [~s(<a href="), escape(url), open, escape(page.title), "</a>"]}
  end

  defp short_date(date), do: date |> format_short_date() |> punctuated()

  # Under a year heading the year is dropped; a format that does not end in it stays whole.
  defp day_and_month(date) do
    date
    |> format_short_date()
    |> String.replace(~r/[\s,]*#{date.year}\z/, "")
    |> punctuated()
  end

  # Tabular figures widen punctuation too, so the separators keep proportional widths.
  defp punctuated(text) do
    {:safe,
     text
     |> escape()
     |> IO.iodata_to_binary()
     |> String.replace(~r/[,.]/, ~s(<span class="punct">\\0</span>))}
  end

  defp social_links(links) do
    links
    |> Enum.map(&{:safe, [~s(<a href="), escape(&1.url), ~s(">), escape(&1.name), "</a>"]})
    |> separated()
  end

  @new_for_days 30

  defp recent?(%SiteData{now: now}, post),
    do: Date.diff(DateTime.to_date(now), DateTime.to_date(post.publish_at)) <= @new_for_days

  defp kind(post) do
    cond do
      book(post) -> :book
      present?(post.title) -> :article
      true -> :note
    end
  end

  defp kind_label(:article), do: pgettext("post kind", "Article")
  defp kind_label(:note), do: pgettext("post kind", "Note")
  defp kind_label(:book), do: pgettext("post kind", "Book")

  defp heading(post), do: if(kind(post) != :note, do: post_label(post))

  defp byline(post) do
    book = book(post)

    title =
      if heading(post) != book.title,
        do: {:safe, [~s(<cite class="book-title">), escape(book.title), "</cite>"]}

    rating = if book.rating, do: stars(book.rating)

    author =
      if present?(book.author),
        do: {:safe, [~s(<span class="author">), escape(book.author), "</span>"]}

    case separated([title, author, rating]) do
      {:safe, []} -> nil
      {:safe, items} -> {:safe, [~s(<p class="byline">), items, "</p>"]}
    end
  end

  defp stars(rating) do
    rating = rating |> max(0) |> min(5)

    {:safe,
     [
       ~s(<span class="stars" role="img" aria-label="),
       rating_label(rating),
       ~s("><span aria-hidden="true">),
       String.duplicate("★", rating),
       ~s(<span class="star-off">),
       String.duplicate("★", 5 - rating),
       "</span></span></span>"
     ]}
  end

  defp split_projects(projects),
    do: projects |> sort_projects() |> Enum.split_with(&(&1.project_type != "professional"))

  defp list_picture(%{thumbnail_image: %Image{} = image}), do: image
  defp list_picture(%{header_image: %Image{} = image}), do: image
  defp list_picture(_project), do: nil

  defp page_picture(%{header_image: %Image{} = image}), do: image
  defp page_picture(%{thumbnail_image: %Image{} = image}), do: image
  defp page_picture(_project), do: nil

  defp project_stack(project), do: project |> Content.tag_list() |> Enum.join(", ")

  defp first_link(project) do
    case project_links(project) do
      [link | _] -> link_tag(link, link_label(link))
      [] -> nil
    end
  end

  defp link_label(link),
    do: if(present?(link.label), do: link.label, else: pgettext("project link", "Source"))

  defp link_tag(link, text),
    do: {:safe, [~s(<a href="), escape(link.url), ~s(" rel="noopener">), escape(text), "</a>"]}

  defp short_url(url),
    do:
      url |> String.replace(~r{\A[a-z][a-z0-9+.-]*://(www\.)?}i, "") |> String.trim_trailing("/")

  @sep ~s(<span class="sep" aria-hidden="true">·</span>)

  defp sep, do: {:safe, @sep}

  defp separated(items) do
    {:safe,
     items
     |> Enum.filter(&(match?({:safe, _}, &1) or present?(&1)))
     |> Enum.map(&Safe.to_iodata/1)
     |> Enum.intersperse(@sep)}
  end

  defp meta_line(items) do
    case separated(items) do
      {:safe, []} ->
        nil

      {:safe, label} ->
        {:safe,
         [
           ~s(<p class="meta"><span class="meta-label">),
           label,
           ~s(</span><span class="rule" aria-hidden="true"></span></p>)
         ]}
    end
  end

  defp project_facts(project) do
    facts =
      Enum.filter(
        [
          {pgettext("project", "Stack"), project_stack(project)},
          {pgettext("project", "Status"), project_status_label(project.status)},
          {pgettext("project", "Role"), project.role},
          {pgettext("project", "Company"), project.company},
          {pgettext("project", "Period"), project_period(project)}
        ],
        fn {_label, value} -> present?(value) end
      )

    facts ++
      Enum.map(project_links(project), &{link_label(&1), link_tag(&1, short_url(&1.url))})
  end
end
