defmodule FeatherWeb.BookLive.Index do
  @moduledoc """
  The bookshelf of a site (port of the Rails `BookshelfComponent`):
  currently reading, want to read, and finished books grouped by the year
  they were read (newest year first and open, older years collapsed).
  """
  use FeatherWeb, :live_view

  alias Feather.Books

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      active={:books}
    >
      <.header>
        Books
        <:actions :if={@books != []}>
          <.button
            variant={:primary}
            icon="plus"
            navigate={~p"/sites/#{@site.public_id}/books/new"}
            id="new-book"
          >
            New book
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@books == []}
        id="no-books"
        layout={:page}
        plush_size={:xxl}
        plush="book-open"
        title="Your bookshelf is empty"
      >
        Add the books you are reading or have read.
        <:action>
          <.button navigate={~p"/sites/#{@site.public_id}/books/new"} variant={:primary} icon="plus">
            Add your first book
          </.button>
        </:action>
      </.empty_state>

      <section
        :for={
          {id, label, books} <- [
            {"books-reading", "Currently reading", @reading},
            {"books-want-to-read", "Want to read", @want_to_read}
          ]
        }
        :if={books != []}
        id={id}
        class="bookshelf__section"
      >
        <h2 class="bookshelf__heading gap-2">
          {label} <span class="bookshelf__count">{count(books)}</span>
        </h2>
        <div class="bookshelf__grid">
          <.book_cover :for={book <- books} book={book} site={@site} />
        </div>
      </section>

      <details
        :for={{{year, books}, index} <- Enum.with_index(@finished_by_year)}
        id={"books-finished-#{year || "unknown"}"}
        class="bookshelf__section group"
        open={index == 0}
        phx-mounted={JS.ignore_attributes(["open"])}
      >
        <summary class="bookshelf__heading cursor-pointer list-none gap-1 sm:-ms-5 [&::-webkit-details-marker]:hidden">
          <.icon
            name="chevron-down"
            class="size-4 shrink-0 -rotate-90 transition-transform group-open:rotate-0"
          />
          <span class="flex items-center gap-2">
            {year || "Unknown"} <span class="bookshelf__count">{count(books)}</span>
          </span>
        </summary>
        <div class="bookshelf__grid">
          <.book_cover :for={book <- books} book={book} site={@site} />
        </div>
      </details>
    </.site_shell>
    """
  end

  attr :book, :map, required: true
  attr :site, :map, required: true

  defp book_cover(assigns) do
    ~H"""
    <.link
      navigate={~p"/sites/#{@site.public_id}/books/#{@book.public_id}/edit"}
      id={"book-#{@book.public_id}"}
      class="book-cover"
      title={"#{@book.title} – #{@book.author}"}
    >
      <div class="book-cover__image">
        <img
          :if={@book.cover_image}
          src={image_path(@site, @book.cover_image, "mobile_x1.webp")}
          class="book-cover__img"
          alt=""
        />
        <span :if={!@book.cover_image && @book.emoji not in [nil, ""]} class="book-cover__emoji">
          {@book.emoji}
        </span>
        <.icon
          :if={!@book.cover_image && @book.emoji in [nil, ""]}
          name="book-open"
          class="size-8 text-base-content/70"
        />
      </div>
      <div class="book-cover__title">{@book.title}</div>
      <div class="book-cover__author">{@book.author}</div>
      <.rating
        :if={@book.reading_status == "finished"}
        value={@book.rating}
        class="book-cover__rating block text-warning-content dark:text-warning"
      />
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    books = Books.list_books(socket.assigns.current_scope, preload: [:cover_image])
    by_status = Enum.group_by(books, & &1.reading_status)
    newest_first = &Enum.sort_by(&1, fn book -> book.inserted_at end, {:desc, DateTime})

    finished_by_year =
      by_status
      |> Map.get("finished", [])
      |> Enum.group_by(&(&1.read_at && &1.read_at.year))
      |> Enum.sort_by(fn {year, _books} -> -(year || 0) end)

    {:ok,
     socket
     |> assign(:site, socket.assigns.current_scope.site)
     |> assign(:page_title, "Books")
     |> assign(:books, books)
     |> assign(:reading, newest_first.(Map.get(by_status, "reading", [])))
     |> assign(:want_to_read, newest_first.(Map.get(by_status, "want_to_read", [])))
     |> assign(:finished_by_year, finished_by_year)}
  end

  defp count([_book]), do: "1 book"
  defp count(books), do: "#{length(books)} books"
end
