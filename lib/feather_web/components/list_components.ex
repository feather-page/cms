defmodule FeatherWeb.ListComponents do
  @moduledoc """
  The list every collection of the admin shares (posts, pages, projects,
  users, deployment targets, API tokens, social links): a card of rows,
  each with a leading tile, a title, a meta line and trailing actions.

      <.list_card id="posts" stream>
        <.list_row :for={{id, post} <- @streams.posts} id={id} navigate={edit_path(post)}>
          <:leading>{post.emoji}</:leading>
          {post.title}
          <:meta><.publication_badge status={Content.publication_status(post)} /></:meta>
          <:action
            id={"delete-post-\#{post.public_id}"}
            icon="trash"
            label="Delete"
            click={JS.push("delete", value: %{id: post.public_id})}
            confirm="Are you sure?"
            danger
          />
        </.list_row>
      </.list_card>

  With `navigate` the whole row links there. Actions are quiet icon
  buttons; below 768px a row with more than one action folds them into one
  menu.
  """
  use Phoenix.Component

  import FeatherWeb.CoreComponents, only: [icon: 1, status_badge: 1]

  alias Phoenix.LiveView.JS

  @doc """
  Renders the card that holds the rows. Pass `stream` when the rows come
  from a stream, and `hidden` to keep an empty stream container out of
  sight.
  """
  attr :id, :string, required: true
  attr :stream, :boolean, default: false
  attr :hidden, :boolean, default: false
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def list_card(assigns) do
    ~H"""
    <div class={["card list-card", @hidden && "d-none", @class]}>
      <ul id={@id} class="list-group list-group-flush" phx-update={@stream && "stream"}>
        {render_slot(@inner_block)}
      </ul>
    </div>
    """
  end

  @doc """
  Renders a row of a `list_card/1`. The inner block is the title; `excerpt`
  sets it in regular weight for rows that show text instead of a title.
  """
  attr :id, :string, required: true
  attr :navigate, :string, default: nil, doc: "where the whole row links to"
  attr :excerpt, :boolean, default: false

  slot :leading, doc: "the tile: an emoji, an icon or an image" do
    attr :class, :any
  end

  slot :inner_block, required: true
  slot :meta, doc: "the secondary line below the title"
  slot :trailing, doc: "content before the actions, always visible"

  slot :action do
    attr :id, :string, required: true
    attr :icon, :string, required: true
    attr :label, :string, required: true
    attr :click, JS, required: true
    attr :confirm, :string
    attr :danger, :boolean
    attr :hidden, :boolean, doc: "rendered disabled and invisible, keeping its place"
  end

  def list_row(assigns) do
    assigns =
      assigns
      |> assign(:menu?, length(assigns.action) > 1)
      |> assign(:menu_id, "#{assigns.id}-menu")

    ~H"""
    <li id={@id} class="list-group-item list-row">
      <div :for={leading <- @leading} class={["list-row__tile", leading[:class]]}>
        {render_slot(leading)}
      </div>
      <div class="list-row__body">
        <.link
          :if={@navigate}
          navigate={@navigate}
          class={["list-row__title stretched-link", @excerpt && "list-row__title--excerpt"]}
        >
          {render_slot(@inner_block)}
        </.link>
        <div :if={!@navigate} class={["list-row__title", @excerpt && "list-row__title--excerpt"]}>
          {render_slot(@inner_block)}
        </div>
        <div :if={@meta != []} class="list-row__meta">{render_slot(@meta)}</div>
      </div>
      <div :if={@trailing != [] or @action != []} class="list-row__actions">
        {render_slot(@trailing)}
        <button
          :for={action <- @action}
          type="button"
          id={action.id}
          class={[
            "btn btn-link list-row__action",
            action[:danger] && "list-row__action--danger",
            action[:hidden] && "invisible",
            @menu? && "d-none d-md-inline-flex"
          ]}
          title={action.label}
          aria-label={action.label}
          disabled={action[:hidden]}
          phx-click={action.click}
          data-confirm={action[:confirm]}
        >
          <.icon name={action.icon} size={18} />
        </button>
        <div :if={@menu?} class="dropdown d-md-none">
          <button
            type="button"
            id={"#{@menu_id}-toggle"}
            class="btn btn-link list-row__action"
            title="Actions"
            aria-label="Actions"
            aria-haspopup="menu"
            aria-expanded="false"
            aria-controls={@menu_id}
            phx-click={toggle_menu(@menu_id)}
          >
            <.icon name="ellipsis-vertical" size={20} />
          </button>
          <ul
            id={@menu_id}
            class="dropdown-menu dropdown-menu-end"
            role="menu"
            data-bs-popper
            phx-click-away={close_menu(@menu_id)}
            phx-window-keydown={close_menu(@menu_id)}
            phx-key="Escape"
          >
            <li :for={action <- @action} :if={!action[:hidden]} role="none">
              <button
                type="button"
                id={"#{action.id}-menu-item"}
                class={["dropdown-item list-row__menu-item", action[:danger] && "text-danger"]}
                role="menuitem"
                phx-click={action.click |> close_menu(@menu_id)}
                data-confirm={action[:confirm]}
              >
                <.icon name={action.icon} size={18} /> {action.label}
              </button>
            </li>
          </ul>
        </div>
      </div>
    </li>
    """
  end

  defp toggle_menu(id) do
    JS.toggle_class("show", to: "##{id}")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "##{id}-toggle")
  end

  defp close_menu(js \\ %JS{}, id) do
    js
    |> JS.remove_class("show", to: "##{id}")
    |> JS.set_attribute({"aria-expanded", "false"}, to: "##{id}-toggle")
  end

  @doc """
  Renders the badge of a post, page or project's
  `Feather.Content.publication_status/1`: Draft, Published or Unpublished
  changes.
  """
  attr :status, :atom, required: true, values: [:draft, :published, :unpublished_changes]
  attr :id, :string, default: nil

  def publication_badge(assigns) do
    ~H"""
    <%= case @status do %>
      <% :draft -> %>
        <.status_badge id={@id} kind={:draft}>Draft</.status_badge>
      <% :published -> %>
        <.status_badge id={@id} kind={:published}>Published</.status_badge>
      <% :unpublished_changes -> %>
        <.status_badge id={@id} kind={:changed}>Unpublished changes</.status_badge>
    <% end %>
    """
  end

  @doc "Renders a neutral badge, e.g. a project's status or a page type."
  slot :inner_block, required: true

  def neutral_badge(assigns) do
    ~H"""
    <.status_badge>{render_slot(@inner_block)}</.status_badge>
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
end
