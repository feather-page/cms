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

      view |> element("#delete-post-#{post.public_id}") |> render_click()

      assert %{"error" => message} = assert_redirect(view, "/")
      assert message =~ "no longer have access"
      assert Repo.get(Content.Post, post.id)
    end

    test "is redirected on patches", %{conn: conn, site: site, user: user} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      remove_user(site, user)

      assert {:error, {:redirect, %{to: "/"}}} =
               render_patch(view, ~p"/sites/#{site.public_id}/posts?p=2")
    end

    test "a super admin keeps access", %{conn: conn, site: site, scope: scope, user: user} do
      {:ok, post} = Content.create_post(scope, %{"title" => "Delete me"})
      user |> Ecto.Changeset.change(super_admin: true) |> Repo.update!()
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      remove_user(site, user)

      view |> element("#delete-post-#{post.public_id}") |> render_click()
      refute Repo.get(Content.Post, post.id)
    end
  end
end
