defmodule FeatherWeb.ReviewLive.Form do
  @moduledoc """
  Writes, edits and deletes the review of a book: a post linked from the
  book plus the book's star rating. Like posts, short reviews hide title
  and slug; once they show, the title defaults to "Review: <book title>".
  Every change is saved into the unpublished changes at once; the first
  input creates the review as a draft (see "Autosave" in
  `FeatherWeb.ContentForm`). Publish publishes it, Discard puts the
  published version back, Restore an earlier version. The rating is the
  book's: it saves at once and is not versioned.
  """
  use FeatherWeb, :live_view
  @behaviour FeatherWeb.ContentForm

  import FeatherWeb.ContentFormComponents

  alias Feather.{Books, Content}
  alias Feather.Books.Book
  alias Feather.Content.Post
  alias FeatherWeb.{ContentForm, HeaderImagePicker}

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
          <.publication_badge id="status-badge" status={@publication_status} />
        </:badge>
        <:subtitle>
          {@book.emoji} {@book.title}<span :if={@book.author}> by {@book.author}</span>
        </:subtitle>
      </.header>

      <.editor_layout id="review" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form
            for={@form}
            id="review-form"
            phx-change="autosave"
            phx-submit="autosave"
            phx-auto-recover="recover"
          >
            <.lock_version_field record={@post} />
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} hidden={!@show_title_and_slug?} />
            <.editor
              id="review-content-editor"
              site={@current_scope.site}
              value={@editor_json}
              record={@post}
              status={ContentForm.autosave_status(@form, @changed_elsewhere?)}
            >
              <.content_length length={@content_length} />
            </.editor>
          </.form>
        </:main>
        <:details>
          <div class="mb-3">
            <span class="form-label">Rating</span>
            <.star_rating value={@book.rating} />
          </div>
          <.slug_field field={@form[:slug]} form="review-form" hidden={!@show_title_and_slug?} />
          <.input
            field={@form[:publish_at]}
            type="datetime-local"
            label="Publish at (UTC)"
            step="60"
            form="review-form"
          />
          <.live_component
            module={HeaderImagePicker}
            id="review-header-image-picker"
            current_scope={@current_scope}
            header_image={@header_image}
            thumbnail_image={@thumbnail_image}
            emoji={@form[:emoji].value}
          />
          <.record_versions versions={@versions} record={@post} />
        </:details>
      </.editor_layout>

      <.content_actions
        id="review"
        noun="review"
        record={@post}
        form={@form}
        status={@publication_status}
        changed_elsewhere?={@changed_elsewhere?}
      />
    </.site_shell>
    """
  end

  @impl true
  def mount(%{"book_id" => book_id}, _session, socket) do
    scope = socket.assigns.current_scope
    book = Books.get_book!(scope, book_id)

    case {socket.assigns.live_action, Books.get_review_post(scope, book)} do
      {:new, nil} ->
        {:ok, init(socket, book, %Post{site_id: scope.site.id})}

      {:edit, %Post{} = post} ->
        {:ok, init(socket, book, Content.preload_images(post))}

      {:new, %Post{}} ->
        {:ok, push_navigate(socket, to: review_path(scope.site, book, "edit"))}

      {:edit, nil} ->
        {:ok, push_navigate(socket, to: review_path(scope.site, book, "new"))}
    end
  end

  defp init(socket, book, post) do
    socket
    |> assign(:book, book)
    |> ContentForm.mount_record(post)
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    %{live_action: action, book: book, post: post} = socket.assigns
    {:noreply, assign(socket, :page_title, page_title(action, book, post))}
  end

  @impl true
  def handle_event("rate", params, socket) do
    %{current_scope: scope, book: book} = socket.assigns

    case Books.update_book(scope, book, %{rating: params["rating"]}) do
      {:ok, book} -> {:noreply, assign(socket, :book, book)}
      {:error, _invalid_rating} -> {:noreply, socket}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _book} = Books.delete_review(socket.assigns.current_scope, socket.assigns.book)

    {:noreply,
     socket
     |> put_flash(:info, "Review was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/books")}
  end

  def handle_event(event, params, socket), do: ContentForm.handle_event(event, params, socket)

  @impl true
  def handle_info(message, socket), do: ContentForm.handle_info(message, socket)

  @impl ContentForm
  def record(socket), do: socket.assigns.post

  @impl ContentForm
  def save_fields(socket, attrs, opts) do
    %{current_scope: scope, book: book, post: post} = socket.assigns

    with {:ok, %{book: book, post: post}} <- Books.autosave_review(scope, book, post, attrs, opts) do
      {:ok, post, assign(socket, :book, book)}
    end
  end

  @impl ContentForm
  def edit_path(socket, _post), do: review_path(socket.assigns.site, socket.assigns.book, "edit")

  @impl ContentForm
  def assign_form(socket, params, action \\ nil) do
    %{current_scope: scope, post: post, book: book} = socket.assigns
    length = ContentForm.content_length(post)

    form = build_form(scope, post, params, action)

    # Like the Rails post_form controller: when title and slug appear and the
    # title is empty, suggest "Review: <book title>".
    {params, form} =
      if ContentForm.show_title_and_slug?(form, length) and
           not ContentForm.present?(form[:title].value) do
        params = Map.put(params, "title", Book.review_title_suggestion(book))
        {params, build_form(scope, post, params, action)}
      else
        {params, form}
      end

    socket
    |> assign(:params, params)
    |> assign(:form, form)
    |> assign(:content_length, length)
    |> assign(:show_title_and_slug?, ContentForm.show_title_and_slug?(form, length))
  end

  @impl ContentForm
  def assign_record(socket, post), do: assign(socket, :post, post)

  @impl ContentForm
  def noun, do: "Review"

  defp build_form(scope, post, params, action) do
    scope
    |> Content.change_post(post, params)
    |> Map.put(:action, action)
    |> to_form()
  end

  defp page_title(:new, _book, _post), do: "New review"

  defp page_title(:edit, book, post),
    do: ContentForm.heading(post, Book.review_title_suggestion(book))

  defp review_path(site, book, action),
    do: "/sites/#{site.public_id}/books/#{book.public_id}/review/#{action}"
end
