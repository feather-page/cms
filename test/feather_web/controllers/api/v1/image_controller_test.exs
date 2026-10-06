defmodule FeatherWeb.Api.V1.ImageControllerTest do
  use FeatherWeb.ConnCase

  import FeatherWeb.ApiHelpers

  alias Feather.Media

  setup :create_api_user_and_site

  setup %{site: site} do
    %{path: "/api/v1/sites/#{site.public_id}/images"}
  end

  describe "show" do
    test "returns the image metadata", %{conn: conn, path: path, scope: scope} do
      image = image_fixture(scope)

      body =
        conn
        |> get("#{path}/#{image.public_id}")
        |> assert_openapi_response("get", "/sites/{site_id}/images/{id}", 200)

      assert %{"id" => id, "source_url" => nil, "created_at" => _, "updated_at" => _} =
               body["data"]

      assert id == image.public_id
    end

    test "returns 404 for an unknown image", %{conn: conn, path: path} do
      assert conn |> get("#{path}/nonexistent") |> json_response(404) == %{"error" => "Not found"}
    end

    test "returns 404 for an image of another site", %{conn: conn, path: path} do
      foreign = image_fixture(site_scope_fixture())

      assert conn |> get("#{path}/#{foreign.public_id}") |> json_response(404)
    end
  end

  describe "create from a file" do
    test "stores the upload", %{conn: conn, path: path, scope: scope} do
      upload = %Plug.Upload{path: test_image_path(15, 15, "jpg"), filename: "15x15.jpg"}

      body =
        conn
        |> post(path, %{"file" => upload})
        |> assert_openapi_response("post", "/sites/{site_id}/images", 201)

      image = Media.get_image(scope, body["data"]["id"])
      assert image.filename == "15x15.jpg"
      assert image.content_type == "image/jpeg"
      assert File.exists?(Media.original_path(image))
    end

    test "rejects a file that is not an image", %{conn: conn, path: path, scope: scope} do
      file = Path.join(System.tmp_dir!(), "feather-api-#{System.unique_integer([:positive])}.txt")
      File.write!(file, "just text")

      conn = post(conn, path, %{"file" => %Plug.Upload{path: file, filename: "text.txt"}})

      body = json_response(conn, 422)
      assert body["error"] == "Validation failed"
      assert body["details"]["file"] == ["must be an image"]

      assert Media.list_images(scope) == []
      File.rm(file)
    end
  end

  describe "create from a URL" do
    test "fetches the image and records its source", %{conn: conn, path: path, scope: scope} do
      png = File.read!(test_image_path(15, 15))
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, png))

      conn = json_request(conn, :post, path, %{url: "https://example.com/photo.png"})

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/images", 201)
      assert body["data"]["source_url"] == "https://example.com/photo.png"
      assert Media.get_image(scope, body["data"]["id"]).filename == "photo.png"
    end

    test "rejects URLs that are not http(s)", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{url: "ftp://invalid.com/file.jpg"})

      assert json_response(conn, 422)["error"] =~ "Forbidden Schema"
    end

    test "rejects local addresses", %{conn: conn, path: path} do
      for url <- ["http://localhost/image.jpg", "http://127.0.0.1/image.jpg"] do
        conn = json_request(conn, :post, path, %{url: url})

        assert json_response(conn, 422)["error"] =~ "Forbidden"
      end
    end

    test "reports failed downloads", %{conn: conn, path: path} do
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 404, "not found"))

      conn = json_request(conn, :post, path, %{url: "https://example.com/missing.jpg"})

      assert json_response(conn, 422)["error"] == "Image could not be fetched"
    end

    test "rejects a download that is not an image", %{conn: conn, path: path} do
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, "<html></html>"))

      conn = json_request(conn, :post, path, %{url: "https://example.com/page.html"})

      assert json_response(conn, 422)["details"]["file"] == ["must be an image"]
    end
  end

  test "requires a file or a URL", %{conn: conn, path: path} do
    for body <- [%{}, %{url: ""}, %{file: "not an upload"}] do
      conn = json_request(conn, :post, path, body)

      assert json_response(conn, 422) == %{"error" => "Either file or url parameter is required"}
    end
  end
end
