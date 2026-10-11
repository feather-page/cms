defmodule FeatherWeb.ConfirmHelpersTest.Dropper do
  use FeatherWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id="dropper">
      <span id="dropped">{@dropped}</span>
      <.button id="drop" confirm="Drop it?" phx-click={JS.push("drop", target: @myself)}>
        Drop
      </.button>
    </div>
    """
  end

  def mount(socket), do: {:ok, assign(socket, :dropped, "no")}

  def handle_event("drop", _params, socket), do: {:noreply, assign(socket, :dropped, "yes")}
end

defmodule FeatherWeb.ConfirmHelpersTest.Page do
  use FeatherWeb, :live_view

  def render(assigns) do
    ~H"""
    <.confirm_dialog id="confirm-delete" />
    <.live_component module={FeatherWeb.ConfirmHelpersTest.Dropper} id="dropper" />
    <button
      id="hasty"
      phx-click={
        JS.push("drop")
        |> Setzkasten.Components.Overlays.show_confirm("confirm-delete", "Drop it?", JS.push("drop"))
      }
    >
      Drop now
    </button>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end

defmodule FeatherWeb.ConfirmHelpersTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  test "confirm_click sends the parked push to its target", %{conn: conn} do
    {:ok, lv, _html} = live_isolated(conn, __MODULE__.Page)

    confirm_click(lv, "#drop", "Drop it?")

    assert has_element?(lv, "#dropped", "yes")
  end

  test "asked fails for a trigger that pushes its event itself", %{conn: conn} do
    {:ok, lv, _html} = live_isolated(conn, __MODULE__.Page)

    assert_raise ExUnit.AssertionError, ~r/pushes an event itself/, fn -> asked(lv, "#hasty") end
  end
end
