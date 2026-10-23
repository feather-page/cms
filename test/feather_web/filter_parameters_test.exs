defmodule FeatherWeb.FilterParametersTest do
  use ExUnit.Case, async: true

  test "logs no archive.org secret key" do
    assert %{"archive_org_keys" => %{"secret_key" => "[FILTERED]", "access_key" => "ak"}} =
             Phoenix.Logger.filter_values(%{
               "archive_org_keys" => %{"secret_key" => "sk", "access_key" => "ak"}
             })
  end

  test "logs no OAuth code, verifier or token" do
    assert Phoenix.Logger.filter_values(%{
             "code" => "c",
             "code_verifier" => "v",
             "refresh_token" => "r",
             "grant_type" => "authorization_code"
           }) == %{
             "code" => "[FILTERED]",
             "code_verifier" => "[FILTERED]",
             "refresh_token" => "[FILTERED]",
             "grant_type" => "authorization_code"
           }
  end
end
