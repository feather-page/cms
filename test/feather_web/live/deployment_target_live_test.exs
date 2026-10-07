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

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      assert has_element?(lv, "#target-#{staging.public_id}", staging.public_hostname)
      assert has_element?(lv, "#target-#{staging.public_id} .target-type", "Staging")
      assert has_element?(lv, "#target-#{staging.public_id} .target-provider", "internal")
      assert has_element?(lv, "#target-#{production.public_id}", "www.example.org")
      assert has_element?(lv, "#target-#{production.public_id} .target-type", "Production")
      refute has_element?(lv, "#target-#{other.public_id}")
      refute has_element?(lv, "#deploying-#{production.public_id}")
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

      assert lv |> element("#deploy-#{target.public_id}") |> render_click() =~
               "A deployment was triggered for this deployment target."
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

  describe "edit" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "updates host name and type", %{conn: conn, site: site, scope: scope} do
      target = deployment_target_fixture(scope, type: "backup")
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

      {:ok, lv, _html} =
        lv
        |> element("#edit-#{target.public_id}")
        |> render_click()
        |> follow_redirect(
          conn,
          ~p"/sites/#{site.public_id}/deployments/#{target.public_id}/edit"
        )

      refute has_element?(lv, "input[name*=config]")

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
             |> render_change() =~ "can&#39;t be blank"

      assert lv
             |> form("#deployment-target-form",
               deployment_target: %{public_hostname: taken.public_hostname}
             )
             |> render_submit() =~ "has already been taken"
    end

    test "another site's target is not found", %{conn: conn, site: site} do
      other = deployment_target_fixture(site_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/sites/#{site.public_id}/deployments/#{other.public_id}/edit")
      end
    end
  end
end
