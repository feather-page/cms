defmodule FeatherWeb.ImageControllerTest do
  use FeatherWeb.ConnCase

  alias Feather.Media

  setup [:register_and_log_in_user, :create_site_for_user]

  defp upload(path \\ test_image_path()),
    do: %Plug.Upload{path: path, filename: "photo.png", content_type: "image/png"}

  describe "POST /sites/:site_id/images" do
    test "stores the upload and answers like the Editor.js image tool expects", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      conn = post(conn, ~p"/sites/#{site.public_id}/images", %{"image" => upload()})

      [image] = Media.list_images(scope)

      assert json_response(conn, 200) == %{
               "success" => 1,
               "id" => image.id,
               "file" => %{"url" => "/sites/#{site.public_id}/images/#{image.public_id}"}
             }
    end

    test "answers success 0 for files that are not images", %{conn: conn, site: site} do
      path = Path.join(System.tmp_dir!(), "fake-#{System.unique_integer([:positive])}.png")
      File.write!(path, "nope")

      conn = post(conn, ~p"/sites/#{site.public_id}/images", %{"image" => upload(path)})
      assert json_response(conn, 200) == %{"success" => 0}
    end

    test "is not found for another user's site", %{conn: conn} do
      other = site_fixture()

      assert_error_sent 404, fn ->
        post(conn, ~p"/sites/#{other.public_id}/images", %{"image" => upload()})
      end
    end

    test "requires a logged-in user", %{site: site} do
      conn = post(build_conn(), ~p"/sites/#{site.public_id}/images", %{"image" => upload()})
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "POST /sites/:site_id/images/from-url" do
    test "fetches the image", %{conn: conn, site: site, scope: scope} do
      image = File.read!(test_image_path())
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, image))

      conn =
        post(conn, ~p"/sites/#{site.public_id}/images/from-url", %{
          "url" => "https://example.com/cat.png"
        })

      [image] = Media.list_images(scope)
      assert %{"success" => 1, "file" => %{"url" => url}} = json_response(conn, 200)
      assert url == "/sites/#{site.public_id}/images/#{image.public_id}"
      assert image.source_url == "https://example.com/cat.png"
    end

    test "refuses local addresses", %{conn: conn, site: site} do
      conn =
        post(conn, ~p"/sites/#{site.public_id}/images/from-url", %{
          "url" => "http://127.0.0.1/secret.png"
        })

      assert json_response(conn, 200) == %{"success" => 0}
    end
  end

  describe "GET /sites/:site_id/images/:id" do
    test "serves the original and variants with a long cache", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      image = image_fixture(scope)

      response = get(conn, ~p"/sites/#{site.public_id}/images/#{image.public_id}")
      assert response.status == 200
      assert get_resp_header(response, "content-type") == ["image/png"]
      assert [cache] = get_resp_header(response, "cache-control")
      assert cache =~ "max-age=31536000"

      response =
        get(conn, ~p"/sites/#{site.public_id}/images/#{image.public_id}?variant=mobile_x1.webp")

      assert response.status == 200
      assert get_resp_header(response, "content-type") == ["image/webp"]
    end

    test "does not serve images of another site", %{conn: conn, site: site} do
      other_image = image_fixture(site_scope_fixture())

      assert_error_sent 404, fn ->
        get(conn, ~p"/sites/#{site.public_id}/images/#{other_image.public_id}")
      end
    end
  end
end
