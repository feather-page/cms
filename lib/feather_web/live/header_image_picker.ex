defmodule FeatherWeb.HeaderImagePicker do
  @moduledoc """
  Picks the icon (emoji), thumbnail and cover image of a post, page,
  project or review (port of the Rails `header_image_picker`).

  Images come from an Unsplash search (downloaded with
  `Feather.Media.create_image_from_url/3`, attribution stored in
  `unsplash_data`) or from an upload (`Feather.Media.create_image_from_upload/4`).

  It is rendered outside the record's form (it has forms of its own) and
  tells the parent LiveView about every change by sending
  `{FeatherWeb.HeaderImagePicker, change}` to it, where `change` is
  `{:cover, image | nil}`, `{:thumbnail, image | nil}` or
  `{:emoji, emoji | nil}`. The parent puts the change into its form, see
  `FeatherWeb.ContentForm.put_picker_change/2`.
  """
  use FeatherWeb, :live_component

  alias Feather.{Media, Unsplash}
  alias FeatherWeb.EmojiList

  @type change ::
          {:cover, Media.Image.t() | nil}
          | {:thumbnail, Media.Image.t() | nil}
          | {:emoji, String.t() | nil}

  @upload_extensions ~w(.jpg .jpeg .png .webp .gif .heic .heif .tif .tiff)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(mode: nil, query: "", results: [], error: nil, emoji_open?: false)
     |> assign(:unsplash?, Unsplash.configured?())
     |> allow_upload(:image,
       accept: @upload_extensions,
       max_entries: 1,
       max_file_size: Media.max_byte_size(),
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_new(:emoji, fn -> nil end)}
  end

  # Assigns: id, current_scope (with site), header_image, thumbnail_image
  # (image structs or nil) and emoji.
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="header-image-picker mb-3">
      <div
        :if={@header_image || @thumbnail_image || present?(@emoji)}
        id={"#{@id}-preview"}
        class="header-preview mb-3"
      >
        <div :if={@thumbnail_image} class="thumbnail-preview" id={"#{@id}-thumbnail"}>
          <img
            src={image_path(@current_scope.site, @thumbnail_image, "mobile_x1.webp")}
            alt="Thumbnail"
          />
        </div>
        <div :if={@header_image} class="header-preview-image" id={"#{@id}-cover"}>
          <img src={image_path(@current_scope.site, @header_image, "desktop_x1.webp")} alt="Cover" />
        </div>
        <button
          :if={present?(@emoji)}
          type="button"
          id={"#{@id}-emoji"}
          class={["header-preview-emoji", !@header_image && "header-preview-emoji--inline"]}
          title="Change icon"
          phx-click="toggle_emoji"
          phx-target={@myself}
        >
          {@emoji}
        </button>
      </div>

      <div class="d-flex gap-3 flex-wrap mb-3 position-relative align-items-start">
        <div class="d-flex flex-column gap-1">
          <span class="picker-label">Icon</span>
          <div class="d-flex gap-1">
            <button
              type="button"
              id={"#{@id}-add-emoji"}
              class="btn btn-outline-secondary btn-sm"
              phx-click="toggle_emoji"
              phx-target={@myself}
            >
              <.icon name="smile" size={16} /> {if present?(@emoji),
                do: "Change icon",
                else: "Add icon"}
            </button>
            <button
              :if={present?(@emoji)}
              type="button"
              id={"#{@id}-remove-emoji"}
              class="btn btn-outline-danger btn-sm"
              phx-click="remove"
              phx-value-target="emoji"
              phx-target={@myself}
            >
              Remove
            </button>
          </div>
        </div>

        <.image_section
          :for={
            {target, label, image} <- [
              {"thumbnail", "Thumbnail", @thumbnail_image},
              {"cover", "Cover", @header_image}
            ]
          }
          id={@id}
          target={target}
          label={label}
          image={image}
          unsplash?={@unsplash?}
          myself={@myself}
        />

        <div
          :if={@emoji_open?}
          id={"#{@id}-emoji-picker"}
          class="emoji-picker"
          phx-click-away="close_emoji"
          phx-target={@myself}
        >
          <div class="emoji-picker-scroll">
            <div :for={{category, emojis} <- emoji_categories()} class="emoji-category">
              <div class="emoji-category-label">{category}</div>
              <div class="emoji-picker-grid">
                <button
                  :for={emoji <- emojis}
                  type="button"
                  class="emoji-option"
                  phx-click="select_emoji"
                  phx-value-emoji={emoji}
                  phx-target={@myself}
                >
                  {emoji}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div :if={@mode} id={"#{@id}-panel"} class="card mb-3">
        <div class="card-header d-flex justify-content-between align-items-center">
          <strong>{panel_title(@mode)}</strong>
          <button
            type="button"
            class="btn-close"
            aria-label="Close"
            phx-click="close"
            phx-target={@myself}
          ></button>
        </div>
        <div class="card-body">
          <p :if={@error} id={"#{@id}-error"} class="alert alert-danger">{@error}</p>

          <div :if={match?({:search, _}, @mode)}>
            <form
              id={"#{@id}-search-form"}
              phx-change="search"
              phx-submit="search"
              phx-target={@myself}
            >
              <input
                type="search"
                name="query"
                value={@query}
                class="form-control mb-3"
                placeholder="Search for images..."
                autocomplete="off"
                phx-debounce="300"
              />
            </form>
            <p
              :if={@results == [] and String.length(@query) >= 2 and is_nil(@error)}
              class="text-body-secondary text-center"
            >
              No results found
            </p>
            <div id={"#{@id}-results"} class="unsplash-results">
              <div :for={photo <- @results} class="card unsplash-result" id={"unsplash-#{photo.id}"}>
                <button
                  type="button"
                  class="unsplash-result__choose"
                  phx-click="choose"
                  phx-value-id={photo.id}
                  phx-target={@myself}
                  phx-disable-with="Loading..."
                  title={photo.description}
                >
                  <img src={photo.thumbnail_url} alt={photo.description || ""} />
                </button>
                <small class="text-body-secondary p-1">
                  Photo by
                  <a href={photo.photographer_url} target="_blank" rel="noopener">
                    {photo.photographer_name}
                  </a>
                </small>
              </div>
            </div>
          </div>

          <form
            :if={match?({:upload, _}, @mode)}
            id={"#{@id}-upload-form"}
            phx-change="validate_upload"
            phx-submit="validate_upload"
            phx-target={@myself}
          >
            <.live_file_input upload={@uploads.image} class="form-control" />
            <div class="form-text">Max file size: 25 MB</div>
            <p :for={entry <- @uploads.image.entries} class="small mt-2">
              {entry.client_name} – {entry.progress}%
            </p>
            <p
              :for={error <- upload_errors(@uploads.image) ++ entry_errors(@uploads.image)}
              class="text-danger small mt-2"
            >
              {upload_error_message(error)}
            </p>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :target, :string, required: true
  attr :label, :string, required: true
  attr :image, :any, required: true
  attr :unsplash?, :boolean, required: true
  attr :myself, :any, required: true

  defp image_section(assigns) do
    ~H"""
    <div class="d-flex flex-column gap-1">
      <span class="picker-label">{@label}</span>
      <div class="d-flex gap-1">
        <div class="btn-group" role="group">
          <button
            :if={@unsplash?}
            type="button"
            id={"#{@id}-search-#{@target}"}
            class="btn btn-outline-secondary btn-sm"
            phx-click="open"
            phx-value-mode="search"
            phx-value-target={@target}
            phx-target={@myself}
          >
            <.icon name="image" size={16} /> Search
          </button>
          <button
            type="button"
            id={"#{@id}-upload-#{@target}"}
            class="btn btn-outline-secondary btn-sm"
            phx-click="open"
            phx-value-mode="upload"
            phx-value-target={@target}
            phx-target={@myself}
          >
            <.icon name="upload" size={16} /> Upload
          </button>
        </div>
        <button
          :if={@image}
          type="button"
          id={"#{@id}-remove-#{@target}"}
          class="btn btn-outline-danger btn-sm"
          phx-click="remove"
          phx-value-target={@target}
          phx-target={@myself}
          data-confirm={"Are you sure you want to remove the #{String.downcase(@label)}?"}
        >
          Remove
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("open", %{"mode" => mode, "target" => target}, socket)
      when mode in ~w(search upload) and target in ~w(cover thumbnail) do
    mode = {String.to_existing_atom(mode), String.to_existing_atom(target)}

    {:noreply,
     socket
     |> cancel_uploads()
     |> assign(mode: mode, error: nil, emoji_open?: false)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, socket |> cancel_uploads() |> assign(mode: nil, error: nil)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    case Unsplash.search(query) do
      {:ok, results} -> {:noreply, assign(socket, query: query, results: results, error: nil)}
      {:error, message} -> {:noreply, assign(socket, query: query, results: [], error: message)}
    end
  end

  def handle_event("choose", %{"id" => id}, socket) do
    with {:search, target} <- socket.assigns.mode,
         %{} = photo <- Enum.find(socket.assigns.results, &(&1.id == id)),
         {:ok, image} <-
           Media.create_image_from_url(socket.assigns.current_scope, photo.full_url, %{
             unsplash_data: Unsplash.unsplash_data(photo)
           }) do
      notify_parent({target, image})
      {:noreply, assign(socket, mode: nil, error: nil)}
    else
      _ -> {:noreply, assign(socket, :error, "The image could not be loaded. Please try again.")}
    end
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("remove", %{"target" => target}, socket)
      when target in ~w(cover thumbnail emoji) do
    notify_parent({String.to_existing_atom(target), nil})
    {:noreply, socket}
  end

  def handle_event("toggle_emoji", _params, socket) do
    {:noreply, assign(socket, emoji_open?: not socket.assigns.emoji_open?, mode: nil)}
  end

  def handle_event("close_emoji", _params, socket) do
    {:noreply, assign(socket, :emoji_open?, false)}
  end

  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    notify_parent({:emoji, emoji})
    {:noreply, assign(socket, :emoji_open?, false)}
  end

  defp handle_progress(:image, entry, socket) do
    with true <- entry.done?,
         {:upload, target} <- socket.assigns.mode do
      scope = socket.assigns.current_scope

      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          {:ok, Media.create_image_from_upload(scope, path, entry.client_name)}
        end)

      case result do
        {:ok, image} ->
          notify_parent({target, image})
          {:noreply, assign(socket, mode: nil, error: nil)}

        {:error, changeset} ->
          {:noreply, assign(socket, :error, image_error(changeset))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp cancel_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.image.entries, socket, fn entry, socket ->
      cancel_upload(socket, :image, entry.ref)
    end)
  end

  defp notify_parent(change), do: send(self(), {__MODULE__, change})

  defp image_error(%Ecto.Changeset{errors: errors}) do
    case Keyword.get(errors, :file) do
      {message, _opts} -> "The file #{message}."
      nil -> "The image could not be saved."
    end
  end

  defp entry_errors(upload) do
    Enum.flat_map(upload.entries, &upload_errors(upload, &1))
  end

  defp upload_error_message(:too_large), do: "The file is too big (at most 25 MB)."
  defp upload_error_message(:not_accepted), do: "Only image files can be uploaded."
  defp upload_error_message(:too_many_files), do: "Please choose one file."
  defp upload_error_message(error), do: "Upload failed: #{inspect(error)}"

  defp panel_title({:search, target}), do: "Search Unsplash for a #{target_label(target)}"
  defp panel_title({:upload, target}), do: "Upload a #{target_label(target)}"

  defp target_label(:cover), do: "cover image"
  defp target_label(:thumbnail), do: "thumbnail"

  defp emoji_categories, do: EmojiList.categories()

  defp present?(value), do: FeatherWeb.ContentForm.present?(value)
end
