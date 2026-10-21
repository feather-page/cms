defmodule Feather.StaticSite.Themes.FeatherPage.Hue do
  @moduledoc """
  The accent hue of the feather theme (an OKLCH hue angle, 0–359), taken from
  the site's emoji: a curated hue for common emoji, otherwise a stable hash
  of the emoji, and a warm neutral for a site without one. Skin tones and
  variation selectors are ignored, so 👨🏻‍💻 and 👨🏿‍💻 share a hue.

  The layout exposes it as the CSS custom property `--h`.
  """

  @default 60

  @modifiers ["\u{FE0E}", "\u{FE0F}" | Enum.map(0x1F3FB..0x1F3FF, &<<&1::utf8>>)]

  @hues %{
    350 => ~w(🐭 🐁 🐷 🐙 🌸 🌷 🎀 💗 💖 🩷),
    20 => ~w(❤ 🍎 🍓 🌹 🐞 🍒 🍉 🚒 🎈),
    35 => ~w(🔥 🦀 🍷 🎸),
    50 => ~w(🦊 🍊 🧡 🍕 🎃 🐯 🐻 🏠 📚 📖 📙),
    60 => ~w(🐱 🐈 🐶 🐕 🦉 ☕ 🥐 🍞 ⛰ 👋),
    90 => ~w(☀ 🌻 🌼 ⭐ 🌟 💡 ✏ 🐝 🍋 💛 ⚡ 😀 🙂 😊),
    145 => ~w(🐸 🐢 🌱 🌿 🍀 🌳 🌲 🌵 🥑 💚 🚲 🍵 🦖 🐍),
    175 => ~w(🧪 🌴 🦚),
    225 => ~w(🌍 🌎 🌏 🌊 💧 🐳 🐋 🐬 🐟 🐦 ❄ ⛵ 🏔 ✈),
    250 => ~w(💙 🤖 🔧 🛠 ⚙ 📷 📸 📝 🖥 ⌨ 🐧 🚀),
    265 => ~w(👨‍💻 👩‍💻 🧑‍💻 💻 🌙 🦋 🎧),
    300 => ~w(💜 🦄 🔮 🍇 🌈 🎨 🎵 🎶 🪻 🍆)
  }
  @lookup for {hue, emoji} <- @hues,
              e <- emoji,
              into: %{},
              do: {String.replace(e, @modifiers, ""), hue}

  @doc "The hue of a site without emoji."
  @spec default() :: non_neg_integer()
  def default, do: @default

  @doc "The accent hue for an emoji."
  @spec for_emoji(String.t() | nil) :: non_neg_integer()
  def for_emoji(nil), do: @default

  def for_emoji(emoji) when is_binary(emoji) do
    case emoji |> String.replace(@modifiers, "") |> String.trim() do
      "" -> @default
      key -> Map.get_lazy(@lookup, key, fn -> :erlang.phash2(key, 360) end)
    end
  end

  @doc """
  The sRGB hex colour (`"#rrggbb"`) of an OKLCH colour, clipped to the sRGB
  gamut, for images that cannot use CSS: lightness 0–1, chroma, hue in degrees.
  """
  @spec oklch_hex(number(), number(), number()) :: String.t()
  def oklch_hex(lightness, chroma, hue) do
    radians = hue * :math.pi() / 180

    lightness
    |> oklab_to_lms(chroma * :math.cos(radians), chroma * :math.sin(radians))
    |> lms_to_linear_srgb()
    |> Enum.map_join(&hex_channel/1)
    |> then(&("#" <> &1))
  end

  defp oklab_to_lms(lightness, a, b) do
    {
      :math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3),
      :math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3),
      :math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
    }
  end

  defp lms_to_linear_srgb({l, m, s}) do
    [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    ]
  end

  defp hex_channel(linear) do
    linear = linear |> max(0.0) |> min(1.0)

    encoded =
      if linear <= 0.0031308, do: 12.92 * linear, else: 1.055 * :math.pow(linear, 1 / 2.4) - 0.055

    (encoded * 255)
    |> round()
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.downcase()
  end
end
