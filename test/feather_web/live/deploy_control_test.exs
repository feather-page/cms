defmodule FeatherWeb.DeployControlTest do
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

  test "publishing after the last deploy counts as a change not live",
       %{conn: conn, site: site, scope: scope} do
    # The new site and its homepage are older than that deploy.
    two_days_ago = DateTime.add(DateTime.utc_now(), -2, :day)
    Repo.update_all(Feather.Content.PageVersion, set: [published_at: two_days_ago])
    Repo.update_all(Feather.Sites.Site, set: [updated_at: two_days_ago])

    scope |> deployment_target_fixture() |> deployed(yesterday())
    post = post_fixture(scope, title: "Draft", draft: true)
    {:ok, lv, _html} = live(conn, edit_path(site, post))
    assert has_element?(lv, @panel, "Live")

    lv |> form("#post-form", post: %{title: "Today"}) |> render_change()
    lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

    assert has_element?(lv, @panel, "1 change not live")
    assert has_element?(lv, "#deploy-site-sidebar", ~r/^\s*Deploy\s*$/)
  end

  test "live when deployed after the newest publish", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    post_fixture(scope, title: "Published")
    scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, @panel, "Live · just now")
    assert has_element?(lv, ~s(#{@panel} a[href="https://#{site.domain}"]), site.domain)
    refute has_element?(lv, "#deploy-site-sidebar")
  end

  test "a target never deployed counts the homepage and the site", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    deployment_target_fixture(scope)

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, @panel, "2 changes not live")
  end

  test "changing the site settings counts as a change not live", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
    assert has_element?(lv, @panel, "Live")

    lv |> form("#site-form", site: %{title: "Renamed"}) |> render_submit()

    assert has_element?(lv, @panel, "1 change not live")
  end

  describe "the pending count refreshes" do
    defp redeployed(lv, site, target) do
      deployed(target, DateTime.utc_now())
      Publishing.broadcast_notice(site, %{message: "Deployed."})
      assert has_element?(lv, "#site-notices", "Deployed.")
      assert has_element?(lv, @panel, "Live")
    end

    test "after navigation changes and a page delete on the pages list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      page_fixture(scope, title: "First", add_to_navigation: true)
      second = page_fixture(scope, title: "Second")
      deleted = page_fixture(scope, title: "Deleted")
      target = scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/pages")
      assert has_element?(lv, @panel, "Live")

      confirm_click(lv, "#delete-page-#{deleted.public_id}-menu-item")
      assert has_element?(lv, @panel, "1 change not live")

      changes = [
        fn -> lv |> element("#add-to-navigation-#{second.public_id}") |> render_click() end,
        fn -> lv |> element("#move-up-#{second.public_id}") |> render_click() end,
        fn ->
          lv
          |> element("#remove-from-navigation-#{second.public_id}-menu-item")
          |> render_click()
        end
      ]

      for change <- changes do
        redeployed(lv, site, target)
        change.()
        assert has_element?(lv, @panel, "1 change not live")
      end
    end

    test "after deleting a post or project on its list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, title: "Deleted")
      project = project_fixture(scope, title: "Deleted")
      target = scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())

      for {list, button} <- [
            {~p"/sites/#{site.public_id}/posts", "#delete-post-#{post.public_id}-menu-item"},
            {~p"/sites/#{site.public_id}/projects",
             "#delete-project-#{project.public_id}-menu-item"}
          ] do
        deployed(target, DateTime.utc_now())
        {:ok, lv, _html} = live(conn, list)
        assert has_element?(lv, @panel, "Live")

        confirm_click(lv, button)
        assert has_element?(lv, @panel, "1 change not live")
      end
    end

    test "after saving and deleting redirects", %{conn: conn, site: site, scope: scope} do
      redirect = redirect_fixture(scope, old_path: "/gone", target: "/")
      target = scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")
      assert has_element?(lv, @panel, "Live")

      changes = [
        fn ->
          lv
          |> form("#redirect-form", redirect: %{old_path: "/old", target: "/"})
          |> render_submit()
        end,
        fn -> confirm_click(lv, "#delete-redirect-#{redirect.public_id}-menu-item") end
      ]

      for change <- changes do
        redeployed(lv, site, target)
        change.()
        assert has_element?(lv, @panel, "1 change not live")
      end
    end

    test "after unpublishing in the form", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Unpublished")
      scope |> deployment_target_fixture() |> deployed(DateTime.utc_now())
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      assert has_element?(lv, @panel, "Live")

      lv |> element("#unpublish-post") |> render_click()
      assert has_element?(lv, @panel, "1 change not live")
    end

    test "after toggling add to navigation in the page form", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      page = page_fixture(scope, title: "Services")
      target = deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/pages/#{page.public_id}/edit")

      for value <- ["true", "false"] do
        redeployed(lv, site, target)
        lv |> form("#page-form", page: %{add_to_navigation: value}) |> render_change()
        assert has_element?(lv, @panel, "1 change not live")
      end
    end

    test "after social media link and image changes in the settings", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      link = social_media_link_fixture(scope)
      target = deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      changes = [
        fn ->
          lv |> element("#add-link") |> render_click()
          lv |> element("#service-github") |> render_click()

          lv
          |> form("#social-media-link-form",
            social_media_link: %{name: "My GitHub", url: "https://github.com/me"}
          )
          |> render_submit()
        end,
        fn -> confirm_click(lv, "#delete-social_media_links-#{link.id}-menu-item") end,
        fn ->
          lv
          |> file_input("#mascot-footer-form", :footer_mascot_image, [
            %{
              name: "mascot.png",
              content: File.read!(transparent_image_path(120, 40)),
              type: "image/png"
            }
          ])
          |> render_upload("mascot.png")
        end
      ]

      for change <- changes do
        redeployed(lv, site, target)
        change.()
        assert has_element?(lv, @panel, "1 change not live")
      end
    end
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

  test "deploys the site and shows the step", %{
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

    assert has_element?(lv, @panel, "Deploying to #{site.domain}")
    assert has_element?(lv, @panel, "Uploading")
  end
end
