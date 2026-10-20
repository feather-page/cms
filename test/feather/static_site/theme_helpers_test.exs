defmodule Feather.StaticSite.ThemeHelpersTest do
  use ExUnit.Case, async: true

  alias Feather.Media.Image
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Routes, ThemeHelpers}

  defp html(safe), do: Phoenix.HTML.safe_to_string(safe)

  test "pagination page numbers with gaps" do
    assert ThemeHelpers.pagination_page_numbers(1, 5) == [1, 2, 3, 4, 5]
    assert ThemeHelpers.pagination_page_numbers(1, 10) == [1, 2, 3, 4, :gap, 10]
    assert ThemeHelpers.pagination_page_numbers(5, 10) == [1, :gap, 4, 5, 6, :gap, 10]
    assert ThemeHelpers.pagination_page_numbers(9, 10) == [1, :gap, 7, 8, 9, 10]
  end

  describe "image_sources/4" do
    setup do
      %{
        routes: Routes.new(%Site{theme: "feather"}),
        image: %Image{public_id: "img000000001", width: 600, height: 900}
      }
    end

    test "src is the narrowest variant, srcset lists the variants narrowest first with sizes",
         %{routes: routes, image: image} do
      assert html(ThemeHelpers.image_sources(routes, image, [540, 180, 360], "120px")) ==
               ~s( src="/images/img000000001/180.webp") <>
                 ~s( srcset="/images/img000000001/180.webp 120w, /images/img000000001/360.webp 240w, ) <>
                 ~s(/images/img000000001/540.webp 360w" sizes="120px")
    end

    test "a single variant, or sizes the image is too small for, give only src",
         %{routes: routes, image: image} do
      assert html(ThemeHelpers.image_sources(routes, image, [128], "28px")) ==
               ~s( src="/images/img000000001/128.webp")

      assert html(ThemeHelpers.image_sources(routes, image, [960, 1280], "28px")) ==
               ~s( src="/images/img000000001/960.webp")
    end
  end

  test "contained_width/3 is the width object-fit: contain shows an image at in a box" do
    tall = %Image{width: 100, height: 300}
    wide = %Image{width: 300, height: 100}

    assert ThemeHelpers.contained_width(tall, 144, 136) == 45
    assert ThemeHelpers.contained_width(wide, 144, 136) == 144
    assert ThemeHelpers.contained_width(%Image{}, 144, 136) == 144
  end

  test "a rating is announced as a label instead of glyph by glyph, clamped to 0 to 5" do
    assert ThemeHelpers.rating_label(4) == "4 of 5 stars"
    assert ThemeHelpers.rating_label(9) == "5 of 5 stars"
    assert ThemeHelpers.rating_label(-2) == "0 of 5 stars"
  end

  describe "time_tag/2" do
    test "renders the long date by default, a DateTime as its date" do
      assert html(ThemeHelpers.time_tag(~D[2025-05-06])) ==
               ~s(<time datetime="2025-05-06">May 6, 2025</time>)

      assert html(ThemeHelpers.time_tag(~U[2025-05-06 23:00:00Z])) ==
               ~s(<time datetime="2025-05-06">May 6, 2025</time>)
    end

    test "escapes the text of a formatter and keeps safe markup as it is" do
      assert html(ThemeHelpers.time_tag(~D[2025-05-06], fn _date -> "<6 & 7>" end)) ==
               ~s(<time datetime="2025-05-06">&lt;6 &amp; 7&gt;</time>)

      assert html(ThemeHelpers.time_tag(~D[2025-05-06], fn _date -> {:safe, "6<i>.</i>"} end)) ==
               ~s(<time datetime="2025-05-06">6<i>.</i></time>)
    end

    test "renders nothing without a date" do
      assert ThemeHelpers.time_tag(nil) == {:safe, ""}
      assert ThemeHelpers.time_tag(nil, &ThemeHelpers.format_short_date/1) == {:safe, ""}
    end
  end

  describe "emoji_label/3" do
    test "puts the emoji in front, hidden from screen readers, in the given class" do
      assert html(ThemeHelpers.emoji_label("🚲", "Ride & <run>")) ==
               ~s(<span class="link-emoji" aria-hidden="true">🚲</span>Ride &amp; &lt;run&gt;)

      assert html(ThemeHelpers.emoji_label("🪶", "feather", "title-emoji")) ==
               ~s(<span class="title-emoji" aria-hidden="true">🪶</span>feather)
    end

    test "is the text alone without an emoji" do
      assert html(ThemeHelpers.emoji_label(nil, "Plain", "title-emoji")) == "Plain"
      assert html(ThemeHelpers.emoji_label(" ", "Plain")) == "Plain"
    end
  end
end
