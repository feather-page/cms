defmodule FeatherWeb.ContentFormComponents do
  @moduledoc """
  Parts of the content editor screens (posts, pages, projects, reviews):
  the two column layout with its "Details" card, the large title input,
  the slug, the Editor.js editor, the hidden header image fields, the
  status badge and the star rating.
  """
  use Phoenix.Component

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
  Renders the Editor.js editor (see `assets/js/hooks/editor_js.js`).

  The hidden input inside carries the Editor.js JSON. LiveView leaves the
  container alone (`phx-update="ignore"`), so the editor keeps its state
  across renders; the hook updates the input and fires an input event on
  every change, which reaches the form's `phx-change`.
  """
  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true, doc: "names the hidden input"
  attr :value, :string, required: true, doc: "the initial Editor.js JSON"
  attr :site, :map, required: true
  attr :label, :string, default: "Content"
  slot :inner_block, doc: "shown below the editor (e.g. the length counter)"

  def editor(assigns) do
    ~H"""
    <div class="mb-3">
      <label class="visually-hidden" for={"#{@id}-input"}>{@label}</label>
      <div
        id={@id}
        class="editor-wrapper"
        phx-hook="EditorJs"
        phx-update="ignore"
        data-image-endpoint={"/sites/#{@site.public_id}/images"}
        data-image-from-url-endpoint={"/sites/#{@site.public_id}/images/from-url"}
        data-book-lookup-endpoint={"/sites/#{@site.public_id}/books/lookup"}
      >
        <div class="editorjs" data-editor-holder></div>
        <input
          type="hidden"
          id={"#{@id}-input"}
          name={@field.name}
          value={@value}
          phx-debounce="300"
        />
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
