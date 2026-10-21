defmodule FeatherWeb.FilterParametersTest do
  use ExUnit.Case, async: true

  test "logs no archive.org secret key" do
    assert %{"archive_org_keys" => %{"secret_key" => "[FILTERED]", "access_key" => "ak"}} =
             Phoenix.Logger.filter_values(%{
               "archive_org_keys" => %{"secret_key" => "sk", "access_key" => "ak"}
             })
  end
end
