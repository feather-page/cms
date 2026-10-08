defmodule FeatherWeb.ReviewLive.Form do
  @moduledoc """
  Writes, edits and deletes the review of a book: a post linked from the
  book plus the book's star rating. Like posts, short reviews hide title
  and slug; once they show, the title defaults to "Review: <book title>".
  """
  use FeatherWeb, :live_view

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
          <.status_badge :if={@post.draft} id="status-badge" kind={:draft}>Draft</.status_badge>
          <.status_badge :if={!@post.draft} id="status-badge" kind={:published}>
            Published
          </.status_badge>
        </:badge>
        <:subtitle>
          {@book.emoji} {@book.title}<span :if={@book.author}> by {@book.author}</span>
        </:subtitle>
      </.header>

      <.editor_layout id="review" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form for={@form} id="review-form" phx-change="validate" phx-submit="save">
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} hidden={!@show_title_and_slug?} />
            <.editor
              id="review-content-editor"
              field={@form[:content]}
              value={@editor_json}
              site={@site}
            >
              <.content_length length={@content_length} />
            </.editor>
          </.form>
        </:main>
        <:details>
          <div class="mb-3">
            <span class="form-label">Rating</span>
            <.star_rating value={@rating} />
          </div>
          <.slug_field field={@form[:slug]} form="review-form" hidden={!@show_title_and_slug?} />
          <.input
            field={@form[:publish_at]}
            type="datetime-local"
            label="Publish at (UTC)"
            step="60"
            form="review-form"
          />
          <.input field={@form[:draft]} type="checkbox" label="Draft" switch form="review-form" />
          <.live_component
            module={HeaderImagePicker}
            id="review-header-image-picker"
            current_scope={@current_scope}
            header_image={@header_image}
            thumbnail_image={@thumbnail_image}
            emoji={@form[:emoji].value}
          />
        </:details>
      </.editor_layout>

      <.action_bar sticky>
        <button
          type="submit"
          form="review-form"
          id="save-review"
          class="btn btn-primary"
          phx-disable-with="Saving..."
        >
          {if @live_action == :new, do: "Create review", else: "Save"}
        </button>
        <.link navigate={~p"/sites/#{@site.public_id}/books"} class="btn btn-light">Cancel</.link>
        <:danger :if={@live_action == :edit}>
          <button
            type="button"
            id="delete-review"
            class="btn btn-outline-danger"
            phx-click="delete"
            data-confirm="Delete this review?"
          >
            <.icon name="trash-2" size={16} /> Delete
          </button>
        </:danger>
      </.action_bar>
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
    scope = socket.assigns.current_scope

    socket
    |> assign(:site, scope.site)
    |> assign(:page_title, page_title(socket.assigns.live_action, book, post))
    |> assign(:book, book)
    |> assign(:post, post)
    |> assign(:rating, book.rating)
    |> assign(:header_image, ContentForm.loaded(post.header_image))
    |> assign(:thumbnail_image, ContentForm.loaded(post.thumbnail_image))
    |> assign(:slug_touched?, ContentForm.present?(post.slug))
    |> assign(:editor_json, ContentForm.editor_json(scope, post))
    |> assign_form(%{})
  end

  @impl true
  def handle_event("rate", %{"rating" => rating}, socket) do
    {:noreply, assign(socket, :rating, String.to_integer(rating))}
  end

  def handle_event("validate", %{"post" => post_params} = params, socket) do
    socket =
      assign(
        socket,
        :slug_touched?,
        socket.assigns.slug_touched? or ContentForm.slug_target?(params, "post")
      )

    post_params =
      ContentForm.maybe_suggest_slug(
        post_params,
        params,
        "post",
        socket.assigns.current_scope,
        socket.assigns.slug_touched?
      )

    {:noreply, assign_form(socket, post_params, :validate)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    %{current_scope: scope, book: book, post: post, rating: rating} = socket.assigns

    result =
      case socket.assigns.live_action do
        :new ->
          with {:ok, %{book: book}} <- Books.create_review(scope, book, post_params) do
            Books.update_book(scope, book, %{rating: rating})
          end

        :edit ->
          with {:ok, _post} <- Content.update_post(scope, post, post_params) do
            Books.update_book(scope, book, %{rating: rating})
          end
      end

    case result do
      {:ok, _book} ->
        message =
          if socket.assigns.live_action == :new,
            do: "Review was successfully created.",
            else: "Review was successfully updated."

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/books")}

      {:error, %Ecto.Changeset{data: %Post{}}} ->
        {:noreply, assign_form(socket, post_params, :insert)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The review could not be saved.")}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _book} = Books.delete_review(socket.assigns.current_scope, socket.assigns.book)

    {:noreply,
     socket
     |> put_flash(:info, "Review was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/books")}
  end

  @impl true
  def handle_info({HeaderImagePicker, change}, socket) do
    params = ContentForm.put_picker_change(socket.assigns.params, change)

    {:noreply,
     socket
     |> assign(ContentForm.picker_assigns(change))
     |> assign_form(params, socket.assigns.form.source.action)}
  end

  defp assign_form(socket, params, action \\ nil) do
    %{current_scope: scope, post: post, book: book} = socket.assigns
    length = ContentForm.content_length(params, post)

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
