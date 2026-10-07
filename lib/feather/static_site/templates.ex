defmodule Feather.StaticSite.Templates do
  @moduledoc """
  The templates of the static site, ported from the Rails ERB views
  (`app/views/static_site/`, `app/components/static_site/`): the layout
  and the home, post, page and project views in `templates/*.html.eex`.

  They are EEx with `Phoenix.HTML.Engine` (output is escaped unless it is
  `{:safe, iodata}`) rather than HEEx: HEEx adds the app's
  `root_tag_attribute` (`phx-r`) to every root tag, which has no place in
  a hand-made looking static site. Every template is a function taking an
  assigns map and returning safe iodata.

  Rendering goes through `Feather.StaticSite.Renderer`, which builds the
  assigns (`data`, `routes`, `ctx`, ...).
  """

  require EEx

  import Phoenix.HTML, only: [raw: 1]

  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.{HTML, Project}
  alias Feather.Media.Image
  alias Feather.Sites.SocialMediaService
  alias Feather.StaticSite.{Blocks, Routes, SiteData}

  @css_path Path.expand("../../../priv/static_site/static_site.css", __DIR__)
  @external_resource @css_path
  @css File.read!(@css_path)

  @templates ~w(layout home post post_book_card page books_list projects_list project_card
                project tags)a

  for name <- @templates do
    EEx.function_from_file(
      :def,
      name,
      Path.join([__DIR__, "templates", "#{name}.html.eex"]),
      [:assigns],
      engine: Phoenix.HTML.Engine,
      trim: true
    )
  end

  @doc "The stylesheet inlined into every page."
  @spec css() :: String.t()
  def css, do: @css

  ## Helpers

  @doc """
  The page numbers of the pagination: all pages up to 7, otherwise the
  first, the last, the current one and its neighbours (the first or last
  four near the ends), with `:gap` where numbers are left out.
  """
  @spec pagination_page_numbers(pos_integer(), pos_integer()) :: [pos_integer() | :gap]
  def pagination_page_numbers(_current, total) when total <= 7, do: Enum.to_list(1..total)

  def pagination_page_numbers(current, total) do
    near_end =
      cond do
        current <= 3 -> Enum.to_list(1..4)
        current >= total - 2 -> Enum.to_list((total - 3)..total)
        true -> []
      end

    ([1, total, current, current - 1, current + 1] ++ near_end)
    |> Enum.filter(&(&1 >= 1 and &1 <= total))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce([], fn
      page, [previous | _] = acc when is_integer(previous) and page > previous + 1 ->
        [page, :gap | acc]

      page, acc ->
        [page | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  A date in the long English format of the Rails export
  (`"October 06, 2026"`); datetimes are taken in UTC.
  """
  @spec format_date(DateTime.t() | Date.t() | nil) :: String.t()
  def format_date(nil), do: ""
  def format_date(%DateTime{} = datetime), do: datetime |> DateTime.to_date() |> format_date()
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%B %d, %Y")

  @doc "A book's read date, `\"14/03/2026\"`."
  @spec format_short_date(Date.t() | nil) :: String.t()
  def format_short_date(nil), do: ""
  def format_short_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  @doc "A rating of 1 to 5 as stars: `\"★★★☆☆\"`."
  @spec rating_stars(integer() | nil) :: String.t() | nil
  def rating_stars(nil), do: nil

  def rating_stars(rating) when is_integer(rating) do
    rating = rating |> max(0) |> min(5)
    String.duplicate("★", rating) <> String.duplicate("☆", 5 - rating)
  end

  @doc """
  The copyright notice with `{{CurrentYear}}` replaced. Inline HTML is
  allowed (sanitized like content; Rails inserted it unsanitized).
  """
  @spec copyright(String.t() | nil, integer()) :: Phoenix.HTML.safe()
  def copyright(text, year \\ Date.utc_today().year) do
    {:safe,
     (text || "")
     |> String.replace("{{CurrentYear}}", Integer.to_string(year))
     |> HTML.sanitize()}
  end

  @doc """
  Text as HTML paragraphs like Rails' `simple_format`: blank lines separate
  paragraphs, single line breaks become `<br />`. Inline HTML is
  sanitized like content.
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

  defp unsplash_credit?(%Image{} = image),
    do: Image.unsplash?(image) and HTML.safe_url?(Image.unsplash_photographer_url(image))

  defp unsplash_credit?(_image), do: false

  defp book(%{book: %Book{} = book}), do: book
  defp book(_post), do: nil

  # Rails linked every review with a title; only published ones exist in
  # the exported site.
  defp review_linked?(data, %Book{post: %Content.Post{} = post}),
    do: present?(post.title) and SiteData.published?(data, post)

  defp review_linked?(_data, _book), do: false

  # Books with a read date, grouped by year, most recent first.
  defp books_by_year(books) do
    books
    |> Enum.filter(& &1.read_at)
    |> Enum.sort_by(& &1.read_at, {:desc, Date})
    |> Enum.chunk_by(& &1.read_at.year)
    |> Enum.map(fn [first | _] = group -> {first.read_at.year, group} end)
  end

  # Ongoing projects first (latest start first), then the others by end
  # (or start) date, latest first.
  defp sort_projects(projects) do
    {ongoing, other} = Enum.split_with(projects, &(&1.status == "ongoing"))

    Enum.sort_by(ongoing, & &1.started_at, {:desc, Date}) ++
      Enum.sort_by(other, &(&1.ended_at || &1.started_at), {:desc, Date})
  end

  defp project_links(%Project{links: links}) when is_list(links),
    do: Enum.filter(links, &(present?(&1.url) and HTML.safe_url?(&1.url)))

  defp project_links(_project), do: []

  defp status_badge_class("completed"), do: "success"
  defp status_badge_class("ongoing"), do: "primary"
  defp status_badge_class("paused"), do: "warning"
  defp status_badge_class(_status), do: "secondary"

  @project_type_labels %{
    "professional" => "Professional",
    "personal" => "Personal",
    "open_source" => "Open Source",
    "freelance" => "Freelance"
  }

  defp project_type_label(type), do: Map.get(@project_type_labels, type) || titleize(type)

  defp titleize(nil), do: ""

  defp titleize(text) do
    text
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp blank?(value), do: not present?(value)
end
