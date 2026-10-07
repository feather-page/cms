defmodule FeatherWeb.EncryptionKeyTest do
  # A changed CONFIG_ENCRYPTION_KEY makes stored target credentials
  # unreadable; only editing and deploying a target may fail because of it.
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
      target = Publishing.get_staging_target(scope)
      change_key()
      %{target: target}
    end

    test "site pages and their preview link still work", %{conn: conn, site: site, target: target} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")
      assert has_element?(lv, ~s(#site-preview-link[href="/preview/#{target.public_id}"]))
    end

    test "the preview still works", %{conn: conn, target: target} do
      conn = get(conn, "/preview/#{target.public_id}/")
      assert html_response(conn, 200)
    end

    test "targets can be listed, loading one with its config fails", %{
      scope: scope,
      target: target
    } do
      assert [%{public_id: public_id}] = Publishing.list_targets(scope)
      assert public_id == target.public_id

      assert ExUnit.CaptureLog.capture_log(fn ->
               assert_raise ArgumentError, fn -> Publishing.get_target!(scope, public_id) end
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
