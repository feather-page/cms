defmodule Feather.Media.Drawing do
  @moduledoc """
  Draws the images the export generates (ADR 0028) with libvips (through
  Vix): an emoji as a favicon and share cards. Text is laid out by Pango;
  emoji come out in colour where Noto Color Emoji is installed (the Docker
  image has it), otherwise in whatever font fontconfig finds for them.

  Files appear complete or not at all, like image variants.
  """

  alias Vix.Vips.{Image, Operation}

  @type look :: %{
          background: String.t(),
          text: String.t(),
          muted: String.t(),
          accent: String.t(),
          font: String.t(),
          font_file: Path.t()
        }

  @type card :: %{
          title: String.t(),
          site_title: String.t() | nil,
          emoji: String.t() | nil,
          look: look()
        }

  @favicon_size 192
  @card_width 1200
  @card_height 630
  @margin 80
  @band 20
  @emoji_size 140
  @title_top 250
  @title_height 250
  @title_points 64
  @site_title_points 32
  @site_title_bottom @card_height - @band - 60
  @transparent [0.0, 0.0, 0.0, 0.0]

  @doc "Draws an emoji centred on a transparent 192×192 PNG."
  @spec favicon(String.t(), Path.t()) :: :ok | {:error, term()}
  def favicon(emoji, target) do
    with {:ok, glyph} <- emoji_image(emoji, @favicon_size),
         {:ok, icon} <- centre(glyph, @favicon_size, @favicon_size) do
      write_png(icon, target)
    end
  end

  @doc """
  Draws a 1200×630 PNG share card: the emoji and the title on the look's
  background, the site title (if any) below them and a band in the accent colour.
  A title too long for its box is set smaller.
  """
  @spec share_card(card(), Path.t()) :: :ok | {:error, term()}
  def share_card(%{look: look} = card, target) do
    with {:ok, background} <- solid(@card_width, @card_height, look.background),
         {:ok, band} <- solid(@card_width, @band, look.accent),
         {:ok, layers} <- card_layers(card),
         {:ok, image} <- composite(background, [{band, 0, @card_height - @band} | layers]) do
      write_png(image, target)
    end
  end

  defp card_layers(card) do
    with {:ok, emoji} <- optional_emoji(card.emoji),
         {:ok, title} <- title_image(card.title, card.look),
         {:ok, site_title} <- optional_site_title(card.site_title, card.look) do
      {:ok,
       Enum.reject(
         [
           emoji && {emoji, @margin, @margin},
           {title, @margin, @title_top},
           site_title && {site_title, @margin, @site_title_bottom - Image.height(site_title)}
         ],
         &is_nil/1
       )}
    end
  end

  defp optional_site_title(site_title, look) when is_binary(site_title) and site_title != "",
    do: text(site_title, look, look.muted, @site_title_points)

  defp optional_site_title(_site_title, _look), do: {:ok, nil}

  defp optional_emoji(emoji) when is_binary(emoji) and emoji != "",
    do: emoji_image(emoji, @emoji_size)

  defp optional_emoji(_emoji), do: {:ok, nil}

  defp title_image(title, look) do
    with {:ok, image} <- text(title, look, look.text, @title_points) do
      if Image.height(image) > @title_height,
        do: text(title, look, look.text, @title_points, height: @title_height, dpi: nil),
        else: {:ok, image}
    end
  end

  defp text(string, look, color, points, opts \\ []) do
    markup = ~s(<span foreground="#{color}">#{escape(string)}</span>)

    options =
      [
        font: "#{look.font} #{points}",
        fontfile: look.font_file,
        width: @card_width - 2 * @margin,
        wrap: :VIPS_TEXT_WRAP_WORD_CHAR,
        rgba: true,
        dpi: 72
      ]
      |> Keyword.merge(opts)
      |> Enum.reject(&match?({_key, nil}, &1))

    # A dpi turns off autofitting to the height.
    with {:ok, {image, _}} <- Operation.text(markup, options), do: {:ok, image}
  end

  defp emoji_image(emoji, size) do
    with {:ok, {glyph, _}} <- Operation.text(escape(emoji), font: "sans 160", rgba: true),
         do: Operation.thumbnail_image(glyph, size, height: size)
  end

  defp centre(image, width, height) do
    Operation.gravity(image, :VIPS_COMPASS_DIRECTION_CENTRE, width, height,
      extend: :VIPS_EXTEND_BACKGROUND,
      background: @transparent
    )
  end

  defp solid(width, height, hex) do
    with {:ok, black} <- Operation.black(width, height, bands: 3),
         {:ok, filled} <- Operation.linear(black, [1.0, 1.0, 1.0], rgb(hex)),
         {:ok, image} <- Operation.cast(filled, :VIPS_FORMAT_UCHAR),
         do: Operation.copy(image, interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  defp rgb("#" <> <<r::binary-2, g::binary-2, b::binary-2>>),
    do: Enum.map([r, g, b], &(&1 |> String.to_integer(16) |> Kernel./(1)))

  defp composite(background, layers) do
    layered =
      Enum.reduce_while(layers, {:ok, background}, fn {layer, x, y}, {:ok, image} ->
        case Operation.composite2(image, layer, :VIPS_BLEND_MODE_OVER, x: x, y: y) do
          {:ok, image} -> {:cont, {:ok, image}}
          error -> {:halt, error}
        end
      end)

    with {:ok, image} <- layered, do: Operation.extract_band(image, 0, n: 3)
  end

  defp write_png(image, target) do
    partial = "#{target}.#{System.unique_integer([:positive])}.part"

    try do
      with :ok <- Operation.pngsave(image, partial, keep: []), do: File.rename(partial, target)
    after
      File.rm(partial)
    end
  end

  defp escape(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
