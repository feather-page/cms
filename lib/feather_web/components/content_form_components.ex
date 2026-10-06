defmodule FeatherWeb.ContentFormComponents do
  @moduledoc """
  Form parts of the content forms (posts, pages, projects, reviews): the
  Editor.js editor, title and slug, the hidden header image fields and the
  star rating.
  """
  use Phoenix.Component

  import FeatherWeb.CoreComponents

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
      <label class="form-label" for={"#{@id}-input"}>{@label}</label>
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
  Renders title and slug. `hidden` hides them (short posts) but keeps them
  in the form.
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :hidden, :boolean, default: false
  attr :id, :string, default: "title-and-slug"

  def title_and_slug(assigns) do
    ~H"""
    <div id={@id} class={["mb-3", @hidden && "d-none"]}>
      <.input field={@form[:title]} label="Title" phx-debounce="300" autocomplete="off" />
      <.input
        field={@form[:slug]}
        label="Slug"
        placeholder="/a-nice-slug"
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
    <div id={@id} class="form-text">{@length} / {@max}</div>
    """
  end
end
