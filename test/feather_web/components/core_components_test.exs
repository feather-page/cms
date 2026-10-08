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

  describe "header/1" do
    test "renders a back link, a truncated title and a badge" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.header back="/sites/abc/posts" back_label="Posts" truncate>
          A long title
          <:badge><span class="badge">Draft</span></:badge>
        </.header>
        """)

      assert text(html, ~s(a.page-header__back[href="/sites/abc/posts"])) =~ "Posts"
      assert text(html, "h1.page-header__title.text-truncate") =~ "A long title"
      assert text(html, ".page-header__title-row > .badge") == "Draft"
    end

    test "keeps plain headers without back link" do
      assigns = %{}
      html = rendered_to_string(~H"<.header>Posts</.header>")

      assert text(html, "h1.page-header__title") =~ "Posts"
      refute has?(html, ".page-header__back")
      refute has?(html, ".text-truncate")
    end
  end

  describe "input/1" do
    test "renders a checkbox as a switch" do
      html =
        render_component(&input/1, type: "checkbox", name: "draft", label: "Draft", switch: true)

      assert has?(html, ~s(.form-check.form-switch input[type="checkbox"][role="switch"]))
    end

    test "renders a prefix in an input group" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input name="title" value="" label="Title">
          <:prefix><input name="emoji" class="form-control emoji-input" /></:prefix>
        </.input>
        """)

      assert has?(html, ~s(.input-group > input[name="emoji"] + input[name="title"]))
    end

    test "renders labels as form-label" do
      html = render_component(&input/1, id: "title", name: "title", value: "", label: "Title")
      assert text(html, ~s(label.form-label[for="title"])) == "Title"
    end
  end

  test "action_bar/1 puts the destructive action on the right" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.action_bar sticky>
        <button>Save</button>
        <:danger><button>Delete</button></:danger>
      </.action_bar>
      """)

    assert has?(html, ".action-bar.action-bar--sticky")
    assert text(html, ".action-bar > .action-bar__danger > button") == "Delete"
  end

  defp has?(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.any?()

  defp text(html, selector),
    do:
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(selector)
      |> LazyHTML.text()
      |> String.trim()
end
