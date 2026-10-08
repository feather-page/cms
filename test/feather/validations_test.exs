defmodule Feather.ValidationsTest do
  use ExUnit.Case, async: true

  alias Feather.Validations

  describe "emoji?/1" do
    test "accepts emoji, including skin tones, ZWJ sequences and variation selectors" do
      for emoji <- ["🌐", "🪶", "👍🏽", "👩‍💻", "❤️", "🏳️‍🌈", "📘📗"] do
        assert Validations.emoji?(emoji), "expected #{emoji} to be an emoji"
      end
    end

    test "rejects text" do
      for text <- ["a", "hello", "🌐 site", " ", ""] do
        refute Validations.emoji?(text), "expected #{inspect(text)} not to be an emoji"
      end
    end
  end

  describe "validate_emoji/2" do
    defp changeset(emoji) do
      {%{}, %{emoji: :string}}
      |> Ecto.Changeset.cast(%{emoji: emoji}, [:emoji], empty_values: [])
      |> Validations.validate_emoji(:emoji)
    end

    test "allows blank values" do
      assert changeset("").valid?
      assert changeset(nil).valid?
    end

    test "rejects non-emoji" do
      refute changeset("x").valid?
      assert changeset("🌐").valid?
    end
  end
end
