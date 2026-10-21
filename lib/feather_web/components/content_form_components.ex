defmodule FeatherWeb.ContentFormComponents do
  @moduledoc """
  Parts of the content editor screens (posts, pages, projects, reviews):
  the two column layout with its "Details" section, the large title, the
  slug, the block editor and its autosave status, the hidden header image
  fields, the publish actions (Publish ▾ with Unpublish, Discard, Delete),
  the list of versions and the star rating.

  The editor screens are a writing mode: title and text stand on the page
  without frames, the page bar carries where the record sits, its status,
  the autosave status and the publish actions (on phones the publish
  actions sit in a bar at the bottom).
  """
  use Phoenix.Component
  use FeatherWeb, :verified_routes

  use Setzkasten

  alias Phoenix.LiveView.JS

  @doc """
  Renders the editor layout: title and content in the wide column, the
  "Details" section next to it (from 1024px) or below it, collapsed until
  opened.

  The fields in the details section live outside the record's form (the
  header image picker has forms of its own); give them a `form` attribute
  with the id of the record's form.
  """
  attr :id, :string, required: true, doc: "prefix of the ids, e.g. \"post\""
  attr :open, :boolean, default: false, doc: "opens the details section (e.g. after errors)"
  slot :main, required: true
  slot :details, required: true

  def editor_layout(assigns) do
    ~H"""
    <div class="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
      <div class="min-w-0">{render_slot(@main)}</div>
      <section
        id={"#{@id}-details"}
        class={[
          "editor-details min-w-0 border-t border-base-content/10 pt-2",
          "lg:border-t-0 lg:border-s lg:ps-6 lg:pt-0",
          @open && "is-open"
        ]}
        aria-labelledby={"#{@id}-details-toggle"}
      >
        <h2 class="editor-details__heading">
          <button
            type="button"
            id={"#{@id}-details-toggle"}
            class="editor-details__toggle"
            aria-controls={"#{@id}-details-body"}
            aria-expanded={to_string(@open)}
            phx-click={
              JS.toggle_class("is-open", to: "##{@id}-details")
              |> JS.toggle_attribute({"aria-expanded", "true", "false"})
            }
          >
            Details <.icon name="chevron-down" class="editor-details__chevron size-4" />
          </button>
        </h2>
        <div id={"#{@id}-details-body"} class="editor-details__body">
          {render_slot(@details)}
        </div>
      </section>
    </div>
    """
  end

  @doc """
  Renders the block editor (ProseMirror, see `assets/js/hooks/prose_mirror.js`).
  Its autosave status is `editor_status/1`, in the page bar.

  The hook loads the document from `value` (ProseMirror JSON, see
  `Feather.Content.ProseMirror`) and autosaves it by pushing `sync` events
  (see "Autosave" in `FeatherWeb.ContentForm`), building on the
  `record`'s `lock_version` (none for a new record: the first sync
  creates it). LiveView leaves the document and the status alone
  (`phx-update="ignore"`), so the editor keeps its state across renders.

  The status covers the editor and the form fields (`status`, see
  `FeatherWeb.ContentForm.autosave_status/2`).

  Image blocks upload to the `site`'s image endpoints
  (`FeatherWeb.ImageController`), sending the CSRF token.
  """
  attr :id, :string, required: true
  attr :site, :map, required: true, doc: "the record's site, for the image endpoints"
  attr :value, :string, required: true, doc: "the initial ProseMirror JSON"
  attr :record, :map, required: true, doc: "the post, page or project (a new one has no id)"
  attr :status, :string, default: "saved", doc: "the status of the form fields"
  attr :label, :string, default: "Content"
  slot :inner_block, doc: "shown below the editor (e.g. the length counter)"

  # The hook pushes its events from the outer element, which LiveView
  # locks during a push; its children are ignored, so patches that land
  # meanwhile cannot reset the document or the status.
  def editor(assigns) do
    ~H"""
    <div class="mt-4">
      <div
        id={@id}
        class="block-editor"
        phx-hook="ProseMirror"
        data-label={@label}
        data-lock-version={@record.id && @record.lock_version}
        data-form-status={@status}
        data-image-upload-url={~p"/sites/#{@site.public_id}/images"}
        data-image-from-url-url={~p"/sites/#{@site.public_id}/images/from-url"}
        data-book-lookup-url={~p"/sites/#{@site.public_id}/books/lookup"}
        data-diagram-preview-url={~p"/sites/#{@site.public_id}/diagrams/preview"}
        data-code-highlight-url={~p"/sites/#{@site.public_id}/code/highlight"}
        data-csrf-token={Plug.CSRFProtection.get_csrf_token()}
      >
        <div id={"#{@id}-document"} phx-update="ignore" data-doc={@value}>
          <div data-editor-mount></div>
        </div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the autosave status of the editor `editor` (its id): "Saved",
  "Saving…", "Not saved" and so on, written by the editor hook, with a
  Reload button (`#<editor>-reload`) once the record changed elsewhere.
  It shows in the page bar from `md` (`place={:bar}`) and next to Publish
  in the bottom bar on phones (`place={:bottom}`, the ids with `-bottom`).
  """
  attr :editor, :string, required: true
  attr :place, :atom, default: :bar, values: [:bar, :bottom]

  def editor_status(assigns) do
    assigns = assign(assigns, :suffix, if(assigns.place == :bottom, do: "-bottom", else: ""))

    ~H"""
    <div
      id={"#{@editor}-status#{@suffix}"}
      class="block-editor__status"
      data-editor-status={@editor}
      data-place={@place}
      phx-update="ignore"
    >
      <span data-status-text role="status">Saved</span>
      <button
        type="button"
        id={"#{@editor}-reload#{@suffix}"}
        class="btn btn-sm btn-primary btn-outline"
        data-reload
        hidden
      >
        Reload
      </button>
    </div>
    """
  end

  @doc """
  Renders the title as a large heading-like field without a frame. It
  wraps and grows with the title; Enter moves on to the text and line
  breaks (e.g. pasted) become spaces, so the title stays one line of
  text. `hidden` hides it (short posts) but keeps it in the form.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :hidden, :boolean, default: false
  attr :id, :string, default: "title-field"

  def title_field(assigns) do
    ~H"""
    <div id={@id} class={@hidden && "hidden"}>
      <.input
        field={@field}
        type="textarea"
        rows="1"
        label="Title"
        hide_label
        class="editor-title textarea-ghost"
        placeholder="Title"
        phx-debounce="300"
        phx-hook=".TitleField"
        autocomplete="off"
      />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".TitleField">
        export default {
          mounted() {
            this.fit()
            this.el.addEventListener("input", () => {
              if (this.el.value.includes("\n")) {
                const at = this.el.selectionStart
                this.el.value = this.el.value.replace(/\r?\n/g, " ")
                this.el.setSelectionRange(at, at)
              }
              this.fit()
            })
            this.el.addEventListener("keydown", (event) => {
              if (event.key !== "Enter" || event.isComposing) return
              event.preventDefault()
              document.querySelector(".block-editor .ProseMirror")?.focus()
            })
            this.resize = () => this.fit()
            window.addEventListener("resize", this.resize)
          },
          updated() { this.fit() },
          destroyed() { window.removeEventListener("resize", this.resize) },
          fit() {
            this.el.style.height = "auto"
            this.el.style.height = `${this.el.scrollHeight}px`
          }
        }
      </script>
    </div>
    """
  end

  @doc """
  Renders the slug input, for the details section (`form` names the record's
  form).
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :form, :string, required: true
  attr :id, :string, default: "slug-field"

  def slug_field(assigns) do
    ~H"""
    <div id={@id}>
      <.input
        field={@field}
        label="Slug"
        placeholder="/a-nice-slug"
        form={@form}
        phx-debounce="300"
        autocomplete="off"
      />
    </div>
    """
  end

  @doc """
  Renders the meta title input of a short post, for the details section
  (`form` names the record's form).
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :form, :string, required: true
  attr :id, :string, default: "meta-title-field"

  def meta_title_field(assigns) do
    ~H"""
    <div id={@id}>
      <.input
        field={@field}
        label="Meta title"
        help="Names this short post in search results and feed readers, not on the site. Written for you when you first publish it."
        form={@form}
        phx-debounce="300"
        autocomplete="off"
      />
    </div>
    """
  end

  @doc """
  Renders the description input with its Suggest button
  (`#suggest-description`, sends `suggest_description`), for the details
  section of posts and pages (`form` names the record's form). The button
  needs a saved record and waits while a suggestion is on its way.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :form, :string, required: true
  attr :record, :map, required: true
  attr :suggesting, :boolean, default: false
  attr :id, :string, default: "description-field"

  def description_field(assigns) do
    ~H"""
    <div id={@id}>
      <.input
        field={@field}
        type="textarea"
        label="Description"
        help="Shown in search results and link previews. Written for you when you publish while it is empty."
        form={@form}
        rows="3"
        phx-debounce="300"
      />
      <.button
        id="suggest-description"
        type="button"
        size={:sm}
        loading={@suggesting}
        disabled={is_nil(@record.id) or @suggesting}
        phx-click="suggest_description"
      >
        Suggest
      </.button>
    </div>
    """
  end

  @doc """
  Renders the record's counter as a hidden field of its form (empty for a
  new record), so the values LiveView recovers after a reconnect name the
  counter they were shown with (see "Autosave" in
  `FeatherWeb.ContentForm`). The form needs `phx-auto-recover="recover"`.
  """
  attr :record, :map, required: true

  def lock_version_field(assigns) do
    ~H"""
    <input type="hidden" name="lock_version" value={@record.id && @record.lock_version} />
    """
  end

  @doc """
  Renders the hidden fields set by the header image picker.
  """
  attr :form, Phoenix.HTML.Form, required: true

  def header_image_fields(assigns) do
    ~H"""
    <.input field={@form[:header_image_id]} type="hidden" />
    <.input field={@form[:thumbnail_image_id]} type="hidden" />
    <.input field={@form[:emoji]} type="hidden" />
    """
  end

  @doc """
  Renders a five star rating; clicking a star sends `event` with the value.
  The stars come in reading order, so Tab walks from one star to five.
  """
  attr :id, :string, default: "star-rating"
  attr :value, :integer, default: nil
  attr :event, :string, default: "rate"

  def star_rating(assigns) do
    ~H"""
    <div id={@id} class="star-rating" role="radiogroup" aria-label="Rating">
      <button
        :for={star <- 1..5}
        type="button"
        id={"#{@id}-#{star}"}
        class={["star", @value && star <= @value && "filled"]}
        phx-click={@event}
        phx-value-rating={star}
        role="radio"
        aria-checked={to_string(@value == star)}
        aria-label={"#{star} #{if star == 1, do: "star", else: "stars"}"}
      >
        ★
      </button>
    </div>
    """
  end

  @doc """
  Renders the Publish button. It dispatches `feather:publish`, on which
  the editor hook sends its pending edits and then pushes `publish` with
  its status, so no edit typed before the click is missed. Disabled while
  the record cannot be published (see
  `FeatherWeb.ContentForm.publishable?/3`).
  """
  attr :id, :string, required: true
  attr :disabled, :boolean, default: false
  attr :class, :any, default: nil

  def publish_button(assigns) do
    ~H"""
    <.button
      id={@id}
      class={@class}
      variant={:primary}
      icon="send"
      disabled={@disabled}
      phx-click={JS.dispatch("feather:publish")}
    >
      Publish
    </.button>
    """
  end

  @doc """
  Renders the Restore button of a version (`#restore-version-<number>`).
  Sends `restore` with the version's `number`.
  """
  attr :version, :map, required: true

  def restore_button(assigns) do
    ~H"""
    <.button
      id={"restore-version-#{@version.number}"}
      size={:sm}
      icon="rotate-ccw"
      phx-click="restore"
      phx-value-number={@version.number}
      confirm={"Restore version #{@version.number}?"}
      confirm_text="It replaces the unpublished changes; the published version stays until you publish."
      confirm_label="Restore"
    >
      Restore
    </.button>
    """
  end

  @doc """
  Renders the versions of a record, newest first: number, when and by whom
  it was published, and which one is the published version. The `action`
  slot renders per version (it gets the version).
  """
  attr :id, :string, default: "versions"
  attr :versions, :list, required: true
  attr :published_version_id, :string, default: nil
  slot :action

  def versions_list(assigns) do
    ~H"""
    <section :if={@versions != []} class="editor-details__group" aria-labelledby={"#{@id}-heading"}>
      <h3 id={"#{@id}-heading"} class="editor-details__group-heading">Versions</h3>
      <ul id={@id} class="flex flex-col gap-3">
        <li
          :for={version <- @versions}
          id={"version-#{version.number}"}
          class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm"
        >
          <span class="font-medium">Version {version.number}</span>
          <.badge :if={version.id == @published_version_id} tone={:success}>Published</.badge>
          <span class="basis-full text-base-content/70">
            {Calendar.strftime(version.published_at, "%d/%m/%Y %H:%M")}
            <span :if={version.published_by}>by {version.published_by.email}</span>
          </span>
          {render_slot(@action, version)}
        </li>
      </ul>
    </section>
    """
  end

  @doc """
  Renders the publish actions of a post, page or project form: Publish
  (disabled unless `FeatherWeb.ContentForm.publishable?/3`) and a menu
  with Unpublish (once published), Discard changes (with unpublished
  changes) and Delete (once the record exists). From `md` they sit in the
  page bar (`place={:bar}`, ids `#publish-<id>`, `#unpublish-<id>`,
  `#discard-<id>`, `#delete-<id>`); on phones in a bar at the bottom
  (`place={:bottom}`, the same ids with `-bottom`).
  """
  attr :id, :string, required: true, doc: ~s(e.g. "post")
  attr :record, :map, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :status, :atom, required: true, doc: "the publication status"
  attr :changed_elsewhere?, :boolean, required: true
  attr :noun, :string, required: true, doc: ~s(for the delete confirmation, e.g. "post")
  attr :place, :atom, default: :bar, values: [:bar, :bottom]

  def content_actions(assigns) do
    assigns =
      assign(assigns,
        suffix: if(assigns.place == :bottom, do: "-bottom", else: ""),
        unpublish?: !Feather.Content.draft?(assigns.record),
        discard?: assigns.status == :unpublished_changes
      )

    ~H"""
    <div class="join">
      <.publish_button
        id={"publish-#{@id}#{@suffix}"}
        class={(@unpublish? or @discard? or @record.id) && "join-item"}
        disabled={!FeatherWeb.ContentForm.publishable?(@record, @form, @changed_elsewhere?)}
      />
      <.dropdown
        :if={@unpublish? or @discard? or @record.id}
        id={"publish-menu-#{@id}#{@suffix}"}
        label="More publishing actions"
        align={:end}
        position={if @place == :bottom, do: :top, else: :bottom}
        trigger_class="btn-primary join-item px-2"
      >
        <:trigger></:trigger>
        <:item
          :if={@unpublish?}
          id={"unpublish-#{@id}#{@suffix}"}
          icon="eye-off"
          on_click="unpublish"
        >
          Unpublish
        </:item>
        <:item
          :if={@discard?}
          id={"discard-#{@id}#{@suffix}"}
          icon="x"
          on_click="discard"
          confirm="Discard the unpublished changes?"
          confirm_text="The published version comes back; your changes since then are gone."
          confirm_label="Discard"
        >
          Discard changes
        </:item>
        <:item
          :if={@record.id}
          id={"delete-#{@id}#{@suffix}"}
          icon="trash-2"
          on_click="delete"
          confirm={"Delete this #{@noun}?"}
          confirm_text={FeatherWeb.SiteComponents.delete_text(@noun, @record)}
          danger
          divider={@unpublish? or @discard?}
        >
          Delete
        </:item>
      </.dropdown>
    </div>
    """
  end

  @doc """
  Renders the versions of a record with a Restore button for every
  version but the published one.
  """
  attr :versions, :list, required: true
  attr :record, :map, required: true

  def record_versions(assigns) do
    ~H"""
    <.versions_list versions={@versions} published_version_id={@record.published_version_id}>
      <:action :let={version}>
        <.restore_button :if={version.id != @record.published_version_id} version={version} />
      </:action>
    </.versions_list>
    """
  end

  @doc """
  Renders the content length of a short post against the length from
  which its title field is shown (see "Short posts" in
  `FeatherWeb.ContentForm`): `Short post · 123 / 300 characters`, from 300
  characters `300 characters · title field shown`. For posts without title
  and slug.
  """
  attr :length, :integer, required: true
  attr :id, :string, default: "content-length"

  def content_length(assigns) do
    assigns = assign(assigns, :max, FeatherWeb.ContentForm.short_post_length())

    ~H"""
    <p id={@id} class="mt-1 text-end text-sm text-base-content/70 tabular-nums">
      <%= if @length < @max do %>
        Short post · {@length} / {@max} characters
      <% else %>
        {@length} characters · title field shown
      <% end %>
    </p>
    """
  end
end
