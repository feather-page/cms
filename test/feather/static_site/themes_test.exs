defmodule Feather.StaticSite.ThemesTest do
  use ExUnit.Case, async: true

  alias Feather.Sites.Site
  alias Feather.StaticSite.{Theme, Themes}
  alias Feather.StaticSite.Themes.{FeatherPage, SimpleSidebar}

  test "lists the themes a site can choose" do
    assert Themes.keys() == ["feather", "simple_sidebar"]
    assert Themes.options() == [{"feather.page", "feather"}, {"Simple sidebar", "simple_sidebar"}]
  end

  test "returns the module of a theme by key or by site" do
    assert Themes.module("feather") == FeatherPage
    assert Themes.module(%Site{}) == FeatherPage
    assert Themes.module(%Site{theme: "feather"}) == FeatherPage
    assert Themes.module("simple_sidebar") == SimpleSidebar
  end

  test "raises for unknown themes" do
    assert_raise ArgumentError, ~s(unknown theme "nope"), fn -> Themes.module("nope") end
  end

  test "every theme implements the theme contract and ships its fonts" do
    for key <- Themes.keys(), theme = Themes.module(key) do
      Code.ensure_loaded!(theme)

      for {name, arity} <- Theme.behaviour_info(:callbacks),
          do: assert(function_exported?(theme, name, arity), "#{key}: #{name}/#{arity}")

      assert theme.fonts() != %{}

      for name <- Map.keys(theme.fonts()),
          do: assert(File.regular?(theme.font_path(name)), "#{key}: #{name}")
    end
  end
end
