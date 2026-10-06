defmodule FeatherWeb.Api.V1.AuthenticationTest do
  use FeatherWeb.ConnCase

  import FeatherWeb.ApiHelpers

  alias Feather.Accounts

  setup :create_api_user_and_site

  defp posts_path(site_public_id), do: "/api/v1/sites/#{site_public_id}/posts"

  describe "bearer token" do
    test "is required", %{site: site} do
      conn = build_conn() |> put_req_header("accept", "application/json")

      assert conn |> get(posts_path(site.public_id)) |> json_response(401) ==
               %{"error" => "Unauthorized"}
    end

    test "must not be empty", %{site: site} do
      conn = build_conn() |> authenticate("")

      assert conn |> get(posts_path(site.public_id)) |> json_response(401)
    end

    test "must use the Bearer scheme", %{site: site, token: token} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Token #{token}")
        |> put_req_header("accept", "application/json")

      assert conn |> get(posts_path(site.public_id)) |> json_response(401)
    end

    test "accepts the scheme in any case", %{site: site, token: token} do
      conn =
        build_conn()
        |> put_req_header("authorization", "bearer #{token}")
        |> put_req_header("accept", "application/json")

      assert conn |> get(posts_path(site.public_id)) |> json_response(200)
    end

    test "stops working once deleted", %{site: site, user: user, token: token} do
      [api_token] = Accounts.list_api_tokens(user)
      :ok = Accounts.delete_api_token(user, api_token.id)

      conn = build_conn() |> authenticate(token)

      assert conn |> get(posts_path(site.public_id)) |> json_response(401)
    end

    test "is checked before the site", %{} do
      conn = build_conn() |> authenticate("invalid")

      assert conn |> get(posts_path("nonexistent")) |> json_response(401)
    end
  end

  describe "site access" do
    test "allows the user's sites", %{conn: conn, site: site} do
      assert conn |> get(posts_path(site.public_id)) |> json_response(200)
    end

    test "hides other users' sites", %{conn: conn} do
      other_site = site_fixture()

      for path <- [
            posts_path(other_site.public_id),
            "/api/v1/sites/#{other_site.public_id}/pages",
            "/api/v1/sites/#{other_site.public_id}/images/whatever"
          ] do
        assert conn |> get(path) |> json_response(404) == %{"error" => "Not found"}
      end
    end

    test "hides other users' sites from writes", %{conn: conn} do
      other_site = site_fixture()

      conn =
        json_request(conn, :post, posts_path(other_site.public_id), %{post: %{title: "x"}})

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a site that does not exist", %{conn: conn} do
      assert conn |> get(posts_path("nonexistent")) |> json_response(404)
    end

    test "allows super admins every site" do
      {:ok, token, _} = Accounts.create_api_token(super_admin_fixture())
      other_site = site_fixture()

      conn = build_conn() |> authenticate(token)

      assert conn |> get(posts_path(other_site.public_id)) |> json_response(200)
    end
  end
end
