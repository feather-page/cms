defmodule FeatherWeb.Api.V1.ContentApiTest do
  @moduledoc """
  The scenarios of the Rails feature `features/content_api.feature`, one
  test each. Endpoint details are tested next to this file.
  """
  use FeatherWeb.ConnCase

  import FeatherWeb.ApiHelpers

  alias Feather.Content

  setup :create_api_user_and_site

  defp posts_path(site), do: "/api/v1/sites/#{site.public_id}/posts"
  defp pages_path(site), do: "/api/v1/sites/#{site.public_id}/pages"
  defp images_path(site), do: "/api/v1/sites/#{site.public_id}/images"

  describe "authentication" do
    test "authenticating with a valid Bearer token", %{conn: conn, site: site} do
      assert conn |> get(posts_path(site)) |> json_response(200)
    end

    test "rejecting requests without authentication", %{site: site} do
      conn = build_conn() |> put_req_header("accept", "application/json")

      assert conn |> get(posts_path(site)) |> json_response(401) == %{"error" => "Unauthorized"}
    end

    test "rejecting requests with an invalid token", %{site: site} do
      conn = build_conn() |> authenticate("invalid-token-value")

      assert conn |> get(posts_path(site)) |> json_response(401)
    end

    test "accessing only authorized sites", %{conn: conn} do
      other_site = site_fixture(user_fixture(), %{title: "Other Blog"})

      assert conn |> get(posts_path(other_site)) |> json_response(404) == %{
               "error" => "Not found"
             }
    end
  end

  describe "posts" do
    test "listing all posts", %{conn: conn, site: site, scope: scope} do
      for _ <- 1..3, do: post_fixture(scope)

      conn = get(conn, posts_path(site))

      body = assert_openapi_response(conn, "get", "/sites/{site_id}/posts", 200)
      assert length(body["data"]) == 3
    end

    test "creating a post with block content", %{conn: conn, site: site} do
      conn =
        json_request(conn, :post, posts_path(site), %{
          post: %{
            title: "My Imported Post",
            content: [%{type: "paragraph", text: "Hello world"}]
          }
        })

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/posts", 201)
      assert body["data"]["title"] == "My Imported Post"

      assert [%{"id" => id, "type" => "paragraph", "text" => "Hello world"}] =
               body["data"]["content"]

      assert is_binary(id)
    end

    test "creating a post with invalid block content", %{conn: conn, site: site} do
      conn =
        json_request(conn, :post, posts_path(site), %{
          post: %{title: "Bad Post", content: [%{type: "unknown_type"}]}
        })

      body = json_response(conn, 422)
      assert body["error"] == "Content validation failed"
      assert [message] = body["details"]["content"]
      assert message =~ "Valid types:"
    end

    test "updating a post title", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Old Title")

      conn =
        json_request(conn, :patch, "#{posts_path(site)}/#{post.public_id}", %{
          post: %{title: "New Title"}
        })

      body = assert_openapi_response(conn, "patch", "/sites/{site_id}/posts/{id}", 200)
      assert body["data"]["title"] == "New Title"
    end

    test "updating only post content without changing title",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Keep This Title")

      conn =
        json_request(conn, :patch, "#{posts_path(site)}/#{post.public_id}", %{
          post: %{content: [%{type: "paragraph", text: "New content"}]}
        })

      body = json_response(conn, 200)
      assert body["data"]["title"] == "Keep This Title"
      assert [%{"text" => "New content"}] = body["data"]["content"]
    end

    test "deleting a post", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "To Delete")

      conn = delete(conn, "#{posts_path(site)}/#{post.public_id}")

      assert json_response(conn, 200) == %{"message" => "Post deleted"}
      assert Content.get_post(scope, post.public_id) == nil
    end
  end

  describe "pages" do
    test "listing all pages", %{conn: conn, site: site, scope: scope} do
      # Every site starts with its homepage.
      [_homepage] = Content.list_pages(scope)
      for _ <- 1..2, do: page_fixture(scope)

      conn = get(conn, pages_path(site))

      body = assert_openapi_response(conn, "get", "/sites/{site_id}/pages", 200)
      assert length(body["data"]) == 3
    end

    test "creating a page with block content", %{conn: conn, site: site} do
      conn =
        json_request(conn, :post, pages_path(site), %{
          page: %{
            title: "About Me",
            slug: "about-me",
            page_type: "default",
            content: [%{type: "paragraph", text: "About me..."}]
          }
        })

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/pages", 201)
      assert body["data"]["title"] == "About Me"
    end

    test "updating a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Old Page")

      conn =
        json_request(conn, :patch, "#{pages_path(site)}/#{page.public_id}", %{
          page: %{title: "Updated Page"}
        })

      body = assert_openapi_response(conn, "patch", "/sites/{site_id}/pages/{id}", 200)
      assert body["data"]["title"] == "Updated Page"
    end

    test "deleting a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Unwanted")

      conn = delete(conn, "#{pages_path(site)}/#{page.public_id}")

      assert json_response(conn, 200) == %{"message" => "Page deleted"}
    end
  end

  describe "images" do
    test "viewing an image", %{conn: conn, site: site, scope: scope} do
      image = image_fixture(scope)

      conn = get(conn, "#{images_path(site)}/#{image.public_id}")

      body = assert_openapi_response(conn, "get", "/sites/{site_id}/images/{id}", 200)
      assert body["data"]["id"] == image.public_id
    end

    test "uploading an image file", %{conn: conn, site: site} do
      path = test_image_path(15, 15, "jpg")
      upload = %Plug.Upload{path: path, filename: "15x15.jpg", content_type: "image/jpeg"}

      conn = post(conn, images_path(site), %{"file" => upload})

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/images", 201)
      assert is_binary(body["data"]["id"])
    end

    test "uploading a non-image file returns error", %{conn: conn, site: site} do
      path = Path.join(System.tmp_dir!(), "feather-api-#{System.unique_integer([:positive])}.txt")
      File.write!(path, "just text")
      upload = %Plug.Upload{path: path, filename: "text.txt", content_type: "text/plain"}

      conn = post(conn, images_path(site), %{"file" => upload})

      assert json_response(conn, 422)
      File.rm(path)
    end

    test "creating an image from URL", %{conn: conn, site: site} do
      jpg = File.read!(test_image_path(15, 15, "jpg"))

      Req.Test.stub(Feather.Media, fn conn ->
        assert conn.host == "example.com"
        assert conn.request_path == "/photo.jpg"

        conn
        |> Plug.Conn.put_resp_content_type("image/jpeg")
        |> Plug.Conn.send_resp(200, jpg)
      end)

      conn = json_request(conn, :post, images_path(site), %{url: "https://example.com/photo.jpg"})

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/images", 201)
      assert is_binary(body["data"]["id"])
    end
  end

  describe "block content validation" do
    test "validating all supported block types", %{conn: conn, site: site, scope: scope} do
      image = image_fixture(scope)

      content = [
        %{type: "paragraph", text: "Hello"},
        %{type: "header", text: "Title", level: 2},
        %{type: "code", code: "x = 1", language: "ruby"},
        %{type: "image", image_id: image.public_id},
        %{type: "quote", text: "To be", caption: "Shakespeare"},
        %{type: "list", style: "ul", items: ["one", "two"]},
        %{type: "table", content: [["A", "B"], ["1", "2"]], with_headings: true},
        %{type: "book", book_public_id: "abc123"}
      ]

      conn =
        json_request(conn, :post, posts_path(site), %{
          post: %{title: "All Block Types", content: content}
        })

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/posts", 201)
      assert length(body["data"]["content"]) == 8
    end

    test "AI-friendly error messages for invalid blocks", %{conn: conn, site: site} do
      conn =
        json_request(conn, :post, posts_path(site), %{
          post: %{title: "Bad", content: [%{type: "header", text: "Missing level"}]}
        })

      assert %{"details" => %{"content" => [message]}} = json_response(conn, 422)
      assert message =~ "Block 0"
      assert message =~ "(header)"
      assert message == "Block 0 (header): missing required fields: level"
    end
  end
end
