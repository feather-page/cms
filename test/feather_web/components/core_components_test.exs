defmodule FeatherWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest
  import FeatherWeb.CoreComponents

  describe "icon/1" do
    test "renders Lucide icons as inline SVG" do
      html = render_component(&icon/1, name: "pencil")
      assert html =~ ~s(<svg)
      assert html =~ ~s(viewBox="0 0 24 24")
      assert html =~ ~s(stroke="currentColor")
      assert html =~ ~s(m15 5 4 4)
    end

    test "maps old Bootstrap names to Lucide" do
      assert render_component(&icon/1, name: "trash") ==
               render_component(&icon/1, name: "trash-2")

      assert render_component(&icon/1, name: "gear") ==
               render_component(&icon/1, name: "settings")
    end

    test "renders brand icons with size and class" do
      html = render_component(&icon/1, name: "github", size: 24, class: "text-primary")
      assert html =~ ~s(width="24")
      assert html =~ ~s(class="lucide text-primary")
      assert html =~ ~s(aria-hidden="true")
    end

    test "does not use felt-css's .icon class, which sizes plush icons to 2.25rem" do
      html = render_component(&icon/1, name: "pencil", size: 16)
      assert html =~ ~r/class="lucide\b/
      refute html =~ ~r/class="[^"]*\bicon\b/
    end

    test "falls back to a question mark" do
      assert render_component(&icon/1, name: "does-not-exist") ==
               render_component(&icon/1, name: "circle-help")
    end
  end

  describe "button/1" do
    test "uses Bootstrap classes" do
      html = render_component(&button/1, variant: "primary", inner_block: [])
      assert html =~ ~s(class="btn btn-primary")
    end

    test "is a neutral light button without a variant" do
      assert render_component(&button/1, inner_block: []) =~ ~s(class="btn btn-light")
    end

    test "has an outlined danger variant for destructive actions" do
      html = render_component(&button/1, variant: "danger-outline", inner_block: [])
      assert html =~ ~s(class="btn btn-outline-danger")
    end
  end

  describe "dropdown/1" do
    test "renders a closed menu with an accessible toggle" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown id="menu" label="Account">
          <:toggle>Open</:toggle>
          <li>Item</li>
        </.dropdown>
        """)

      assert html =~ ~s(id="menu-toggle")
      assert html =~ ~s(aria-expanded="false")
      assert html =~ ~s(aria-controls="menu-menu")
      assert html =~ ~s(aria-label="Account")
      assert html =~ ~s(class="btn dropdown-toggle btn-light btn-sm")
      assert html =~ ~r/class="dropdown-menu\s*"/
      assert html =~ "phx-click-away"
      assert html =~ ~s(phx-key="Escape")
    end

    test "aligns the menu to the end and hides the caret on request" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown id="menu" align="end" caret={false}>
          <:toggle>Open</:toggle>
          <li>Item</li>
        </.dropdown>
        """)

      assert html =~ ~s(class="dropdown-menu dropdown-menu-end")
      refute html =~ "dropdown-toggle"
    end
  end
end
