defmodule Feather.StaticSite.Themes.FeatherPage.HueTest do
  use ExUnit.Case, async: true

  alias Feather.StaticSite.Themes.FeatherPage.Hue

  test "known emoji have a curated hue" do
    assert Hue.for_emoji("🐭") == 350
    assert Hue.for_emoji("👨‍💻") == 265
  end

  test "skin tones and variation selectors do not change the hue" do
    assert Hue.for_emoji("👨🏻‍💻") == 265
    assert Hue.for_emoji("👨🏿‍💻") == 265
    assert Hue.for_emoji("❤️") == Hue.for_emoji("❤")
    assert Hue.for_emoji(" 🐭 ") == 350
  end

  test "other emoji get a stable hue from their hash" do
    hue = Hue.for_emoji("🦩")

    assert hue in 0..359
    assert Hue.for_emoji("🦩") == hue
    assert Hue.for_emoji("🦩🏽") == hue
  end

  test "a site without emoji gets the neutral default" do
    assert Hue.for_emoji(nil) == Hue.default()
    assert Hue.for_emoji("") == Hue.default()
    assert Hue.for_emoji("  ") == Hue.default()
  end
end
