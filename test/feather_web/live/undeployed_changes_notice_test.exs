defmodule FeatherWeb.UndeployedChangesNoticeTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Publishing, Repo}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp deployed(target, at) do
    target |> Ecto.Changeset.change(last_deployed_at: at) |> Repo.update!()
  end

  defp yesterday, do: DateTime.add(DateTime.utc_now(), -1, :day)

  defp edit_path(site, post), do: ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit"

  test "publishing after the last production deploy shows a notice linking to the deployments",
       %{conn: conn, site: site, scope: scope} do
    # The new site's homepage was published before that deploy.
    Repo.update_all(Feather.Content.PageVersion,
      set: [published_at: DateTime.add(DateTime.utc_now(), -2, :day)]
    )

    scope |> deployment_target_fixture() |> deployed(yesterday())
    post = post_fixture(scope, title: "Draft", draft: true)
    {:ok, lv, _html} = live(conn, edit_path(site, post))
    refute has_element?(lv, "#site-notice-undeployed-changes")

    {:ok, lv, _html} =
      lv
      |> form("#post-form", post: %{title: "Today"})
      |> put_submitter("#publish-post")
      |> render_submit()
      |> follow_redirect(conn, edit_path(site, post))

    assert has_element?(lv, "#site-notice-undeployed-changes", "not deployed yet")

    assert has_element?(
             lv,
             ~s(#site-notice-undeployed-changes a[href="/sites/#{site.public_id}/deployments"])
           )
  end

  test "no notice when production was deployed after the newest publish", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    post_fixture(scope, title: "Published")
    scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    refute has_element?(lv, "#site-notice-undeployed-changes")
  end

  test "a production target never deployed counts as not deployed", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    deployment_target_fixture(scope)

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, "#site-notice-undeployed-changes")
  end

  test "the notice goes away when a deploy notice arrives after a production deploy", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    target = scope |> deployment_target_fixture() |> deployed(yesterday())
    post_fixture(scope, title: "Published")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")
    assert has_element?(lv, "#site-notice-undeployed-changes")

    deployed(target, DateTime.utc_now())
    Publishing.broadcast_notice(site, "Site built.", "https://#{target.public_hostname}")

    assert has_element?(lv, "#site-notices", "Site built.")
    refute has_element?(lv, "#site-notice-undeployed-changes")
  end
end
