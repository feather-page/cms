defmodule FeatherWeb.ListComponentsTest do
  use ExUnit.Case, async: true

  import FeatherWeb.ListComponents, only: [initials: 1]

  test "initials takes the first letters of the local part's words" do
    assert initials("robert.curth@example.com") == "RC"
    assert initials("robert@example.com") == "R"
    assert initials("jane-doe-smith@example.com") == "JD"
    assert initials("élise@example.com") == "É"
    assert initials("__@example.com") == "?"
  end
end
