defmodule Feather.StaticSite.Templates do
  @moduledoc """
  The HEEx templates of the static site: the layout and the home, post,
  page and project views, ported from the Rails ERB views
  (`app/views/static_site/`, `app/components/static_site/`).

  Rendering goes through `Feather.StaticSite.Renderer`; these components
  expect the assigns it builds (`data`, `routes`, `ctx`, ...).
  """

  use Phoenix.Component

  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.Project
  alias Feather.Media.Image
  alias Feather.StaticSite.{Blocks, Routes, Sanitizer, SiteData}

  @css_path Path.expand("../../../priv/static_site/static_site.css", __DIR__)
  @external_resource @css_path
  @css File.read!(@css_path)

  @doc "The stylesheet inlined into every page."
  @spec css() :: String.t()
  def css, do: @css

  ## Layout

  @doc """
  The page layout. Assigns: `site`, `routes`, `social_links`,
  `page_title`, `page_emoji`, `is_home`, `header_image`, `rss_url` and the
  rendered view as `inner_content`.
  """
  def layout(assigns) do
    assigns =
      assigns
      |> assign_new(:header_image, fn -> nil end)
      |> assign_new(:rss_url, fn -> nil end)

    ~H"""
    <!DOCTYPE html>
    <html lang={@site.language_code}>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>{@page_title}</title>
        <style>
          <%= Phoenix.HTML.raw(css()) %>
        </style>
        <link rel="icon" href={favicon_href(@page_emoji || @site.emoji)} />
        <link
          :if={@rss_url}
          rel="alternate"
          type="application/rss+xml"
          href={@rss_url}
          title={@site.title}
        />
      </head>
      <body>
        <nav>
          {@site.emoji} <a href={Routes.home_url(@routes)}>{@site.title}</a>
          <%= unless @is_home do %>
            <span class="divider">/</span> {@page_emoji} {@page_title}
          <% end %>
        </nav>
        <main>
          <%= cond do %>
            <% match?(%Image{}, @header_image) -> %>
              <div class="header-image-container">
                <img
                  src={Routes.image_url(@routes, @header_image, :desktop_x1_webp)}
                  srcset={Routes.image_srcset(@routes, @header_image)}
                  sizes="100vw"
                  alt={@page_title}
                  class="header-image"
                />
                <div :if={@page_emoji} class="emoji">{@page_emoji}</div>
              </div>
            <% @page_emoji && !@is_home -> %>
              <div class="emoji">{@page_emoji}</div>
            <% true -> %>
          <% end %>
          <h1>{@page_title}</h1>
          {@inner_content}
          <div :if={unsplash_credit?(@header_image)} class="photo-credit">
            Photo by
            <a
              href={Image.unsplash_photographer_url(@header_image)}
              target="_blank"
              rel="noopener"
            >{Image.unsplash_photographer_name(@header_image)}</a>
            on
            <a
              href="https://unsplash.com"
              target="_blank"
              rel="noopener"
            >Unsplash</a>
          </div>
        </main>
        <footer>
          <hr />
          <p>
            <a
              :for={link <- @social_links}
              :if={Sanitizer.safe_url?(link.url)}
              href={link.url}
              title={link.name}
              class="socialLink"
            >
              {Phoenix.HTML.raw(Feather.Sites.SocialMediaService.svg(link.icon) || "")}
            </a>
          </p>
          <p>{copyright(@site.copyright)}</p>
        </footer>
      </body>
    </html>
    """
  end

  ## Home

  @doc """
  The post list. Assigns: `data`, `routes`, `ctx`, `posts`,
  `current_page`, `total_pages`.
  """
  def home(assigns) do
    ~H"""
    <ul class="page-list">
      <li :for={item <- @data.navigation}>
        {item.page.emoji}
        <a class="page-link" href={Routes.page_url(@routes, item.page)}>{item.page.title}</a>
      </li>
    </ul>

    {Blocks.render(@data.homepage && @data.homepage.content, @ctx)}

    <hr />

    <h2>Blogposts</h2>

    <div class="page-list">
      <%= for post <- @posts do %>
        <article>
          <%= if blank?(post.title) do %>
            <.post_book_card :if={book(post)} book={book(post)} routes={@routes} />
            <div class="post-shortBody">
              <div :if={present?(post.emoji) && is_nil(book(post))} class="post-emoji">
                {post.emoji}
              </div>
              <div class="post-content">{Blocks.render(post.content, @ctx)}</div>
            </div>
            <div class="post-date">{format_date(post.publish_at)}</div>
          <% else %>
            <div>
              <a class="post-title" href={Routes.post_url(@routes, post)}>{post.title}</a>
              <span
                :if={book(post) && book(post).rating}
                class="rating"
                aria-label={"#{book(post).rating} out of 5 stars"}
              >
                {rating_stars(book(post).rating)}
              </span>
            </div>
            <div class="post-long-body">
              <div :if={present?(post.emoji)} class="post-emoji">{post.emoji}</div>
              <div class="post-long-content">
                <div :if={match?(%Image{}, post.thumbnail_image)} class="post-thumbnail">
                  <img
                    src={Routes.image_url(@routes, post.thumbnail_image, :mobile_x1_webp)}
                    alt=""
                    loading="lazy"
                  />
                </div>
                <div :if={post.content not in [nil, []]} class="post-excerpt">
                  {Content.content_excerpt(post)}
                </div>
              </div>
            </div>
            <div class="post-date">{format_date(post.publish_at)}</div>
            <.tags class="post-tags" tags={Content.tag_list(post)} />
          <% end %>
        </article>
        <hr />
      <% end %>
    </div>

    <nav :if={@total_pages > 1} class="pagination" aria-label="Pagination">
      <a
        :if={@current_page > 1}
        href={Routes.home_url(@routes, @current_page - 1)}
        class="pagination-link"
      >&larr;</a>
      <%= for page <- pagination_page_numbers(@current_page, @total_pages) do %>
        <%= cond do %>
          <% page == :gap -> %>
            <span class="pagination-gap">&hellip;</span>
          <% page == @current_page -> %>
            <span class="pagination-current">{page}</span>
          <% true -> %>
            <a href={Routes.home_url(@routes, page)} class="pagination-link">{page}</a>
        <% end %>
      <% end %>
      <a
        :if={@current_page < @total_pages}
        href={Routes.home_url(@routes, @current_page + 1)}
        class="pagination-link"
      >&rarr;</a>
    </nav>
    """
  end

  ## Post

  @doc "A post. Assigns: `routes`, `ctx`, `post`."
  def post(assigns) do
    ~H"""
    <.post_book_card :if={book(@post)} book={book(@post)} routes={@routes} />

    {Blocks.render(@post.content, @ctx)}

    <div class="post-date">{format_date(@post.publish_at)}</div>

    <.tags class="post-tags" tags={Content.tag_list(@post)} />
    """
  end

  attr :book, Book, required: true
  attr :routes, Routes, required: true

  defp post_book_card(assigns) do
    ~H"""
    <div class="book-card book-card--detail">
      <div class="book-card-header">
        <%= cond do %>
          <% match?(%Image{}, @book.cover_image) -> %>
            <img
              src={Routes.image_url(@routes, @book.cover_image, :mobile_x1_webp)}
              alt={@book.title}
              class="book-cover"
              loading="lazy"
            />
          <% present?(@book.emoji) -> %>
            <span class="book-emoji">{@book.emoji}</span>
          <% true -> %>
        <% end %>
        <div class="book-info">
          <div class="book-title">{@book.title}</div>
          <div class="book-author">{@book.author}</div>
          <div :if={@book.rating} class="book-rating" aria-label={"#{@book.rating} out of 5 stars"}>
            {rating_stars(@book.rating)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  ## Page

  @doc "A page. Assigns: `data`, `routes`, `ctx`, `page`."
  def page(assigns) do
    ~H"""
    {Blocks.render(@page.content, @ctx)}

    <.tags class="page-tags" tags={Content.tag_list(@page)} />

    <.books_list :if={@page.page_type == "books"} data={@data} routes={@routes} />

    <.projects_list :if={@page.page_type == "projects"} projects={@data.projects} routes={@routes} />
    """
  end

  defp books_list(assigns) do
    assigns = assign(assigns, :groups, books_by_year(assigns.data.books))

    ~H"""
    <%= for {year, books} <- @groups do %>
      <h2>{year} ({length(books)})</h2>
      <div class="books-grid">
        <div :for={book <- books} class="book-card">
          <img
            :if={match?(%Image{}, book.cover_image)}
            src={Routes.image_url(@routes, book.cover_image, :mobile_x1_webp)}
            alt={book.title}
            class="book-cover"
          />
          <div class="book-info">
            <span :if={present?(book.emoji)} class="book-emoji">{book.emoji}</span>
            <%= if review_linked?(@data, book) do %>
              <a href={Routes.post_url(@routes, book.post)} class="book-title">{book.title}</a>
            <% else %>
              <span class="book-title">{book.title}</span>
            <% end %>
            <span class="book-author">{book.author}</span>
            <span :if={book.rating} class="book-rating">{rating_stars(book.rating)}</span>
            <span :if={book.read_at} class="book-date">{format_short_date(book.read_at)}</span>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp projects_list(assigns) do
    assigns = assign(assigns, :projects, sort_projects(assigns.projects))

    ~H"""
    <div class="projects-list">
      <%= for {project, index} <- Enum.with_index(@projects) do %>
        <.project_card project={project} routes={@routes} />
        <hr :if={index != length(@projects) - 1} />
      <% end %>
    </div>
    """
  end

  defp project_card(assigns) do
    ~H"""
    <div class="project-item">
      <div class="project-header">
        <%= cond do %>
          <% match?(%Image{}, @project.thumbnail_image) -> %>
            <img
              src={Routes.image_url(@routes, @project.thumbnail_image, :mobile_x1_webp)}
              alt=""
              class="project-thumbnail"
            />
          <% present?(@project.emoji) -> %>
            <span class="project-emoji">{@project.emoji}</span>
          <% true -> %>
        <% end %>
        <a href={Routes.project_url(@routes, @project)} class="project-title">{@project.title}</a>
      </div>
      <div class="project-meta">
        <span :if={present?(@project.company)} class="project-company">{@project.company}</span>
        <span class="project-period">{Project.display_period(@project)}</span>
        <span :if={present?(@project.role)} class="project-role">{@project.role}</span>
      </div>
      <div class="project-badges">
        <span class={"badge badge-#{status_badge_class(@project.status)}"}>
          {titleize(@project.status)}
        </span>
        <span class="badge badge-outline">{project_type_label(@project.project_type)}</span>
        <span :for={tag <- Content.tag_list(@project)} class="badge badge-outline">{tag}</span>
      </div>
      <p :if={present?(@project.short_description)} class="project-description">
        {@project.short_description}
      </p>
    </div>
    """
  end

  ## Project

  @doc "A project. Assigns: `routes`, `ctx`, `project`."
  def project(assigns) do
    ~H"""
    <div class="project-detail">
      <div class="project-metadata">
        <div class="project-meta-row">
          <span class={"badge badge-#{status_badge_class(@project.status)}"}>
            {titleize(@project.status)}
          </span>
          <span :if={present?(@project.company)} class="project-company">{@project.company}</span>
          <span class="project-period">{Project.display_period(@project)}</span>
          <span :for={tag <- Content.tag_list(@project)} class="badge badge-outline">{tag}</span>
        </div>
        <div :if={present?(@project.role)} class="project-role">{@project.role}</div>
      </div>

      <div :if={present?(@project.short_description)} class="project-summary">
        {simple_format(@project.short_description)}
      </div>
    </div>

    {Blocks.render(@project.content, @ctx)}

    <div :if={project_links(@project) != []} class="project-links">
      <h3>Links</h3>
      <div class="links-list">
        <a
          :for={link <- project_links(@project)}
          href={link.url}
          target="_blank"
          rel="noopener noreferrer"
          class="project-link"
        >
          🔗 {if present?(link.label), do: link.label, else: link.url}
        </a>
      </div>
    </div>
    """
  end

  ## Shared components

  attr :tags, :list, required: true
  attr :class, :string, required: true

  defp tags(assigns) do
    ~H"""
    <div :if={@tags != []} class={@class}>
      <span :for={tag <- @tags} class="badge badge-outline">{tag}</span>
    </div>
    """
  end

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
  allowed (sanitized like content).
  """
  @spec copyright(String.t() | nil, integer()) :: Phoenix.HTML.safe()
  def copyright(text, year \\ Date.utc_today().year) do
    {:safe,
     (text || "")
     |> String.replace("{{CurrentYear}}", Integer.to_string(year))
     |> Sanitizer.sanitize()}
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
          |> Sanitizer.sanitize()
          |> String.replace(~r/([^\n]\n)(?=[^\n])/, "\\1<br />")

        ["<p>", html, "</p>"]
      end)

    {:safe, Enum.intersperse(paragraphs, "\n\n")}
  end

  defp favicon_href(emoji) do
    "data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22>" <>
      "<text y=%22.9em%22 font-size=%2290%22>#{emoji}</text></svg>"
  end

  defp unsplash_credit?(%Image{} = image),
    do: Image.unsplash?(image) and Sanitizer.safe_url?(Image.unsplash_photographer_url(image))

  defp unsplash_credit?(_image), do: false

  defp book(%{book: %Book{} = book}), do: book
  defp book(_post), do: nil

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
    do: Enum.filter(links, &(present?(&1.url) and Sanitizer.safe_url?(&1.url)))

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
