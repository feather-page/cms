defmodule Feather.ReleaseTest do
  use Feather.DataCase

  import ExUnit.CaptureIO

  alias Feather.Release

  describe "set_target_config/2" do
    test "replaces the config of the target of the site with the domain" do
      scope = site_scope_fixture()
      target = deployment_target_fixture(scope, config: %{})
      config = %{"host" => "ftp.example.com", "user" => "u2", "password" => "new", "path" => "/"}

      output =
        capture_io(fn ->
          domain = "https://" <> String.upcase(scope.site.domain)
          assert {:ok, _} = Release.set_target_config(domain, config)
        end)

      assert output =~ "Config of #{scope.site.domain} (ftps) set."
      assert Repo.reload!(target).config == config
    end

    test "reports a domain without a target" do
      scope = site_scope_fixture()

      for domain <- ["unknown.example.com", scope.site.domain] do
        assert capture_io(:stderr, fn ->
                 assert Release.set_target_config(domain, %{}) == {:error, :not_found}
               end) =~ "No deployment target for #{domain}."
      end
    end
  end
end
