defmodule FeatherWeb.HeaderImagePicker do
  @moduledoc """
  Picks the icon (emoji), thumbnail and cover image of a post, page,
  project or review (port of the Rails `header_image_picker`): three
  media slots, each a preview tile with "Add" or "Change" and "Remove".

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
    <div id={@id} class="media-picker">
      <div class="media-slots">
        <div class="media-slot" id={"#{@id}-icon-slot"}>
          <button
            type="button"
            class={["media-slot__tile", !present?(@emoji) && "media-slot__tile--empty"]}
            tabindex="-1"
            aria-hidden="true"
            phx-click="toggle_emoji"
            phx-target={@myself}
          >
            <span :if={present?(@emoji)} id={"#{@id}-emoji"}>{@emoji}</span>
            <.icon :if={!present?(@emoji)} name="smile" size={24} />
          </button>
          <span class="media-slot__label">Icon</span>
          <div class="media-slot__actions">
            <button
              type="button"
              id={"#{@id}-choose-emoji"}
              class="media-slot__action"
              aria-label={if present?(@emoji), do: "Change icon", else: "Add icon"}
              phx-click="toggle_emoji"
              phx-target={@myself}
            >
              {if present?(@emoji), do: "Change", else: "Add"}
            </button>
            <button
              :if={present?(@emoji)}
              type="button"
              id={"#{@id}-remove-emoji"}
              class="media-slot__action media-slot__action--danger"
              aria-label="Remove icon"
              phx-click="remove"
              phx-value-target="emoji"
              phx-target={@myself}
            >
              Remove
            </button>
          </div>
        </div>

        <.image_slot
          :for={
            {target, label, image, version} <- [
              {"thumbnail", "Thumbnail", @thumbnail_image, "mobile_x1.webp"},
              {"cover", "Cover", @header_image, "mobile_x1.webp"}
            ]
          }
          id={@id}
          target={target}
          label={label}
          image={image}
          src={image && image_path(@current_scope.site, image, version)}
          mode={if @unsplash?, do: "search", else: "upload"}
          myself={@myself}
        />
      </div>

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

      <div :if={@mode} id={"#{@id}-panel"} class="media-panel">
        <div class="media-panel__header">
          <span>{panel_title(@mode)}</span>
          <button
            type="button"
            class="btn-close"
            aria-label="Close"
            phx-click="close"
            phx-target={@myself}
          ></button>
        </div>
        <div class="media-panel__body">
          <div :if={@unsplash?} class="btn-group btn-group-sm d-flex mb-3" role="group">
            <button
              :for={{mode, label} <- [{:search, "Search Unsplash"}, {:upload, "Upload"}]}
              type="button"
              id={"#{@id}-#{mode}-#{elem(@mode, 1)}"}
              class={["btn btn-light flex-fill", elem(@mode, 0) == mode && "active"]}
              aria-pressed={to_string(elem(@mode, 0) == mode)}
              phx-click="open"
              phx-value-mode={mode}
              phx-value-target={elem(@mode, 1)}
              phx-target={@myself}
            >
              {label}
            </button>
          </div>

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
                aria-label="Search Unsplash"
                autocomplete="off"
                phx-debounce="300"
              />
            </form>
            <p
              :if={@results == [] and String.length(@query) >= 2 and is_nil(@error)}
              class="text-body-secondary text-center small"
            >
              No results found
            </p>
            <div id={"#{@id}-results"} class="unsplash-results">
              <div :for={photo <- @results} class="unsplash-result" id={"unsplash-#{photo.id}"}>
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
                <span class="unsplash-result__credit text-truncate">
                  by
                  <a href={photo.photographer_url} target="_blank" rel="noopener">
                    {photo.photographer_name}
                  </a>
                </span>
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
            <.live_file_input
              upload={@uploads.image}
              class="form-control"
              aria-label={panel_title(@mode)}
            />
            <div class="form-text">At most 25 MB</div>
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
  attr :src, :string, default: nil
  attr :mode, :string, required: true, doc: "the panel mode to open: search or upload"
  attr :myself, :any, required: true

  defp image_slot(assigns) do
    ~H"""
    <div class="media-slot" id={"#{@id}-#{@target}-slot"}>
      <button
        type="button"
        id={@image && "#{@id}-#{@target}"}
        class={["media-slot__tile", !@image && "media-slot__tile--empty"]}
        tabindex="-1"
        aria-hidden="true"
        phx-click="open"
        phx-value-mode={@mode}
        phx-value-target={@target}
        phx-target={@myself}
      >
        <img :if={@image} src={@src} alt="" />
        <.icon :if={!@image} name="image" size={24} />
      </button>
      <span class="media-slot__label">{@label}</span>
      <div class="media-slot__actions">
        <button
          type="button"
          id={"#{@id}-choose-#{@target}"}
          class="media-slot__action"
          aria-label={"#{if @image, do: "Change", else: "Add"} #{String.downcase(@label)}"}
          phx-click="open"
          phx-value-mode={@mode}
          phx-value-target={@target}
          phx-target={@myself}
        >
          {if @image, do: "Change", else: "Add"}
        </button>
        <button
          :if={@image}
          type="button"
          id={"#{@id}-remove-#{@target}"}
          class="media-slot__action media-slot__action--danger"
          aria-label={"Remove #{String.downcase(@label)}"}
          phx-click="remove"
          phx-value-target={@target}
          phx-target={@myself}
          data-confirm={"Remove the #{String.downcase(@label)}?"}
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

  defp panel_title({_mode, target}), do: "Choose a #{target_label(target)}"

  defp target_label(:cover), do: "cover image"
  defp target_label(:thumbnail), do: "thumbnail"

  defp emoji_categories, do: EmojiList.categories()

  defp present?(value), do: FeatherWeb.ContentForm.present?(value)
end
