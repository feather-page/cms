defmodule FeatherWeb.SiteLive.SettingsFediverseTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Accounts.Scope
  alias Feather.{Fediverse, Repo}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp settings(conn, site), do: live(conn, ~p"/sites/#{site.public_id}/settings")

  test "asks for the fediverse name as part of the handle on the site's domain",
       %{conn: conn, site: site} do
    {:ok, lv, _html} = settings(conn, site)

    assert has_element?(lv, "#fediverse-form input#site_fediverse_name")
    assert has_element?(lv, "#fediverse-form", "@#{site.domain}")
    refute has_element?(lv, "#fediverse-account")
  end

  test "saves the name and shows the account's address, not online before the next deploy",
       %{conn: conn, site: site} do
    {:ok, lv, _html} = settings(conn, site)

    html =
      lv
      |> form("#fediverse-form", site: %{fediverse_name: "Timon"})
      |> render_submit()

    assert html =~ "The fediverse name was saved."
    assert has_element?(lv, "#fediverse-account", "@timon@#{site.domain}")
    assert has_element?(lv, "#fediverse-account", "https://#{site.domain}/activitypub/timon")
    assert has_element?(lv, "#fediverse-status", "Online with the next deploy")
    assert has_element?(lv, "#fediverse-form")
    assert Repo.reload!(site).fediverse_name == "timon"
  end

  test "shows why a name is refused", %{conn: conn, site: site} do
    {:ok, lv, _html} = settings(conn, site)

    lv
    |> form("#fediverse-form", site: %{fediverse_name: "ti mon"})
    |> render_submit()

    assert has_element?(lv, "#site_fediverse_name-error-0")
    assert Repo.reload!(site).fediverse_name == nil
  end

  test "fixes the name once a deploy put the account online",
       %{conn: conn, site: site, scope: scope} do
    {:ok, site} =
      Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "timon"})

    :ok = Fediverse.record_online(site, DateTime.utc_now())

    {:ok, lv, _html} = settings(conn, site)

    refute has_element?(lv, "#fediverse-form")
    assert has_element?(lv, "#fediverse-account", "@timon@#{site.domain}")
    assert has_element?(lv, "#fediverse-status", "Online")
  end

  test "warns before a new domain is saved, which starts the account over",
       %{conn: conn, site: site, scope: scope} do
    {:ok, site} =
      Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "timon"})

    :ok = Fediverse.record_online(site, DateTime.utc_now())
    follower_fixture(site)

    {:ok, lv, _html} = settings(conn, site)
    refute has_element?(lv, "#domain-change-warning")

    lv |> form("#site-form", site: %{domain: "pumbaa.blog"}) |> render_change()
    assert has_element?(lv, "#domain-change-warning", "@timon@pumbaa.blog")
    assert has_element?(lv, "#domain-change-warning", "@timon@#{site.domain} loses its followers")

    lv |> form("#site-form", site: %{domain: site.domain}) |> render_change()
    refute has_element?(lv, "#domain-change-warning")

    lv |> form("#site-form", site: %{domain: "pumbaa.blog"}) |> render_submit()

    refute has_element?(lv, "#domain-change-warning")
    assert has_element?(lv, "#fediverse-account", "@timon@pumbaa.blog")
    assert has_element?(lv, "#fediverse-status", "Online with the next deploy")
    assert has_element?(lv, "#fediverse-followers", "No followers yet")
  end

  test "a new domain of a site without a fediverse name brings no warning",
       %{conn: conn, site: site} do
    {:ok, lv, _html} = settings(conn, site)

    lv |> form("#site-form", site: %{domain: "pumbaa.blog"}) |> render_change()

    refute has_element?(lv, "#domain-change-warning")
  end

  test "rotates the signing key, which stays pending until the next deploy",
       %{conn: conn, site: site, scope: scope} do
    {:ok, site} =
      Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "timon"})

    :ok = Fediverse.record_online(site, DateTime.utc_now())

    {:ok, lv, _html} = settings(conn, site)
    refute has_element?(lv, "#fediverse-key-status")

    html = confirm_click(lv, "#rotate-key-menu-item", "Rotate the account's key?")

    assert html =~ "The new key goes online with the next deploy."
    assert has_element?(lv, "#fediverse-key-status", "New key with the next deploy")
    refute has_element?(lv, "#rotate-key-menu-item")
    assert Fediverse.key_pending?(Repo.reload!(site))

    :ok = Fediverse.record_online(Repo.reload!(site), DateTime.utc_now())

    {:ok, lv, _html} = settings(conn, site)
    refute has_element?(lv, "#fediverse-key-status")
    assert has_element?(lv, "#rotate-key-menu-item")
  end

  test "shows the number of followers", %{conn: conn, site: site, scope: scope} do
    {:ok, site} =
      Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "timon"})

    {:ok, lv, _html} = settings(conn, site)
    assert has_element?(lv, "#fediverse-followers", "No followers yet")

    for _n <- 1..2, do: follower_fixture(site)

    {:ok, lv, _html} = settings(conn, site)
    assert has_element?(lv, "#fediverse-followers", "2 followers")
  end

  test "lists the blocked accounts and servers and unblocks them",
       %{conn: conn, site: site, scope: scope} do
    {:ok, lv, _html} = settings(conn, site)
    refute has_element?(lv, "#fediverse-blocks")

    {:ok, site} =
      Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "timon"})

    {:ok, lv, _html} = settings(conn, site)
    assert has_element?(lv, "#no-blocks")

    scope = Scope.put_site(scope, site)
    ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
    {:ok, account} = Fediverse.block(scope, ana, :account)
    {:ok, server} = Fediverse.block(scope, ana, :server)

    {:ok, lv, _html} = settings(conn, site)
    assert has_element?(lv, "#blocks-#{account.id}", "@ana@mastodon.example")
    assert has_element?(lv, "#blocks-#{server.id}", "mastodon.example")

    html = lv |> element("#unblock-blocks-#{server.id}-menu-item") |> render_click()

    assert html =~ "Unblocked mastodon.example."
    refute has_element?(lv, "#blocks-#{server.id}")
    assert has_element?(lv, "#blocks-#{account.id}")
    assert Enum.map(Fediverse.list_blocks(scope), & &1.id) == [account.id]
  end
end
