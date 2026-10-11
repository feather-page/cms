defmodule FeatherWeb.CoreComponents do
  @moduledoc """
  The admin's own UI components, next to the shared ones of
  [setzkasten](https://github.com/shostakovich/setzkasten) (`<.button>`,
  `<.input>`, `<.header>`, `<.list>`/`<.list_row>`, `<.badge>`,
  `<.empty_state>`, `<.action_bar>`, `<.dropdown>`, `<.icon>`, ...), which
  `use FeatherWeb, :html` imports with `use Setzkasten`.

  Styling is Tailwind CSS with daisyUI and the setzkasten theme; see
  `assets/css/app.css` for the few app-specific styles.
  """
  use Phoenix.Component
  use Gettext, backend: FeatherWeb.Gettext

  import Setzkasten.Components.Icons, only: [icon: 1]
  import Setzkasten.Components.Feedback, only: [badge: 1]

  @doc """
  Renders a social media brand icon (`priv/icons`, see
  `Feather.Sites.SocialMediaService`) as inline SVG in `currentColor`,
  16px by default; a `size-*` class replaces the size.

  ## Examples

      <.brand_icon name="github" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil

  def brand_icon(assigns) do
    svg = Feather.Sites.SocialMediaService.svg(assigns.name) || raise_unknown(assigns.name)

    # The brand SVGs are trusted files from priv/icons; only the class is
    # replaced (escaped) and the icon hidden from screen readers.
    class =
      ["brand-icon", size_class(assigns.class), assigns.class]
      |> List.flatten()
      |> Enum.reject(&(&1 in [nil, false]))
      |> Enum.join(" ")
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    svg =
      svg
      |> String.replace(~r/\s(width|height)="[^"]*"/, "")
      |> String.replace(~r/\sclass="[^"]*"/, "")
      |> String.replace("<svg", ~s(<svg class="#{class}" aria-hidden="true"), global: false)

    assigns = assign(assigns, :svg, Phoenix.HTML.raw(svg))

    ~H"""
    {@svg}
    """
  end

  defp size_class(nil), do: "size-4"
  defp size_class(class) when is_binary(class), do: !String.contains?(class, "size-") && "size-4"

  defp size_class(class) when is_list(class),
    do: !Enum.any?(class, &(is_binary(&1) and String.contains?(&1, "size-"))) && "size-4"

  defp raise_unknown(name), do: raise(ArgumentError, "unknown brand icon #{inspect(name)}")

  @doc """
  Renders the leading tile of a list row: an emoji, an image or a Lucide
  icon on a quiet square.

  ## Examples

      <.tile emoji={post.emoji} />
      <.tile image={image_path(site, post.thumbnail_image, "mobile_x1.webp")} />
      <.tile icon="file-text" />
  """
  attr :emoji, :string, default: nil
  attr :image, :string, default: nil
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, doc: "other content, e.g. a brand icon"

  def tile(assigns) do
    ~H"""
    <span class={[
      "grid size-10 shrink-0 place-items-center overflow-hidden rounded-field bg-base-200 text-xl",
      @class
    ]}>
      <img :if={@image} src={@image} alt="" class="size-full object-cover" />
      <span :if={!@image && @emoji} aria-hidden="true">{@emoji}</span>
      <.icon
        :if={!@image && !@emoji && @icon}
        name={@icon}
        class="size-5 text-base-content/70"
      />
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders the badge of a post, page or project's
  `Feather.Content.publication_status/1`: Draft, Published (`Published ·
  not live yet` while `live` is false, see
  `Feather.Publishing.live?/3`) or Changes not published.
  `style` as in setzkasten's badge (`:text` in a meta line).
  """
  attr :status, :atom, required: true, values: [:draft, :published, :unpublished_changes]
  attr :live, :boolean, default: true, doc: "whether the published version is deployed"
  attr :id, :string, default: nil
  attr :style, :atom, default: :dot

  def publication_badge(assigns) do
    ~H"""
    <%= case {@status, @live} do %>
      <% {:draft, _live} -> %>
        <.badge id={@id} style={@style}>Draft</.badge>
      <% {:published, true} -> %>
        <.badge id={@id} tone={:success} style={@style}>Published</.badge>
      <% {:published, false} -> %>
        <.badge id={@id} tone={:warning} style={@style}>Published · not live yet</.badge>
      <% {:unpublished_changes, _live} -> %>
        <.badge id={@id} tone={:info} style={@style}>Changes not published</.badge>
    <% end %>
    """
  end

  @doc "The initials of an email address for an avatar, e.g. `RC` for robert.curth@…"
  @spec initials(String.t()) :: String.t()
  def initials(email) do
    email
    |> String.split("@")
    |> hd()
    |> String.split(~r/[^[:alnum:]]+/u, trim: true)
    |> case do
      [] -> "?"
      [word] -> String.first(word)
      [first, second | _] -> String.first(first) <> String.first(second)
    end
    |> String.upcase()
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
end
