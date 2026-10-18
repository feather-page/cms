defmodule FeatherWeb.DeploymentTargetLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Publishing

  test "a site the user is not a member of is not found", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    site = site_fixture()

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/sites/#{site.public_id}/deployments")
    end
  end

  describe "index" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "shows the site's target", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      :ok = Publishing.record_deploy(target, DateTime.add(DateTime.utc_now(), -3, :day))

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      assert has_element?(
               lv,
               ~s(#deployment-target a[href="https://#{site.domain}"]),
               site.domain
             )

      assert has_element?(lv, "#target-provider", "FTPS")
      assert has_element?(lv, "#target-deployed", "Deployed 3 days ago")
      refute has_element?(lv, "#target-deploying")
      refute has_element?(lv, "#deploy-target[disabled]")
    end

    test "a target never deployed says so", %{conn: conn, site: site, scope: scope} do
      deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      assert has_element?(lv, "#target-deployed", "Never deployed")
    end

    test "without a target shows the empty state", %{conn: conn, site: site} do
      deployment_target_fixture(site_scope_fixture())
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      assert has_element?(lv, "#no-deployment-target")
      refute has_element?(lv, "#deployment-target")
      refute has_element?(lv, "#deploy-target")
    end

    test "shows the deploying badge", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      true = Publishing.acquire_deploy_lock(target)

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      assert has_element?(lv, "#target-deploying")
      assert has_element?(lv, "#deploy-target[disabled]")
    end

    test "deploys the site", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      trace_messages(lv)
      lv |> element("#deploy-target") |> render_click()
      assert_deploy_requested(target)
    end

    test "shows the steps of a running deploy", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      true = Publishing.acquire_deploy_lock(target)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      refute has_element?(lv, "#deploy-progress")

      started_at = DateTime.utc_now()
      progress = &%{target_id: target.public_id, step: &1, started_at: started_at}
      topic = Publishing.notices_topic(site)

      Phoenix.PubSub.broadcast(Feather.PubSub, topic, {:deploy_progress, progress.(:compress)})

      section = "#deploy-progress"
      assert has_element?(lv, section, "Deploying to #{site.domain}")
      assert has_element?(lv, ~s(#{section} [data-step="build"][data-state="done"]))
      assert has_element?(lv, ~s(#{section} [data-step="build"]), "Export pages")
      assert has_element?(lv, ~s(#{section} [data-step="compress"][data-state="current"]))
      assert has_element?(lv, ~s(#{section} [data-step="upload"][data-state="pending"]))
      assert has_element?(lv, section, "Upload via FTPS")
      refute has_element?(lv, ~s(#{section} [data-step="waiting"]))

      Phoenix.PubSub.broadcast(Feather.PubSub, topic, {:deploy_progress, progress.(:waiting)})
      assert has_element?(lv, ~s(#{section} [data-step="waiting"][data-state="current"]))

      Publishing.release_deploy_lock(target)
      Phoenix.PubSub.broadcast(Feather.PubSub, topic, {:site_notice, %{message: "Done."}})
      refute has_element?(lv, section)
    end

    test "ignores the progress of another target", %{conn: conn, site: site, scope: scope} do
      deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        Publishing.notices_topic(site),
        {:deploy_progress,
         %{target_id: "gone12345678", step: :build, started_at: DateTime.utc_now()}}
      )

      refute has_element?(lv, "#deploy-progress")
    end

    test "shows the steps of a deploy that was running before the page loaded", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = deployment_target_fixture(scope)
      true = Publishing.acquire_deploy_lock(target)
      Publishing.put_deploy_progress(target, :upload, DateTime.utc_now())
      on_exit(fn -> Publishing.clear_deploy_progress(target) end)

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      assert has_element?(lv, ~s(#deploy-progress [data-step="upload"][data-state="current"]))
    end

    test "a failed deploy shows as an error that deploys again", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Publishing.broadcast_notice(site, %{
        kind: :error,
        title: "Deploy to #{site.domain} failed",
        message: "Uploading: nope.",
        retry: true
      })

      assert has_element?(lv, "#site-notices .alert-error", "Uploading: nope.")
      trace_messages(lv)
      lv |> element("#site-notices button", "Retry") |> render_click()
      assert_deploy_requested(target)
      refute has_element?(lv, "#site-notices .alert-error")
    end

    test "retrying the deploy of a deleted target says it is gone", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Publishing.broadcast_notice(site, %{kind: :error, message: "Uploading: nope.", retry: true})
      {:ok, _target} = Publishing.delete_target(scope, target)

      assert lv |> element("#site-notices button", "Retry") |> render_click() =~
               "This site has no deployment target."

      refute has_element?(lv, "#site-notices .alert-error")
    end

    test "a successful deploy links to the site", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Publishing.broadcast_notice(site, %{
        kind: :success,
        title: "#{site.title} is live",
        message: "www.example.org · deployed in 0:42",
        url: "https://www.example.org",
        link_label: "Open site",
        external: true
      })

      assert has_element?(lv, "#site-notices .alert-success", "#{site.title} is live")

      assert has_element?(
               lv,
               ~s(#site-notices a.btn[href="https://www.example.org"]),
               "Open site"
             )
    end

    test "shows site notices with their link and refreshes the target", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = deployment_target_fixture(scope)
      true = Publishing.acquire_deploy_lock(target)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      assert has_element?(lv, "#target-deploying")

      Publishing.release_deploy_lock(target)

      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        Publishing.notices_topic(site),
        {:site_notice,
         %{message: "Deployed <b>to</b> production.", url: "https://www.example.org"}}
      )

      assert has_element?(lv, "#site-notices", "Deployed <b>to</b> production.")
      assert has_element?(lv, ~s(#site-notices a[href="https://www.example.org"]))
      refute has_element?(lv, "#target-deploying")
    end

    test "shows site notices without a link", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        Publishing.notices_topic(site),
        {:site_notice, %{message: "Deploy failed.", url: nil}}
      )

      assert has_element?(lv, "#site-notices", "Deploy failed.")
      refute has_element?(lv, "#site-notices a")
    end

    test "ignores other sites' notices", %{conn: conn, site: site} do
      other = site_fixture()
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        Publishing.notices_topic(other),
        {:site_notice, %{message: "Not for you.", url: nil}}
      )

      refute render(lv) =~ "Not for you."
    end
  end

  # In tests, deploys are requested by sending {:deploy_requested, target}
  # to the LiveView process (deploy_mode :manual), which swallows it.
  defp trace_messages(lv), do: :erlang.trace(lv.pid, true, [:receive])

  defp assert_deploy_requested(target) do
    target_id = target.id
    assert_receive {:trace, _pid, :receive, {:deploy_requested, %{id: ^target_id}}}
  end
end
