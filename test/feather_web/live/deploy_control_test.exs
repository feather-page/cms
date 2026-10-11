defmodule FeatherWeb.DeployControlTest do
  # The deploy control at the bottom of the site sidebar.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Publishing, Repo}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp deployed(target, at) do
    target |> Ecto.Changeset.change(last_deployed_at: at) |> Repo.update!()
  end

  defp yesterday, do: DateTime.add(DateTime.utc_now(), -1, :day)

  defp edit_path(site, post), do: ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit"

  @panel "#deploy-panel-sidebar"

  test "publishing after the last production deploy counts as a change not live",
       %{conn: conn, site: site, scope: scope} do
    # The new site's homepage was published before that deploy.
    Repo.update_all(Feather.Content.PageVersion,
      set: [published_at: DateTime.add(DateTime.utc_now(), -2, :day)]
    )

    scope |> deployment_target_fixture() |> deployed(yesterday())
    post = post_fixture(scope, title: "Draft", draft: true)
    {:ok, lv, _html} = live(conn, edit_path(site, post))
    assert has_element?(lv, @panel, "Live")

    lv |> form("#post-form", post: %{title: "Today"}) |> render_change()
    lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

    assert has_element?(lv, @panel, "1 change not live")
    assert has_element?(lv, "#deploy-site-sidebar", "Deploy to production")
  end

  test "live when production was deployed after the newest publish", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    post_fixture(scope, title: "Published")
    scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, @panel, "Live · just now")
    refute has_element?(lv, "#deploy-site-sidebar")
  end

  test "a production target never deployed counts as not deployed", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    deployment_target_fixture(scope)

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, @panel, "1 change not live")
  end

  test "a deploy notice reloads the status", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    target = scope |> deployment_target_fixture() |> deployed(yesterday())
    post_fixture(scope, title: "Published")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")
    assert has_element?(lv, @panel, "changes not live")

    deployed(target, DateTime.utc_now())
    Publishing.broadcast_notice(site, %{message: "Site built."})

    assert has_element?(lv, "#site-notices", "Site built.")
    assert has_element?(lv, @panel, "Live")
  end

  test "deploys every production target and shows the step", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    target = scope |> deployment_target_fixture() |> deployed(yesterday())
    post_fixture(scope, title: "Published")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    :erlang.trace(lv.pid, true, [:receive])
    lv |> element("#deploy-site-sidebar") |> render_click()
    target_id = target.id
    assert_receive {:trace, _pid, :receive, {:deploy_requested, %{id: ^target_id}}}

    Phoenix.PubSub.broadcast(
      Feather.PubSub,
      Publishing.notices_topic(site),
      {:deploy_progress,
       %{target_id: target.public_id, step: :upload, started_at: DateTime.utc_now()}}
    )

    assert has_element?(lv, @panel, "Deploying to #{target.public_hostname}")
    assert has_element?(lv, @panel, "Uploading")
  end
end
