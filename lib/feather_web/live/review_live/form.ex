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
      <.header>
        {@page_title}
        <:subtitle>
          <.link navigate={~p"/sites/#{@site.public_id}/books"}>Books</.link> / {@book.title}
        </:subtitle>
      </.header>

      <.live_component
        module={HeaderImagePicker}
        id="review-header-image-picker"
        current_scope={@current_scope}
        header_image={@header_image}
        thumbnail_image={@thumbnail_image}
        emoji={@form[:emoji].value}
      />

      <div class="mb-3 d-flex align-items-center gap-3">
        <span :if={@book.emoji} class="display-6">{@book.emoji}</span>
        <div>
          <span class="form-label d-block mb-1">Rating</span>
          <.star_rating value={@rating} />
        </div>
      </div>

      <.form for={@form} id="review-form" phx-change="validate" phx-submit="save">
        <.header_image_fields form={@form} />
        <.title_and_slug form={@form} hidden={!@show_title_and_slug?} />
        <.editor id="review-content-editor" field={@form[:content]} value={@editor_json} site={@site}>
          <.content_length length={@content_length} />
        </.editor>
        <.input field={@form[:publish_at]} type="datetime-local" label="Publish at (UTC)" step="60" />
        <.input field={@form[:draft]} type="checkbox" label="Draft" />

        <div class="d-flex gap-2">
          <.button variant="primary" phx-disable-with="Saving..." id="save-review">
            {if @live_action == :new, do: "Create Review", else: "Update Review"}
          </.button>
          <.button navigate={~p"/sites/#{@site.public_id}/books"}>Cancel</.button>
          <button
            :if={@live_action == :edit}
            type="button"
            id="delete-review"
            class="btn btn-outline-danger ms-auto"
            phx-click="delete"
            data-confirm="Are you sure?"
          >
            Delete Review
          </button>
        </div>
      </.form>
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
        {:ok, init(socket, book, Content.preload_header_images(post))}

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
    |> assign(:page_title, page_title(socket.assigns.live_action, book))
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

  defp page_title(:new, book), do: "Write Review for #{book.title}"
  defp page_title(:edit, book), do: "Edit Review for #{book.title}"

  defp review_path(site, book, action),
    do: "/sites/#{site.public_id}/books/#{book.public_id}/review/#{action}"
end
