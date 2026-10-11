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

    test "lists the site's targets", %{conn: conn, site: site, scope: scope} do
      [staging] = Publishing.list_targets(scope)
      production = deployment_target_fixture(scope, public_hostname: "www.example.org")
      other = deployment_target_fixture(site_scope_fixture())

      :ok = Publishing.record_deploy(production, DateTime.add(DateTime.utc_now(), -3, :day))

      {:ok, lv, html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      assert has_element?(lv, "#target-#{staging.public_id} a", "Staging")

      assert has_element?(
               lv,
               "#target-#{staging.public_id} .target-host",
               staging.public_hostname
             )

      assert has_element?(lv, "#target-#{staging.public_id} .target-provider", "Built-in")
      assert has_element?(lv, "#target-#{staging.public_id} .target-deployed", "Never deployed")
      assert has_element?(lv, "#target-#{production.public_id} a", "Production")
      assert has_element?(lv, "#target-#{production.public_id} .target-host", "www.example.org")

      assert has_element?(
               lv,
               "#target-#{production.public_id} .target-deployed",
               "Deployed 3 days ago"
             )

      refute has_element?(lv, "#target-#{other.public_id}")
      refute has_element?(lv, "#deploying-#{production.public_id}")

      ids =
        html
        |> LazyHTML.from_document()
        |> LazyHTML.query("#deployment-targets > li")
        |> LazyHTML.attribute("id")

      assert ids == ["target-#{production.public_id}", "target-#{staging.public_id}"]
    end

    test "shows the deploying badge", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      true = Publishing.acquire_deploy_lock(target)

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      assert has_element?(lv, "#deploying-#{target.public_id}")
      assert has_element?(lv, "#deploy-#{target.public_id}[disabled]")
    end

    test "deploys a target", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      trace_messages(lv)
      lv |> element("#deploy-#{target.public_id}") |> render_click()
      assert_deploy_requested(target)
    end

    test "shows the steps of a running deploy", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope, provider: "hetzner_ftps")
      true = Publishing.acquire_deploy_lock(target)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      refute has_element?(lv, "#deploy-progress-#{target.public_id}")

      started_at = DateTime.utc_now()
      progress = &%{target_id: target.public_id, step: &1, started_at: started_at}
      topic = Publishing.notices_topic(site)

      Phoenix.PubSub.broadcast(Feather.PubSub, topic, {:deploy_progress, progress.(:compress)})

      section = "#deploy-progress-#{target.public_id}"
      assert has_element?(lv, section, "Deploying to #{target.public_hostname}")
      assert has_element?(lv, ~s(#{section} [data-step="build"][data-state="done"]))
      assert has_element?(lv, ~s(#{section} [data-step="build"]), "Export pages")
      assert has_element?(lv, ~s(#{section} [data-step="compress"][data-state="current"]))
      assert has_element?(lv, ~s(#{section} [data-step="upload"][data-state="pending"]))
      assert has_element?(lv, section, "Upload to Hetzner (FTPS)")
      refute has_element?(lv, ~s(#{section} [data-step="waiting"]))

      Phoenix.PubSub.broadcast(Feather.PubSub, topic, {:deploy_progress, progress.(:waiting)})
      assert has_element?(lv, ~s(#{section} [data-step="waiting"][data-state="current"]))

      Publishing.release_deploy_lock(target)
      Phoenix.PubSub.broadcast(Feather.PubSub, topic, {:site_notice, %{message: "Done."}})
      refute has_element?(lv, section)
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

      assert has_element?(
               lv,
               ~s(#deploy-progress-#{target.public_id} [data-step="upload"][data-state="current"])
             )
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
        title: "Deploy to #{target.public_hostname} failed",
        message: "Uploading: nope.",
        retry: target.public_id
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

      Publishing.broadcast_notice(site, %{
        kind: :error,
        message: "Uploading: nope.",
        retry: target.public_id
      })

      {:ok, _target} = Publishing.delete_target(scope, target)

      assert lv |> element("#site-notices button", "Retry") |> render_click() =~
               "This deployment target no longer exists."

      refute has_element?(lv, "#site-notices .alert-error")

      # A crafted event without a target.
      assert render_click(lv, "retry_deploy", %{"id" => "1"}) =~
               "This deployment target no longer exists."
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

    @tag :capture_log
    test "cannot deploy another site's target", %{conn: conn, site: site} do
      other = deployment_target_fixture(site_scope_fixture())
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      Process.flag(:trap_exit, true)

      assert {{%Ecto.NoResultsError{}, _}, _} =
               catch_exit(render_hook(lv, "deploy", %{"id" => other.public_id}))
    end

    test "shows site notices with their link and refreshes the list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = deployment_target_fixture(scope)
      true = Publishing.acquire_deploy_lock(target)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      assert has_element?(lv, "#deploying-#{target.public_id}")

      Publishing.release_deploy_lock(target)

      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        Publishing.notices_topic(site),
        {:site_notice,
         %{message: "Deployed <b>to</b> production.", url: "https://www.example.org"}}
      )

      assert has_element?(lv, "#site-notices", "Deployed <b>to</b> production.")
      assert has_element?(lv, ~s(#site-notices a[href="https://www.example.org"]))
      refute has_element?(lv, "#deploying-#{target.public_id}")
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

  describe "edit" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "updates host name and type", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope, type: "backup")
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      {:ok, lv, _html} =
        lv
        |> element("#target-#{target.public_id} .list-col-grow a")
        |> render_click()
        |> follow_redirect(
          conn,
          ~p"/sites/#{site.public_id}/deployments/#{target.public_id}/edit"
        )

      refute has_element?(lv, "input[name*=config]")
      assert has_element?(lv, "h1", "Backup")

      assert has_element?(
               lv,
               ".setzkasten-page-bar",
               "#{target.public_hostname} · Hetzner (FTPS)"
             )

      {:ok, _lv, html} =
        lv
        |> form("#deployment-target-form",
          deployment_target: %{public_hostname: " New.Example.com ", type: "production"}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/sites/#{site.public_id}/deployments")

      assert html =~ "Deployment target was successfully updated."
      target = Publishing.get_target!(scope, target.public_id)
      assert target.public_hostname == "new.example.com"
      assert target.type == "production"
    end

    test "shows validation errors", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope)
      taken = deployment_target_fixture(scope)

      {:ok, lv, _html} =
        live(conn, ~p"/sites/#{site.public_id}/deployments/#{target.public_id}/edit")

      assert lv
             |> form("#deployment-target-form", deployment_target: %{public_hostname: ""})
             |> render_change() =~ "Can&#39;t be blank"

      assert lv
             |> form("#deployment-target-form",
               deployment_target: %{public_hostname: taken.public_hostname}
             )
             |> render_submit() =~ "Has already been taken"
    end

    test "another site's target is not found", %{conn: conn, site: site} do
      other = deployment_target_fixture(site_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/sites/#{site.public_id}/deployments/#{other.public_id}/edit")
      end
    end
  end
end
