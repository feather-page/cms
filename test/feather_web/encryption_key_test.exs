defmodule FeatherWeb.EncryptionKeyTest do
  # A changed CONFIG_ENCRYPTION_KEY may only break editing and deploying a target.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Encryption, Publishing}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp change_key do
    original = Application.get_env(:feather, :config_encryption_key)
    on_exit(fn -> Application.put_env(:feather, :config_encryption_key, original) end)

    Application.put_env(
      :feather,
      :config_encryption_key,
      Base.encode64(:crypto.strong_rand_bytes(32))
    )
  end

  describe "with a different key" do
    setup %{scope: scope} do
      target = deployment_target_fixture(scope)
      change_key()
      %{target: target}
    end

    test "site pages and their preview link still work", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")
      assert has_element?(lv, ~s(#site-preview-link-sidebar[href="/preview/#{site.public_id}"]))
    end

    test "the target loads without its config, deploying it fails", %{
      scope: scope,
      target: target
    } do
      assert %{id: id} = Publishing.get_target(scope)
      assert id == target.id

      assert ExUnit.CaptureLog.capture_log(fn ->
               assert_raise ArgumentError, fn -> Publishing.deploy_site(scope) end
             end) =~ "CONFIG_ENCRYPTION_KEY"
    end
  end

  describe "Encryption.validate_key!/0" do
    test "accepts 32 bytes encoded as base64" do
      assert Encryption.validate_key!() == :ok
    end

    test "raises for a missing or malformed key" do
      original = Application.get_env(:feather, :config_encryption_key)
      on_exit(fn -> Application.put_env(:feather, :config_encryption_key, original) end)

      for key <- [nil, "not base64!", Base.encode64("too short")] do
        Application.put_env(:feather, :config_encryption_key, key)

        assert_raise RuntimeError, ~r/CONFIG_ENCRYPTION_KEY/, fn ->
          Encryption.validate_key!()
        end
      end
    end
  end
end
