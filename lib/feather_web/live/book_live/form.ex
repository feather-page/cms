defmodule FeatherWeb.BookLive.Form do
  @moduledoc """
  Creates and edits books. An OpenLibrary search (server-side, debounced)
  fills title, author, ISBN and OpenLibrary key; the cover of the chosen
  result is downloaded on save (`Feather.Books.attach_cover_from_url/3`).
  The edit page links to the book's review and deletes the book.
  """
  use FeatherWeb, :live_view

  alias Feather.{Books, OpenLibrary}
  alias Feather.Books.Book

  @reading_statuses [
    {"Want to Read", "want_to_read"},
    {"Currently Reading", "reading"},
    {"Finished Reading", "finished"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:books}
    >
      <.header>
        {@page_title}
        <:subtitle>
          <.link navigate={~p"/sites/#{@site.public_id}/books"}>Books</.link> / {@page_title}
        </:subtitle>
        <:actions :if={@live_action == :edit}>
          <.button
            :if={!Book.review?(@book)}
            navigate={~p"/sites/#{@site.public_id}/books/#{@book.public_id}/review/new"}
            id="write-review"
          >
            <.icon name="star" size={16} /> Write Review
          </.button>
          <.button
            :if={Book.review?(@book)}
            navigate={~p"/sites/#{@site.public_id}/books/#{@book.public_id}/review/edit"}
            id="edit-review"
          >
            <.icon name="star" size={16} /> Edit Review
          </.button>
        </:actions>
      </.header>

      <form id="book-search-form" phx-change="search" phx-submit="search" class="mb-3">
        <label for="book-search" class="form-label">Search OpenLibrary</label>
        <input
          type="search"
          id="book-search"
          name="query"
          value={@query}
          class="form-control"
          placeholder="Search by title or author..."
          autocomplete="off"
          phx-debounce="300"
        />
        <p :if={@search_error} id="book-search-error" class="text-danger small mt-1">
          {@search_error}
        </p>
        <div :if={@results != []} id="book-search-results" class="list-group mt-1">
          <button
            :for={{result, index} <- Enum.with_index(@results)}
            type="button"
            id={"book-search-result-#{index}"}
            class="list-group-item list-group-item-action d-flex align-items-center gap-2"
            phx-click="select_result"
            phx-value-index={index}
          >
            <img :if={result.cover_url} src={result.cover_url} width="40" alt="" />
            <span>
              <strong>{result.title}</strong>
              <br /><small class="text-body-secondary">by {result.author || "Unknown"}</small>
            </span>
          </button>
        </div>
      </form>

      <.form for={@form} id="book-form" phx-change="validate" phx-submit="save">
        <.input
          field={@form[:reading_status]}
          type="select"
          label="Reading status"
          options={@reading_statuses}
        />
        <div class="row">
          <div class="col-2">
            <.input field={@form[:emoji]} label="Emoji" />
          </div>
          <div class="col">
            <.input field={@form[:title]} label="Title" phx-debounce="300" />
          </div>
        </div>
        <div class="row">
          <div class="col-3">
            <.input field={@form[:read_at]} type="date" label="Read at" />
          </div>
          <div class="col">
            <.input field={@form[:author]} label="Author" phx-debounce="300" />
          </div>
        </div>
        <.input field={@form[:isbn]} type="hidden" />
        <.input field={@form[:open_library_key]} type="hidden" />

        <div id="book-cover-preview" class="mb-3">
          <img :if={@cover_url} src={@cover_url} class="book-cover-preview" alt="Cover" />
          <img
            :if={!@cover_url && @book.cover_image}
            src={image_path(@site, @book.cover_image, "mobile_x1.webp")}
            class="book-cover-preview"
            alt="Cover"
          />
        </div>

        <div class="d-flex gap-2 align-items-center">
          <.button variant="primary" phx-disable-with="Saving..." id="save-book">
            {if @live_action == :new, do: "Save Book", else: "Update Book"}
          </.button>
          <.button navigate={~p"/sites/#{@site.public_id}/books"}>Cancel</.button>
          <button
            :if={@live_action == :edit}
            type="button"
            id="delete-book"
            class="btn btn-danger btn-sm ms-auto"
            title="Delete"
            phx-click="delete"
            data-confirm="Are you sure?"
          >
            <.icon name="trash" size={16} /> Delete
          </button>
        </div>
      </.form>
    </.site_shell>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    book =
      case socket.assigns.live_action do
        :new -> %Book{site_id: scope.site.id, cover_image: nil}
        :edit -> scope |> Books.get_book!(params["id"]) |> Books.preload_cover_image()
      end

    {:ok,
     socket
     |> assign(:site, scope.site)
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new, do: "New Book", else: "Edit Book")
     )
     |> assign(:reading_statuses, @reading_statuses)
     |> assign(:book, book)
     |> assign(query: "", results: [], search_error: nil, cover_url: nil)
     |> assign_form(%{})}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    case OpenLibrary.search(query) do
      {:ok, results} ->
        {:noreply, assign(socket, query: query, results: results, search_error: nil)}

      {:error, message} ->
        {:noreply, assign(socket, query: query, results: [], search_error: message)}
    end
  end

  def handle_event("select_result", %{"index" => index}, socket) do
    case Enum.at(socket.assigns.results, String.to_integer(index)) do
      nil ->
        {:noreply, socket}

      result ->
        params =
          Map.merge(socket.assigns.params, %{
            "title" => result.title || "",
            "author" => result.author || "",
            "isbn" => result.isbn || "",
            "open_library_key" => result.key || ""
          })

        {:noreply,
         socket
         |> assign(query: "", results: [], cover_url: result.cover_url)
         |> assign_form(params, socket.assigns.form.source.action)}
    end
  end

  def handle_event("validate", %{"book" => book_params}, socket) do
    {:noreply, assign_form(socket, book_params, :validate)}
  end

  def handle_event("save", %{"book" => book_params}, socket) do
    %{current_scope: scope, book: book, live_action: action} = socket.assigns

    result =
      case action do
        :new -> Books.create_book(scope, book_params)
        :edit -> Books.update_book(scope, book, book_params)
      end

    case result do
      {:ok, saved} ->
        message =
          if action == :new,
            do: "The book was successfully added.",
            else: "The book was successfully updated."

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> maybe_attach_cover(saved)
         |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/books")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         assign_form(socket, book_params, if(action == :new, do: :insert, else: :update))}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _book} = Books.delete_book(socket.assigns.current_scope, socket.assigns.book)

    {:noreply,
     socket
     |> put_flash(:info, "The book was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/books")}
  end

  defp maybe_attach_cover(%{assigns: %{cover_url: nil}} = socket, _book), do: socket

  defp maybe_attach_cover(socket, book) do
    case Books.attach_cover_from_url(socket.assigns.current_scope, book, socket.assigns.cover_url) do
      {:ok, _book} -> socket
      {:error, _reason} -> put_flash(socket, :error, "The cover could not be downloaded.")
    end
  end

  defp assign_form(socket, params, action \\ nil) do
    changeset =
      socket.assigns.current_scope
      |> Books.change_book(socket.assigns.book, params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end
