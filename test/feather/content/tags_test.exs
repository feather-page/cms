defmodule Feather.Content.TagsTest do
  use ExUnit.Case, async: true

  alias Feather.Content.Tags

  test "normalize/1 lowercases, trims and removes duplicates" do
    assert Tags.normalize("Elixir, phoenix ,ELIXIR,, ") == "elixir, phoenix"
    assert Tags.normalize(" , ") == nil
    assert Tags.normalize(nil) == nil
  end

  test "tag_list/1 splits the stored string" do
    assert Tags.tag_list("a, b") == ["a", "b"]
    assert Tags.tag_list(%{tags: "a, b"}) == ["a", "b"]
    assert Tags.tag_list(%{tags: nil}) == []
  end

  test "from_list/1 joins and normalizes" do
    assert Tags.from_list(["A", "b", "a"]) == "a, b"
    assert Tags.from_list([]) == nil
  end
end
