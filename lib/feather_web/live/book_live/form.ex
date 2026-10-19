defmodule FeatherWeb.BookLive.Form do
  @moduledoc """
  Creates and edits books. A book search (server-side, debounced) on
  Hardcover, or on OpenLibrary without a Hardcover token (ADR 0023), fills
  title, author and ISBN of a new book and only the ISBN of an existing
  one. The cover of the chosen result, or an uploaded cover, becomes the
  book's cover on save. The edit page links to the book's review and
  deletes the book.
  """
  use FeatherWeb, :live_view

  alias Feather.{Books, Hardcover, Media, OpenLibrary}
  alias Feather.Books.Book

  @cover_extensions ~w(.jpg .jpeg .png .webp)

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
            label={"Search #{search_name(@search_service)}"}
            help="Fills in title, author and cover."
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
                <%= cond do %>
                  <% entry = List.first(@uploads.cover.entries) -> %>
                    <.live_img_preview entry={entry} alt="Cover" />
                  <% @cover_url -> %>
                    <img src={@cover_url} alt="Cover" />
                  <% @book.cover_image -> %>
                    <img src={image_path(@site, @book.cover_image, "mobile_x1.webp")} alt="Cover" />
                  <% @form[:emoji].value not in [nil, ""] -> %>
                    <span aria-hidden="true">{@form[:emoji].value}</span>
                  <% true -> %>
                    <.icon name="book-open" class="size-8 text-base-content/70" />
                <% end %>
              </div>
              <div class="flex flex-col items-start gap-2">
                <label
                  id="book-cover-upload"
                  class="btn btn-sm focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-primary"
                >
                  <.icon name="upload" />Upload cover
                  <.live_file_input upload={@uploads.cover} class="sr-only" />
                </label>
                <p class="label whitespace-normal">
                  JPG, PNG or WebP, at most {max_cover_mb()} MB.
                </p>
                <p
                  :if={@cover_error}
                  id="book-cover-error"
                  class="flex items-center gap-1.5 text-sm text-error-ink"
                >
                  <.icon name="circle-alert" class="size-4 shrink-0" />{@cover_error}
                </p>
              </div>
            </div>
            <div :if={@live_action == :edit} class="mt-2">
              <.book_search
                form="book-search-form"
                label={
                  if @cover_url || @book.cover_image, do: "Find another cover", else: "Find a cover"
                }
                help={"Searches #{search_name(@search_service)} and sets the cover and ISBN."}
                query={@query}
                results={@results}
                error={@search_error}
              />
            </div>
          </fieldset>
          <.input field={@form[:isbn]} type="hidden" />

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
     |> assign(query: "", results: [], search_error: nil, cover_url: nil, cover_error: nil)
     |> assign(:search_service, if(Hardcover.configured?(), do: Hardcover, else: OpenLibrary))
     |> allow_upload(:cover,
       accept: @cover_extensions,
       max_entries: 1,
       max_file_size: Media.max_byte_size()
     )
     |> assign_form(%{})}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    case socket.assigns.search_service.search(query) do
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
          Map.merge(socket.assigns.params, result_params(socket.assigns.live_action, result))

        {:noreply,
         socket
         |> cancel_cover_uploads()
         |> assign(query: "", results: [], cover_url: result.cover_url, cover_error: nil)
         |> assign_form(params, socket.assigns.form.source.action)}
    end
  end

  def handle_event("validate", params, socket) do
    {:noreply,
     socket
     |> reject_invalid_cover_upload()
     |> assign_form(Map.get(params, "book", socket.assigns.params), :validate)}
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
         |> attach_chosen_cover(saved)
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
  attr :label, :string, required: true
  attr :help, :string, required: true
  attr :query, :string, required: true
  attr :results, :list, required: true
  attr :error, :string, default: nil

  # The book search: at the top of a new book, in the cover block of
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
      help={@help}
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

  defp search_name(Hardcover), do: "Hardcover"
  defp search_name(OpenLibrary), do: "OpenLibrary"

  defp result_params(:new, result) do
    %{"title" => result.title || "", "author" => result.author || "", "isbn" => result.isbn || ""}
  end

  defp result_params(:edit, %{isbn: nil}), do: %{}
  defp result_params(:edit, result), do: %{"isbn" => result.isbn}

  defp cancel_cover_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.cover.entries, socket, &cancel_upload(&2, :cover, &1.ref))
  end

  # An entry with errors would keep LiveView from submitting the form.
  defp reject_invalid_cover_upload(socket) do
    upload = socket.assigns.uploads.cover
    invalid = Enum.reject(upload.entries, & &1.valid?)

    case upload_errors(upload) ++ Enum.flat_map(invalid, &upload_errors(upload, &1)) do
      [] ->
        assign(socket, :cover_error, nil)

      [error | _] ->
        invalid
        |> Enum.reduce(socket, &cancel_upload(&2, :cover, &1.ref))
        |> assign(:cover_error, upload_error_message(error))
    end
  end

  defp max_cover_mb, do: div(Media.max_byte_size(), 1024 * 1024)

  defp upload_error_message(:too_large), do: "The file is too big (at most #{max_cover_mb()} MB)."
  defp upload_error_message(:not_accepted), do: "Only JPG, PNG and WebP images can be uploaded."
  defp upload_error_message(:too_many_files), do: "Please choose one file."
  defp upload_error_message(error), do: "Upload failed: #{inspect(error)}"

  defp attach_chosen_cover(socket, book) do
    scope = socket.assigns.current_scope

    uploaded =
      consume_uploaded_entries(socket, :cover, fn %{path: path}, entry ->
        {:ok, Books.attach_cover_from_upload(scope, book, path, entry.client_name)}
      end)

    case uploaded do
      [result] -> put_cover_error(socket, result, "The cover could not be saved.")
      [] -> attach_cover_url(socket, book)
    end
  end

  defp attach_cover_url(%{assigns: %{cover_url: nil}} = socket, _book), do: socket

  defp attach_cover_url(socket, book) do
    result =
      Books.attach_cover_from_url(socket.assigns.current_scope, book, socket.assigns.cover_url)

    put_cover_error(socket, result, "The cover could not be downloaded.")
  end

  defp put_cover_error(socket, {:ok, _book}, _message), do: socket
  defp put_cover_error(socket, {:error, _reason}, message), do: put_flash(socket, :error, message)

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
