defmodule Feather.StaticSite.Hue do
  @moduledoc """
  The accent hue of a site's theme (an OKLCH hue angle, 0–359), taken from
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
end
