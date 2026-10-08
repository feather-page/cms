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
    {"Want to read", "want_to_read"},
    {"Currently reading", "reading"},
    {"Finished reading", "finished"}
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
      <.header back={~p"/sites/#{@site.public_id}/books"} back_label="Books" truncate>
        {@page_title}
        <:badge :if={@live_action == :edit}>
          <.status_badge id="status-badge">
            {reading_status_label(@book.reading_status)}
          </.status_badge>
        </:badge>
        <:actions :if={@live_action == :edit}>
          <.link
            :if={!Book.review?(@book)}
            navigate={~p"/sites/#{@site.public_id}/books/#{@book.public_id}/review/new"}
            id="write-review"
            class="btn btn-light"
          >
            <.icon name="star" size={16} /> Write review
          </.link>
          <.link
            :if={Book.review?(@book)}
            navigate={~p"/sites/#{@site.public_id}/books/#{@book.public_id}/review/edit"}
            id="edit-review"
            class="btn btn-light"
          >
            <.icon name="star" size={16} class="text-warning" /> Edit review
          </.link>
        </:actions>
      </.header>

      <div class="form-narrow">
        <form id="book-search-form" phx-change="search" phx-submit="search" class="mb-4">
          <label for="book-search" class="form-label">Search OpenLibrary</label>
          <input
            type="search"
            id="book-search"
            name="query"
            value={@query}
            class="form-control"
            placeholder="Title or author"
            autocomplete="off"
            phx-debounce="300"
          />
          <div class="form-text">Fills in title, author and cover.</div>
          <p :if={@search_error} id="book-search-error" class="text-danger small mt-1">
            {@search_error}
          </p>
          <div :if={@results != []} id="book-search-results" class="list-group mt-2">
            <button
              :for={{result, index} <- Enum.with_index(@results)}
              type="button"
              id={"book-search-result-#{index}"}
              class="list-group-item list-group-item-action d-flex align-items-center gap-3"
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
          <div class="row g-3">
            <div class="col-12">
              <.input field={@form[:title]} label="Title" wrapper_class={nil} phx-debounce="300">
                <:prefix>
                  <input
                    type="text"
                    id={@form[:emoji].id}
                    name={@form[:emoji].name}
                    value={@form[:emoji].value}
                    class="form-control emoji-input"
                    aria-label="Emoji"
                    placeholder="📖"
                    autocomplete="off"
                  />
                </:prefix>
              </.input>
            </div>
            <div class="col-12 col-sm-8">
              <.input
                field={@form[:author]}
                label="Author"
                wrapper_class={nil}
                phx-debounce="300"
              />
            </div>
            <div class="col-12 col-sm-4">
              <.input field={@form[:read_at]} type="date" label="Read at" wrapper_class={nil} />
            </div>
            <div class="col-12 col-sm-8">
              <.input
                field={@form[:reading_status]}
                type="select"
                label="Reading status"
                options={@reading_statuses}
                wrapper_class={nil}
              />
            </div>
            <div class="col-12">
              <span class="form-label">Cover</span>
              <div class="d-flex align-items-center gap-3">
                <div id="book-cover-preview" class="book-cover-preview">
                  <img :if={@cover_url} src={@cover_url} alt="Cover" />
                  <img
                    :if={!@cover_url && @book.cover_image}
                    src={image_path(@site, @book.cover_image, "mobile_x1.webp")}
                    alt="Cover"
                  />
                  <span :if={!@cover_url && !@book.cover_image} aria-hidden="true">
                    {@form[:emoji].value || "📖"}
                  </span>
                </div>
                <p class="form-text m-0">
                  {if @cover_url || @book.cover_image,
                    do: "From OpenLibrary. Search again to pick another one.",
                    else: "Search OpenLibrary above to add a cover."}
                </p>
              </div>
            </div>
          </div>
          <.input field={@form[:isbn]} type="hidden" />
          <.input field={@form[:open_library_key]} type="hidden" />

          <.action_bar>
            <button
              type="submit"
              id="save-book"
              class="btn btn-primary"
              phx-disable-with="Saving..."
            >
              {if @live_action == :new, do: "Add book", else: "Save"}
            </button>
            <.link navigate={~p"/sites/#{@site.public_id}/books"} class="btn btn-light">
              Cancel
            </.link>
            <:danger :if={@live_action == :edit}>
              <button
                type="button"
                id="delete-book"
                class="btn btn-outline-danger"
                phx-click="delete"
                data-confirm="Delete this book?"
              >
                <.icon name="trash-2" size={16} /> Delete
              </button>
            </:danger>
          </.action_bar>
        </.form>
      </div>
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
       if(socket.assigns.live_action == :new, do: "New book", else: book.title)
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

  defp reading_status_label(status) do
    Enum.find_value(@reading_statuses, status, fn {label, value} -> value == status && label end)
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
