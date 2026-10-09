defmodule FeatherWeb.ContentFormComponents do
  @moduledoc """
  Parts of the content editor screens (posts, pages, projects, reviews):
  the two column layout with its "Details" card, the large title input,
  the slug, the block editor with the autosave status, the hidden header
  image fields, the action bar (Publish, Discard, Unpublish, Delete), the
  list of versions and the star rating.
  """
  use Phoenix.Component
  use FeatherWeb, :verified_routes

  import FeatherWeb.CoreComponents

  alias Phoenix.LiveView.JS

  @doc """
  Renders the editor layout: title and content in the wide column, the
  "Details" card next to it (from 992px) or below it, collapsed until
  opened.

  The fields in the details card live outside the record's form (the
  header image picker has forms of its own); give them a `form` attribute
  with the id of the record's form.
  """
  attr :id, :string, required: true, doc: "prefix of the ids, e.g. \"post\""
  attr :open, :boolean, default: false, doc: "opens the details card (e.g. after errors)"
  slot :main, required: true
  slot :details, required: true

  def editor_layout(assigns) do
    ~H"""
    <div class="row g-4 editor-layout">
      <div class="col-12 col-lg-8">{render_slot(@main)}</div>
      <div class="col-12 col-lg-4 editor-details-column">
        <section
          id={"#{@id}-details"}
          class={["card editor-details", @open && "is-open"]}
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
              Details <.icon name="chevron-down" size={18} class="editor-details__chevron" />
            </button>
          </h2>
          <div id={"#{@id}-details-body"} class="card-body editor-details__body">
            {render_slot(@details)}
          </div>
        </section>
      </div>
    </div>
    """
  end

  @doc """
  Renders the block editor (ProseMirror, see `assets/js/hooks/prose_mirror.js`)
  and the form's autosave status.

  The hook loads the document from `value` (ProseMirror JSON, see
  `Feather.Content.ProseMirror`) and autosaves it by pushing `sync` events
  (see "Autosave" in `FeatherWeb.ContentForm`), building on the
  `record`'s `lock_version` (none for a new record: the first sync
  creates it). LiveView leaves the document and the status alone
  (`phx-update="ignore"`), so the editor keeps its state across renders.

  The status (`#<id>-status`) covers the editor and the form fields
  (`status`, see `FeatherWeb.ContentForm.autosave_status/2`), with a
  Reload button (`#<id>-reload`) once the record changed elsewhere.

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
    <div class="mb-3">
      <div
        id={@id}
        class="card block-editor"
        phx-hook="ProseMirror"
        data-label={@label}
        data-lock-version={@record.id && @record.lock_version}
        data-form-status={@status}
        data-image-upload-url={~p"/sites/#{@site.public_id}/images"}
        data-image-from-url-url={~p"/sites/#{@site.public_id}/images/from-url"}
        data-book-lookup-url={~p"/sites/#{@site.public_id}/books/lookup"}
        data-csrf-token={Plug.CSRFProtection.get_csrf_token()}
      >
        <div id={"#{@id}-status"} class="block-editor__status" phx-update="ignore">
          <span data-status-text role="status">Saved</span>
          <button
            type="button"
            id={"#{@id}-reload"}
            class="btn btn-sm btn-outline-primary"
            data-reload
            hidden
          >
            Reload
          </button>
        </div>
        <div id={"#{@id}-document"} phx-update="ignore" data-doc={@value}>
          <div data-editor-mount></div>
        </div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the title as a large input. `hidden` hides it (short posts) but
  keeps it in the form.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :hidden, :boolean, default: false
  attr :id, :string, default: "title-field"

  def title_field(assigns) do
    ~H"""
    <div id={@id} class={["mb-3", @hidden && "d-none"]}>
      <.input
        field={@field}
        class="form-control editor-title"
        placeholder="Title"
        aria-label="Title"
        wrapper_class={nil}
        phx-debounce="300"
        autocomplete="off"
      />
    </div>
    """
  end

  @doc """
  Renders the slug input, for the details card (`form` names the record's
  form). `hidden` hides it (short posts) but keeps it in the form.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :form, :string, required: true
  attr :hidden, :boolean, default: false
  attr :id, :string, default: "slug-field"

  def slug_field(assigns) do
    ~H"""
    <div id={@id} class={@hidden && "d-none"}>
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
  """
  attr :id, :string, default: "star-rating"
  attr :value, :integer, default: nil
  attr :event, :string, default: "rate"

  def star_rating(assigns) do
    ~H"""
    <div id={@id} class="star-rating" role="radiogroup" aria-label="Rating">
      <button
        :for={star <- 5..1//-1}
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
  Renders the Unpublish button of a post, page or project, unless it is a
  draft. Sends `unpublish`.
  """
  attr :id, :string, required: true
  attr :record, :map, required: true

  def unpublish_button(assigns) do
    ~H"""
    <button
      :if={!Feather.Content.draft?(@record)}
      type="button"
      id={@id}
      class="btn btn-outline-secondary"
      phx-click="unpublish"
      data-confirm="Take it off the site? It stays here as a draft."
    >
      <.icon name="eye-off" size={16} /> Unpublish
    </button>
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

  def publish_button(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      class="btn btn-success"
      disabled={@disabled}
      phx-click={JS.dispatch("feather:publish")}
    >
      <.icon name="send" size={16} /> Publish
    </button>
    """
  end

  @doc """
  Renders the Discard button of a record with unpublished changes
  (`status`, see `Feather.Content.publication_status/1`). Sends `discard`.
  """
  attr :id, :string, required: true
  attr :status, :atom, required: true

  def discard_button(assigns) do
    ~H"""
    <button
      :if={@status == :unpublished_changes}
      type="button"
      id={@id}
      class="btn btn-outline-secondary"
      phx-click="discard"
      data-confirm="Discard the unpublished changes and go back to the published version?"
    >
      <.icon name="x" size={16} /> Discard changes
    </button>
    """
  end

  @doc """
  Renders the Restore button of a version (`#restore-version-<number>`).
  Sends `restore` with the version's `number`.
  """
  attr :version, :map, required: true

  def restore_button(assigns) do
    ~H"""
    <button
      type="button"
      id={"restore-version-#{@version.number}"}
      class="btn btn-sm btn-outline-secondary"
      phx-click="restore"
      phx-value-number={@version.number}
      data-confirm={"Restore version #{@version.number}? It replaces the unpublished changes; the published version stays until you publish."}
    >
      <.icon name="rotate-ccw" size={14} /> Restore
    </button>
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
    <section :if={@versions != []} class="mt-3" aria-labelledby={"#{@id}-heading"}>
      <h3 id={"#{@id}-heading"} class="form-label">Versions</h3>
      <ul id={@id} class="list-unstyled d-flex flex-column gap-2 mb-0">
        <li
          :for={version <- @versions}
          id={"version-#{version.number}"}
          class="d-flex flex-wrap align-items-center gap-2"
        >
          <span class="fw-medium">Version {version.number}</span>
          <.status_badge :if={version.id == @published_version_id} kind={:published}>
            Published
          </.status_badge>
          <span class="form-text m-0">
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
  Renders the action bar of a post, page or project form: Publish (disabled
  unless `FeatherWeb.ContentForm.publishable?/3`), Discard, Unpublish and,
  once the record exists, Delete (sends `delete`). The ids are
  `#publish-<id>`, `#discard-<id>`, `#unpublish-<id>` and `#delete-<id>`.
  """
  attr :id, :string, required: true, doc: ~s(e.g. "post")
  attr :record, :map, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :status, :atom, required: true, doc: "the publication status"
  attr :changed_elsewhere?, :boolean, required: true
  attr :noun, :string, required: true, doc: ~s(for the delete confirmation, e.g. "post")

  def content_actions(assigns) do
    ~H"""
    <.action_bar sticky>
      <.publish_button
        id={"publish-#{@id}"}
        disabled={!FeatherWeb.ContentForm.publishable?(@record, @form, @changed_elsewhere?)}
      />
      <.discard_button id={"discard-#{@id}"} status={@status} />
      <.unpublish_button id={"unpublish-#{@id}"} record={@record} />
      <:danger :if={@record.id}>
        <button
          type="button"
          id={"delete-#{@id}"}
          class="btn btn-outline-danger"
          phx-click="delete"
          data-confirm={"Delete this #{@noun}?"}
        >
          <.icon name="trash-2" size={16} /> Delete
        </button>
      </:danger>
    </.action_bar>
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

  @doc "Renders the content length counter (`123 / 300`)."
  attr :length, :integer, required: true
  attr :id, :string, default: "content-length"

  def content_length(assigns) do
    assigns = assign(assigns, :max, FeatherWeb.ContentForm.short_post_length())

    ~H"""
    <div id={@id} class="form-text text-end">{@length} / {@max}</div>
    """
  end
end
