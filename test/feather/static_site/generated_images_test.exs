defmodule Feather.StaticSite.GeneratedImagesTest do
  use ExUnit.Case, async: true

  alias Feather.Sites.Site
  alias Feather.StaticSite.GeneratedImages

  @site %Site{title: "Site", emoji: " 🦊 ", theme: "feather"}

  test "a site's favicon is its emoji, none without one" do
    assert GeneratedImages.favicon(@site) == {:favicon, "🦊"}
    assert GeneratedImages.favicon(%{@site | emoji: " "}) == nil
    assert GeneratedImages.favicon(%{@site | emoji: nil}) == nil
  end

  test "a share card names the site unless its title is the site's" do
    assert {:share_card, %{title: "Post", site_title: "Site", emoji: "📷"}} =
             GeneratedImages.share_card(@site, "Post", "📷")

    assert {:share_card, %{site_title: nil, emoji: nil}} =
             GeneratedImages.share_card(@site, "Site", "")
  end

  test "file names follow what an image shows, not where the font is installed" do
    card = GeneratedImages.share_card(@site, "Post", nil)
    {:share_card, fields} = card
    moved = {:share_card, update_in(fields.look.font_file, &("/elsewhere/" <> Path.basename(&1)))}

    assert GeneratedImages.file_name?(GeneratedImages.file_name(card))
    assert GeneratedImages.file_name(card) == GeneratedImages.file_name(moved)

    refute GeneratedImages.file_name(card) ==
             GeneratedImages.file_name(GeneratedImages.share_card(@site, "Other", nil))

    refute GeneratedImages.file_name(card) ==
             GeneratedImages.file_name(
               GeneratedImages.share_card(%{@site | theme: "simple_sidebar"}, "Post", nil)
             )
  end

  test "paths are only given for file names it makes" do
    assert_raise ArgumentError, fn -> GeneratedImages.path("../feather.db") end
  end
end
