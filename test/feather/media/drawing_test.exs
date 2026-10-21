defmodule Feather.Media.DrawingTest do
  use ExUnit.Case, async: true

  alias Feather.Media.Drawing
  alias Vix.Vips.Image, as: VipsImage

  @look %{
    background: "#fffcf7",
    text: "#3a322c",
    muted: "#6c6258",
    accent: "#d9a46b",
    font: "Nunito ExtraBold",
    font_file:
      Path.expand(
        "../../../priv/static_site/themes/feather_page/fonts/nunito-latin-800.woff2",
        __DIR__
      )
  }

  setup do
    dir = Path.join(System.tmp_dir!(), "drawing-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp png_size(path) do
    {:ok, image} = VipsImage.new_from_file(path)
    assert {:ok, "pngload"} = VipsImage.header_value(image, "vips-loader")
    {VipsImage.width(image), VipsImage.height(image), VipsImage.bands(image)}
  end

  test "a favicon is the emoji on a transparent square", %{dir: dir} do
    target = Path.join(dir, "icon.png")

    assert Drawing.favicon("🦊", target) == :ok
    assert png_size(target) == {192, 192, 4}
  end

  test "a share card fits any title into 1200×630", %{dir: dir} do
    for {title, emoji} <- [{"Hi", "🦊"}, {String.duplicate("A <long> & winding title ", 20), nil}] do
      target = Path.join(dir, "card.png")
      card = %{title: title, site_title: "Site & Co", emoji: emoji, look: @look}

      assert Drawing.share_card(card, target) == :ok
      assert png_size(target) == {1200, 630, 3}
    end
  end

  test "nothing is left behind when drawing fails", %{dir: dir} do
    target = Path.join([dir, "missing", "icon.png"])

    assert {:error, _reason} = Drawing.favicon("🦊", target)
    refute File.exists?(target)
  end
end
