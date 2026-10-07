defmodule Feather.ReleaseTest do
  use Feather.DataCase

  import ExUnit.CaptureIO

  alias Feather.{Publishing, Release}

  describe "set_target_config/2" do
    test "replaces the config of a target" do
      scope = site_scope_fixture()
      target = deployment_target_fixture(scope, config: %{})
      config = %{"host" => "ftp.example.com", "user" => "u2", "password" => "new", "path" => "/"}

      output =
        capture_io(fn ->
          assert {:ok, _} = Release.set_target_config(target.public_id, config)
        end)

      assert output =~ "set"
      assert Publishing.get_target!(scope, target.public_id).config == config
    end

    test "reports an unknown target" do
      assert capture_io(:stderr, fn ->
               assert Release.set_target_config("unknown12345", %{}) == {:error, :not_found}
             end) =~ "No deployment target"
    end
  end
end
