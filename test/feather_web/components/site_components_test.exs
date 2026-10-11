defmodule FeatherWeb.SiteComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import FeatherWeb.SiteComponents

  alias Feather.Pagination

  defp render_pagination(page, total_pages) do
    render_component(&pagination/1,
      pagination: %Pagination{
        page: page,
        total_pages: total_pages,
        total_entries: total_pages * 20
      },
      path: &"/posts?page=#{&1}"
    )
  end

  defp page_links(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("a[data-page]")
    |> Enum.map(&(&1 |> LazyHTML.attribute("data-page") |> hd() |> String.to_integer()))
  end

  describe "delete_text/2" do
    test "says that a published record stays live until the next deploy" do
      assert delete_text("post", %{published_version_id: "v1"}) ==
               "Removes the post from Feather. It stays on the live site until the next deploy."

      assert delete_text("post", %{published_version_id: nil}) == nil
    end
  end

  describe "time_ago/1" do
    test "counts minutes, hours and days" do
      ago = fn minutes -> time_ago(DateTime.add(DateTime.utc_now(), -minutes, :minute)) end

      assert ago.(0) == "just now"
      assert ago.(1) == "1 min ago"
      assert ago.(61) == "1 h ago"
      assert ago.(60 * 25) == "1 day ago"
      assert ago.(60 * 24 * 3) == "3 days ago"
      assert time_ago(nil) == "not deployed yet"
    end
  end

  describe "pagination/1" do
    test "renders nothing for a single page" do
      assert render_pagination(1, 1) == ""
    end

    test "links every page when there are only a few" do
      assert page_links(render_pagination(2, 5)) == [1, 2, 3, 4, 5]
    end

    test "with many pages links the first, the last and the neighbours of the current one" do
      html = render_pagination(12, 23)

      assert page_links(html) == [1, 11, 12, 13, 23]
      assert html |> LazyHTML.from_fragment() |> LazyHTML.query("[data-gap]") |> Enum.count() == 2
    end

    test "joins the first pages without a gap" do
      html = render_pagination(2, 23)

      assert page_links(html) == [1, 2, 3, 23]
      assert html |> LazyHTML.from_fragment() |> LazyHTML.query("[data-gap]") |> Enum.count() == 1
    end

    test "on phones shows the position instead of the page numbers" do
      html = render_pagination(12, 23)

      assert html =~ "Page 12 of 23"

      for link <- html |> LazyHTML.from_fragment() |> LazyHTML.query("a[data-page]") do
        assert link |> LazyHTML.attribute("class") |> hd() =~ "max-sm:hidden"
      end
    end

    test "names Previous and Next for screen readers on phones" do
      html = render_pagination(12, 23)

      assert html =~ ~s(href="/posts?page=11")
      assert html =~ ~s(href="/posts?page=13")
      assert html =~ "Previous"
      assert html =~ "Next"
    end
  end

  describe "rating/1" do
    test "shows the stars to the eye and the rating in words to screen readers" do
      html = render_component(&rating/1, value: 4)

      assert html =~ ~s(aria-hidden="true">★★★★☆</span>)
      assert html =~ ~s(<span class="sr-only">Rated 4 out of 5</span>)
    end

    test "renders nothing without a rating" do
      assert render_component(&rating/1, value: nil) == ""
    end
  end
end
