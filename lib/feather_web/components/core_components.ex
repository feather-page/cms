defmodule FeatherWeb.CoreComponents do
  @moduledoc """
  Core UI components of the admin.

  Styling comes from [felt-css](https://felt-css.rocu.de), a small
  Bootstrap-compatible toolkit loaded in the root layout: use Bootstrap
  class names (`btn btn-primary`, `form-control`, `form-select`,
  `form-check`, `card`, `table`, `nav nav-pills`, `alert alert-*`, `badge`,
  `list-group`, `d-flex`, `gap-*`, `mb-*`, ...). There is no Tailwind.

  Icons are inline SVGs, see `icon/1`.
  """
  use Phoenix.Component
  use Gettext, backend: FeatherWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "alert d-flex align-items-start gap-2 flash",
        @kind == :info && "alert-info",
        @kind == :error && "alert-danger"
      ]}
      {@rest}
    >
      <.icon :if={@kind == :info} name="info" />
      <.icon :if={@kind == :error} name="circle-alert" />
      <div class="flex-grow-1">
        <strong :if={@title} class="d-block">{@title}</strong>
        <span>{msg}</span>
      </div>
      <button type="button" class="btn-close" aria-label={gettext("close")}></button>
    </div>
    """
  end

  @doc """
  Renders a button, or a link styled as a button when `href`, `navigate`
  or `patch` is given.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"} variant="outline">Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type)
  attr :class, :any, default: nil
  attr :variant, :string, values: [nil | ~w(primary secondary outline danger link)], default: nil
  attr :size, :string, values: [nil, "sm", "lg"], default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary",
      "secondary" => "btn-secondary",
      "outline" => "btn-outline-primary",
      "danger" => "btn-danger",
      "link" => "btn-link",
      nil => "btn-outline-secondary"
    }

    assigns =
      assign(assigns, :classes, [
        "btn",
        Map.fetch!(variants, assigns.variant),
        assigns.size && "btn-#{assigns.size}",
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument, which is used to
  retrieve the input name, id, and values. Otherwise all attributes may be
  passed explicitly.

  Besides the HTML input types, `type="select"` renders a `<select>` (pass
  `options`, see `Phoenix.HTML.Form.options_for_select/2`),
  `type="textarea"` a `<textarea>` and `type="checkbox"` a boolean
  checkbox.

  ## Examples

      <.input field={@form[:email]} type="email" label="Email" />
      <.input field={@form[:page_type]} type="select" options={["Default": "default"]} />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :help, :string, default: nil, doc: "a help text shown below the input"

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="form-check mb-3">
      <input
        type="hidden"
        name={@name}
        value="false"
        disabled={@rest[:disabled]}
        form={@rest[:form]}
      />
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value="true"
        checked={@checked}
        class={[@class || "form-check-input", @errors != [] && "is-invalid"]}
        {@rest}
      />
      <label :if={@label} for={@id} class="form-check-label">{@label}</label>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@help} class="form-text">{@help}</div>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-3">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <select
        id={@id}
        name={@name}
        class={[@class || "form-select", @errors != [] && "is-invalid"]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@help} class="form-text">{@help}</div>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-3">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <textarea
        id={@id}
        name={@name}
        class={[@class || "form-control", @errors != [] && "is-invalid"]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@help} class="form-text">{@help}</div>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="mb-3">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[@class || "form-control", @errors != [] && "is-invalid"]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@help} class="form-text">{@help}</div>
    </div>
    """
  end

  # Bootstrap only shows .invalid-feedback after an .is-invalid sibling, so
  # force it visible: the error belongs to the field either way.
  defp error(assigns) do
    ~H"""
    <div class="invalid-feedback d-flex gap-1 align-items-center">
      <.icon name="circle-alert" size={16} />
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a page header with title, optional subtitle and actions.
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      "mb-4",
      @actions != [] && "d-flex align-items-center justify-content-between gap-3",
      @class
    ]}>
      <div>
        <h1 class="h3 mb-1">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-body-secondary mb-0">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="d-flex gap-2">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="table-responsive">
      <table class="table table-hover align-middle">
        <thead>
          <tr>
            <th :for={col <- @col}>{col[:label]}</th>
            <th :if={@action != []}>
              <span class="visually-hidden">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={@row_click && "clickable"}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="text-end text-nowrap">
              <div class="d-inline-flex gap-2">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="row">
      <%= for item <- @item do %>
        <dt class="col-sm-3">{item.title}</dt>
        <dd class="col-sm-9">{render_slot(item)}</dd>
      <% end %>
    </dl>
    """
  end

  @doc """
  Renders an icon as inline SVG.

  Accepts Lucide names (`"pencil"`, `"trash-2"`), the old Bootstrap Icons
  names of the Rails admin (`"pen"`, `"trash"`, `"gear"`) and the social
  media brand icons (`"github"`, `"mastodon"`, ...). Unknown names render
  a question mark icon.

  ## Examples

      <.icon name="pencil" />
      <.icon name="github" size={24} class="text-primary" />
  """
  attr :name, :string, required: true
  attr :size, :integer, default: 20
  attr :class, :any, default: nil
  attr :rest, :global

  def icon(assigns) do
    case FeatherWeb.Icons.paths(assigns.name) do
      nil ->
        case Feather.Sites.SocialMediaService.svg(assigns.name) do
          nil -> lucide(assign(assigns, :paths, FeatherWeb.Icons.fallback_paths()))
          svg -> brand(assign(assigns, :svg, svg))
        end

      paths ->
        lucide(assign(assigns, :paths, paths))
    end
  end

  defp lucide(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={@size}
      height={@size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={["icon", @class]}
      aria-hidden="true"
      {@rest}
    ><path :for={d <- @paths} d={d} /></svg>
    """
  end

  defp brand(assigns) do
    # The brand SVGs are trusted files from priv/icons; only size and class
    # are replaced, both escaped.
    size =
      assigns.size |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    class =
      ["icon", assigns.class]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    svg =
      assigns.svg
      |> String.replace(~r/width="[^"]*"/, ~s(width="#{size}"), global: false)
      |> String.replace(~r/height="[^"]*"/, ~s(height="#{size}"), global: false)
      |> String.replace(~r/class="[^"]*"/, ~s(class="#{class}"), global: false)
      |> String.replace("<svg", ~s(<svg aria-hidden="true"), global: false)

    assigns = assign(assigns, :svg, Phoenix.HTML.raw(svg))

    ~H"""
    {@svg}
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition: {"fade-transition", "opacity-0", "opacity-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition: {"fade-transition", "opacity-100", "opacity-0"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(FeatherWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FeatherWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
