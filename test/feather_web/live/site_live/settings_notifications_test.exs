defmodule FeatherWeb.SiteLive.SettingsNotificationsTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Accounts.Scope
  alias Feather.Sites

  setup [:register_and_log_in_user, :create_site_for_user]

  defp site_scope(scope, site), do: Scope.put_site(scope, site)

  test "explains IndexNow and offers to enter archive.org keys", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

    assert has_element?(lv, "#notifications-hint", "IndexNow")
    assert has_element?(lv, "#archive-org-form input#archive_org_keys_access_key")

    assert has_element?(
             lv,
             ~s(#archive-org-form input#archive_org_keys_secret_key[type="password"])
           )

    refute has_element?(lv, "#archive-org-keys-saved")
  end

  test "saves the keys without showing them again", %{conn: conn, site: site, scope: scope} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

    html =
      lv
      |> form("#archive-org-form",
        archive_org_keys: %{access_key: "access-1234", secret_key: "secret-5678"}
      )
      |> render_submit()

    assert html =~ "The archive.org keys were saved."
    assert has_element?(lv, "#archive-org-keys-saved")
    refute has_element?(lv, "#archive-org-form")
    refute html =~ "secret-5678"

    assert Sites.archive_org_keys(site_scope(scope, site)) ==
             %{access_key: "access-1234", secret_key: "secret-5678"}
  end

  test "shows what is missing", %{conn: conn, site: site, scope: scope} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

    lv
    |> form("#archive-org-form", archive_org_keys: %{access_key: "ak", secret_key: ""})
    |> render_submit()

    assert has_element?(lv, "#archive_org_keys_secret_key-error-0")
    assert Sites.archive_org_keys(site_scope(scope, site)) == nil
  end

  test "does not show a typed secret key again after a failed save", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

    html =
      lv
      |> form("#archive-org-form", archive_org_keys: %{access_key: "", secret_key: "secret-5678"})
      |> render_submit()

    assert has_element?(lv, "#archive_org_keys_access_key-error-0")
    refute html =~ "secret-5678"
  end

  test "removes the keys", %{conn: conn, site: site, scope: scope} do
    :ok =
      Sites.put_archive_org_keys(site_scope(scope, site), %{access_key: "ak", secret_key: "sk"})

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

    html = confirm_click(lv, "#remove-archive-org-keys-menu-item", "Remove the archive.org keys?")

    assert html =~ "The archive.org keys were removed."
    assert has_element?(lv, "#archive-org-form")
    assert Sites.archive_org_keys(site_scope(scope, site)) == nil
  end
end
