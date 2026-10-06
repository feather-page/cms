defmodule FeatherWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

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
      assert html =~ ~s(class="icon text-primary")
      assert html =~ ~s(aria-hidden="true")
    end

    test "falls back to a question mark" do
      assert render_component(&icon/1, name: "does-not-exist") ==
               render_component(&icon/1, name: "circle-help")
    end
  end

  test "button/1 uses Bootstrap classes" do
    html = render_component(&button/1, variant: "primary", inner_block: [])
    assert html =~ ~s(class="btn btn-primary")
  end
end
