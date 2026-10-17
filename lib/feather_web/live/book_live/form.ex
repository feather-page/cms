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
    assigns = assign(assigns, :review, review_link(assigns.site, assigns.book))

    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      active={:books}
    >
      <:bar>
        <.breadcrumbs label="Breadcrumb">
          <:crumb navigate={~p"/sites/#{@site.public_id}/books"}>Books</:crumb>
          <:crumb>{@page_title}</:crumb>
        </.breadcrumbs>
        <.badge :if={@live_action == :edit} id="status-badge">
          {reading_status_label(@book.reading_status)}
        </.badge>
      </:bar>
      <:bar_actions :if={@live_action == :edit}>
        <div class="flex items-center gap-1">
          <.button
            navigate={@review.path}
            id={@review.id}
            size={:sm}
            icon="star"
            class="max-sm:hidden"
          >
            {@review.label}
          </.button>
          <.dropdown
            id="book-menu"
            label="More actions"
            align={:end}
            variant={:ghost}
            chevron={false}
            trigger_class="btn-sm btn-square"
          >
            <:trigger><.icon name="ellipsis-vertical" /></:trigger>
            <:item navigate={@review.path} icon="star" class="sm:hidden">
              {@review.label}
            </:item>
            <:item
              id="delete-book"
              icon="trash-2"
              on_click="delete"
              confirm={"Delete the book “#{@book.title}”?"}
              confirm_text={
                if Book.review?(@book),
                  do:
                    "Removes the book and its review from Feather. They stay on the live site until the next deploy.",
                  else:
                    "Removes the book from Feather. It stays on the live site until the next deploy."
              }
              danger
            >
              Delete
            </:item>
          </.dropdown>
        </div>
      </:bar_actions>

      <div class="max-w-3xl">
        <form
          id="book-search-form"
          phx-change="search"
          phx-submit="search"
          class={@live_action == :new && "mb-6"}
        >
          <.book_search
            :if={@live_action == :new}
            query={@query}
            results={@results}
            error={@search_error}
          />
        </form>

        <.form for={@form} id="book-form" phx-change="validate" phx-submit="save">
          <div class="grid grid-cols-[5rem_minmax(0,1fr)] gap-x-4">
            <.input
              field={@form[:emoji]}
              label="Emoji"
              placeholder="📖"
              autocomplete="off"
              class="text-center text-xl"
            />
            <.input field={@form[:title]} label="Title" phx-debounce="300" />
          </div>
          <div class="grid gap-x-4 sm:grid-cols-3">
            <div class="sm:col-span-2">
              <.input field={@form[:author]} label="Author" phx-debounce="300" />
            </div>
            <.input field={@form[:read_at]} type="date" label="Read at" />
            <div class="sm:col-span-2">
              <.input
                field={@form[:reading_status]}
                type="select"
                label="Reading status"
                options={@reading_statuses}
              />
            </div>
          </div>
          <fieldset class="fieldset">
            <legend class="fieldset-legend">Cover</legend>
            <div class="flex items-center gap-4">
              <div id="book-cover-preview" class="book-cover-preview">
                <img :if={@cover_url} src={@cover_url} alt="Cover" />
                <img
                  :if={!@cover_url && @book.cover_image}
                  src={image_path(@site, @book.cover_image, "mobile_x1.webp")}
                  alt="Cover"
                />
                <span
                  :if={!@cover_url && !@book.cover_image && @form[:emoji].value not in [nil, ""]}
                  aria-hidden="true"
                >
                  {@form[:emoji].value}
                </span>
                <.icon
                  :if={!@cover_url && !@book.cover_image && @form[:emoji].value in [nil, ""]}
                  name="book-open"
                  class="size-8 text-base-content/70"
                />
              </div>
              <p :if={@live_action == :new} class="label whitespace-normal">
                {if @cover_url,
                  do: "From OpenLibrary. Search again to pick another one.",
                  else: "Search OpenLibrary above to add a cover."}
              </p>
            </div>
            <div :if={@live_action == :edit} class="mt-2">
              <.book_search
                form="book-search-form"
                label={
                  if @cover_url || @book.cover_image, do: "Find another cover", else: "Find a cover"
                }
                query={@query}
                results={@results}
                error={@search_error}
              />
            </div>
          </fieldset>
          <.input field={@form[:isbn]} type="hidden" />
          <.input field={@form[:open_library_key]} type="hidden" />

          <.action_bar class="mt-6">
            <.button navigate={~p"/sites/#{@site.public_id}/books"}>Cancel</.button>
            <.button type="submit" id="save-book" variant={:primary} phx-disable-with="Saving…">
              {if @live_action == :new, do: "Add book", else: "Save"}
            </.button>
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
    %{current_scope: scope, book: book} = socket.assigns

    socket =
      with %Book{} = book <- Books.get_book(scope, book.public_id),
           {:ok, _book} <- Books.delete_book(scope, book) do
        put_flash(socket, :info, "The book was successfully deleted.")
      else
        nil -> put_flash(socket, :error, "This book no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The book could not be deleted.")
      end

    {:noreply, push_navigate(socket, to: ~p"/sites/#{socket.assigns.site.public_id}/books")}
  end

  attr :form, :string, default: nil, doc: "the search form's id, when rendered outside it"
  attr :label, :string, default: "Search OpenLibrary"
  attr :query, :string, required: true
  attr :results, :list, required: true
  attr :error, :string, default: nil

  # The OpenLibrary search: at the top of a new book, in the cover block of
  # an existing one (inside the book form, so its field names the search
  # form).
  defp book_search(assigns) do
    ~H"""
    <.input
      type="search"
      id="book-search"
      name="query"
      value={@query}
      label={@label}
      icon="search"
      placeholder="Title or author"
      autocomplete="off"
      phx-debounce="300"
      form={@form}
      help="Fills in title, author and cover."
    />
    <p :if={@error} id="book-search-error" class="flex items-center gap-1.5 text-sm text-error-ink">
      <.icon name="circle-alert" class="size-4 shrink-0" />{@error}
    </p>
    <ul
      :if={@results != []}
      id="book-search-results"
      class="menu mt-2 w-full rounded-box border border-base-content/10 bg-base-100"
    >
      <li :for={{result, index} <- Enum.with_index(@results)}>
        <button
          type="button"
          id={"book-search-result-#{index}"}
          class="gap-3"
          phx-click="select_result"
          phx-value-index={index}
        >
          <img :if={result.cover_url} src={result.cover_url} width="40" alt="" />
          <span>
            <span class="block font-medium">{result.title}</span>
            <span class="text-sm text-base-content/70">by {result.author || "Unknown"}</span>
          </span>
        </button>
      </li>
    </ul>
    """
  end

  # The bar's link to the book's review; a new book has no bar actions.
  defp review_link(_site, %Book{public_id: nil}), do: nil

  defp review_link(site, book) do
    if Book.review?(book) do
      path = ~p"/sites/#{site.public_id}/books/#{book.public_id}/review/edit"
      %{id: "edit-review", label: "Edit review", path: path}
    else
      path = ~p"/sites/#{site.public_id}/books/#{book.public_id}/review/new"
      %{id: "write-review", label: "Write review", path: path}
    end
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
