defmodule FeatherWeb.RouterTest do
  use FeatherWeb.ConnCase

  setup [:register_and_log_in_user, :create_site_for_user]

  test "the content API's routes no longer exist", %{conn: conn, scope: scope, site: site} do
    api = "/api/v1/sites/#{site.public_id}"
    post = "#{api}/posts/#{post_fixture(scope).public_id}"
    page = "#{api}/pages/#{page_fixture(scope).public_id}"
    image = "#{api}/images/#{image_fixture(scope).public_id}"

    requests =
      [get: "#{api}/posts", post: "#{api}/posts", get: "#{api}/pages", post: "#{api}/pages"] ++
        Enum.flat_map([post, page], &[get: &1, patch: &1, put: &1, delete: &1]) ++
        [get: image, post: "#{api}/images"]

    conn = put_req_header(conn, "accept", "application/json")

    for {method, path} <- requests do
      assert dispatch(conn, @endpoint, method, path).status == 404, "#{method} #{path} is routed"
    end
  end
end
