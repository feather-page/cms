defmodule FeatherWeb.SiteAuthTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Accounts.Scope
  alias Feather.{Content, Repo, Sites}

  setup [:register_and_log_in_user, :create_site_for_user]

  # Another member removes the logged in user from the site.
  defp remove_user(site, user) do
    other = user_fixture()
    {:ok, _} = Sites.add_member(site, other)
    other_scope = other |> Scope.for_user() |> Scope.put_site(site)
    member = Enum.find(Sites.list_members(other_scope), &(&1.user_id == user.id))
    {:ok, _} = Sites.remove_member(other_scope, member)
    refute Sites.member?(site, user)
  end

  describe "a member removed while a LiveView is open" do
    test "cannot act through events", %{conn: conn, site: site, scope: scope, user: user} do
      {:ok, post} = Content.create_post(scope, %{"title" => "Keep me"})
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      remove_user(site, user)

      confirm_click(view, "#delete-post-#{post.public_id}-menu-item")

      assert %{"error" => message} = assert_redirect(view, "/")
      assert message =~ "no longer have access"
      assert Repo.get(Content.Post, post.id)
    end

    test "cannot deploy the site", %{conn: conn, site: site, scope: scope, user: user} do
      deployment_target_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      :erlang.trace(view.pid, true, [:receive])

      remove_user(site, user)

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> element("#deploy-target") |> render_click()

      refute_receive {:trace, _pid, :receive, {:deploy_requested, _target}}
    end

    test "cannot retry a deploy", %{conn: conn, site: site, scope: scope, user: user} do
      deployment_target_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")
      Feather.Publishing.broadcast_notice(site, %{kind: :error, message: "Nope.", retry: true})
      assert has_element?(view, "#site-notices button", "Retry")
      :erlang.trace(view.pid, true, [:receive])

      remove_user(site, user)

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> element("#site-notices button", "Retry") |> render_click()

      refute_receive {:trace, _pid, :receive, {:deploy_requested, _target}}
    end

    test "is redirected on patches", %{conn: conn, site: site, user: user} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      remove_user(site, user)

      assert {:error, {:redirect, %{to: "/"}}} =
               render_patch(view, ~p"/sites/#{site.public_id}/posts?p=2")
    end

    test "cannot change a record through the header image picker", %{
      conn: conn,
      site: site,
      scope: scope,
      user: user
    } do
      post = post_fixture(scope, emoji: "🌲")
      picker = "#post-header-image-picker"
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit")
      view |> element("#{picker}-choose-emoji") |> render_click()

      remove_user(site, user)

      view |> element("#{picker}-emoji-picker button", "🦊") |> render_click()
      assert %{"error" => message} = assert_redirect(view, "/")
      assert message =~ "no longer have access"
      assert Repo.reload!(post).emoji == "🌲"
    end

    test "a picker change does not reach a new record's form", %{
      conn: conn,
      site: site,
      scope: scope,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts/new")

      remove_user(site, user)

      send(view.pid, {FeatherWeb.HeaderImagePicker, {:emoji, "🦊"}})
      assert %{"error" => _message} = assert_redirect(view, "/")
      assert Content.list_posts(scope) == []
    end

    test "cannot upload through the header image picker", %{
      conn: conn,
      site: site,
      scope: scope,
      user: user
    } do
      picker = "#post-header-image-picker"
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts/new")
      view |> element("#{picker}-choose-cover") |> render_click()

      upload =
        file_input(view, "#{picker}-upload-form", :image, [
          %{name: "photo.png", content: File.read!(test_image_path()), type: "image/png"}
        ])

      remove_user(site, user)
      render_upload(upload, "photo.png")

      assert %{"error" => _message} = assert_redirect(view, "/")
      assert Feather.Media.list_images(scope) == []
    end

    test "cannot upload a mascot", %{conn: conn, site: site, scope: scope, user: user} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      upload =
        file_input(view, "#mascot-footer-form", :footer_mascot_image, [
          %{name: "mice.png", content: File.read!(test_image_path()), type: "image/png"}
        ])

      remove_user(site, user)
      render_upload(upload, "mice.png")

      assert %{"error" => _message} = assert_redirect(view, "/")
      assert Feather.Media.list_images(scope) == []
    end

    test "a super admin keeps access", %{conn: conn, site: site, scope: scope, user: user} do
      {:ok, post} = Content.create_post(scope, %{"title" => "Delete me"})
      user |> Ecto.Changeset.change(super_admin: true) |> Repo.update!()
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      remove_user(site, user)

      confirm_click(view, "#delete-post-#{post.public_id}-menu-item")
      refute Repo.get(Content.Post, post.id)
    end
  end
end
