defmodule Feather.StaticSite.ThemeHelpersTest do
  use ExUnit.Case, async: true

  alias Feather.StaticSite.ThemeHelpers

  test "pagination page numbers with gaps" do
    assert ThemeHelpers.pagination_page_numbers(1, 5) == [1, 2, 3, 4, 5]
    assert ThemeHelpers.pagination_page_numbers(1, 10) == [1, 2, 3, 4, :gap, 10]
    assert ThemeHelpers.pagination_page_numbers(5, 10) == [1, :gap, 4, 5, 6, :gap, 10]
    assert ThemeHelpers.pagination_page_numbers(9, 10) == [1, :gap, 7, 8, 9, 10]
  end

  test "a rating is announced as a label instead of glyph by glyph, clamped to 0 to 5" do
    assert ThemeHelpers.rating_label(4) == "4 of 5 stars"
    assert ThemeHelpers.rating_label(9) == "5 of 5 stars"
    assert ThemeHelpers.rating_label(-2) == "0 of 5 stars"
  end
end
