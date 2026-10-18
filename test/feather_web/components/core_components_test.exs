defmodule FeatherWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest
  import FeatherWeb.CoreComponents
  import Setzkasten.Components.Icons, only: [icon: 1]

  alias Feather.Sites.SocialMediaService

  describe "icons" do
    test "the app's Lucide icons render through setzkasten's icon/1" do
      html = render_component(&icon/1, name: "list-plus")
      assert html =~ ~s(viewBox="0 0 24 24")
      assert html =~ ~s(stroke="currentColor")
      assert html =~ ~s(M18 9v6)
      assert html =~ ~r/class="lucide size-4"/
    end

    test "every icon name used in the admin exists" do
      names =
        Path.wildcard("lib/feather_web/**/*.ex")
        |> Enum.flat_map(
          &Regex.scan(~r/(?:<\.icon\s[^>]*?\bname|\bicon)="([a-z0-9-]+)"/s, File.read!(&1))
        )
        |> Enum.map(fn [_, name] -> name end)
        |> Enum.uniq()
        |> Kernel.--(Enum.map(SocialMediaService.all(), & &1.icon))

      assert "trash-2" in names

      for name <- names do
        assert render_component(&icon/1, name: name) =~ "<svg", name
      end
    end

    test "an unknown icon raises instead of rendering nothing" do
      assert_raise ArgumentError, fn -> render_component(&icon/1, name: "does-not-exist") end
    end
  end

  describe "brand_icon/1" do
    test "renders the brand SVG in currentColor, hidden from screen readers" do
      html = render_component(&brand_icon/1, name: "github")
      assert html =~ ~s(<svg class="brand-icon size-4" aria-hidden="true")
      assert html =~ ~s(fill="currentColor")
      refute html =~ ~s(width=")
      refute html =~ "bi-github"
    end

    test "a size class replaces the default size" do
      html = render_component(&brand_icon/1, name: "mastodon", class: "size-5")
      assert html =~ ~s(class="brand-icon size-5")
    end
  end

  describe "tile/1" do
    test "shows an image, else the emoji, else the icon" do
      assigns = %{}

      assert has?(
               rendered_to_string(~H|<.tile image="/x.webp" emoji="🌻" icon="file-text" />|),
               "img"
             )

      html = rendered_to_string(~H|<.tile emoji="🌻" icon="file-text" />|)
      assert text(html, "span > span") == "🌻"
      refute has?(html, "svg")

      assert has?(rendered_to_string(~H|<.tile icon="file-text" />|), "svg.lucide")
    end
  end

  describe "publication_badge/1" do
    test "is a neutral badge with a coloured dot" do
      published = render_component(&publication_badge/1, status: :published, id: "b")
      assert has?(published, "span#b.badge .status.status-success")
      assert text(published, ".badge") == "Published"

      assert has?(
               render_component(&publication_badge/1, status: :draft),
               ".status:not([class*=status-])"
             )

      not_live = render_component(&publication_badge/1, status: :published, live: false)
      assert has?(not_live, ".status.status-warning")
      assert text(not_live, ".badge") == "Published · not live yet"

      changed = render_component(&publication_badge/1, status: :unpublished_changes)
      assert has?(changed, ".status.status-info")
      assert text(changed, ".badge") == "Changes not published"
    end
  end

  test "initials takes the first letters of the local part's words" do
    assert initials("robert.curth@example.com") == "RC"
    assert initials("robert@example.com") == "R"
    assert initials("jane-doe-smith@example.com") == "JD"
    assert initials("élise@example.com") == "É"
    assert initials("__@example.com") == "?"
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
