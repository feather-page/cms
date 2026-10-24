defmodule FeatherWeb.FollowLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Accounts.Scope
  alias Feather.{Fediverse, Repo}
  alias Feather.Fediverse.FollowedAccount

  @moduletag :capture_log

  setup [:register_and_log_in_user, :create_site_for_user, :make_account]

  defp make_account(%{scope: scope}) do
    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
    :ok = Fediverse.record_online(site, DateTime.utc_now())
    site = Repo.reload!(site)
    %{site: site, scope: Scope.put_site(scope, site)}
  end

  defp following_path(site), do: ~p"/sites/#{site.public_id}/following"

  test "lists the accounts the site follows, requested ones marked", %{conn: conn, site: site} do
    accepted =
      followed_account_fixture(site, remote_account: remote_account_fixture(%{name: "Ana"}))

    requested =
      followed_account_fixture(site,
        remote_account: remote_account_fixture(%{handle: "@bob@example.social"}),
        accepted: false
      )

    {:ok, lv, _html} = live(conn, following_path(site))

    assert has_element?(lv, "#followed-#{accepted.id}", "Ana")
    refute has_element?(lv, "#followed-#{accepted.id}", "Requested")
    assert has_element?(lv, "#followed-#{requested.id}", "@bob@example.social")
    assert has_element?(lv, "#followed-#{requested.id}", "Requested")
    assert has_element?(lv, ~s(a[href="/sites/#{site.public_id}/timeline"]), "Timeline")
  end

  defp delivered(inbox) do
    receive do
      {:fediverse_request, "POST", ^inbox, body} -> Jason.decode!(body)
    after
      0 -> nil
    end
  end

  test "lists the followers", %{conn: conn, site: site} do
    follower = remote_account_fixture(%{name: "Pumbaa", handle: "@pumbaa@example.social"})
    follower_fixture(site, follower)

    {:ok, lv, _html} = live(conn, following_path(site))
    assert has_element?(lv, "#no-accounts", "Not following anyone yet")

    lv |> element("#follow-list a", "Followers") |> render_click()

    assert_patch(lv, following_path(site) <> "?list=followers")
    assert has_element?(lv, "#follower-#{follower.id}", "Pumbaa")
    assert has_element?(lv, "#follower-#{follower.id}", "@pumbaa@example.social")
  end

  test "unfollows an account", %{conn: conn, site: site} do
    ana =
      remote_account_fixture(%{
        uri: "https://example.social/users/ana",
        inbox: "https://example.social/users/ana/inbox",
        handle: "@ana@example.social"
      })

    followed = followed_account_fixture(site, remote_account: ana)

    {:ok, lv, _html} = live(conn, following_path(site))
    serve_remote_accounts([])
    Req.Test.allow(Feather.Fediverse, self(), lv.pid)

    assert has_element?(lv, "#followed-#{followed.id}", "@ana@example.social")
    refute has_element?(lv, "#followed-#{followed.id}", "Requested")

    confirm_click(lv, "#followed-#{followed.id}-unfollow", "Unfollow @ana@example.social?")

    assert %{"type" => "Undo"} = delivered("https://example.social/users/ana/inbox")
    refute has_element?(lv, "#followed-#{followed.id}")
    assert Repo.all(FollowedAccount) == []
  end
end
