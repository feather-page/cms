defmodule FeatherWeb.ErrorJSONTest do
  use FeatherWeb.ConnCase

  test "renders 404" do
    assert FeatherWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert FeatherWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
