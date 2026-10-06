defmodule FeatherWeb.Api.V1.PostControllerTest do
  use FeatherWeb.ConnCase

  import FeatherWeb.ApiHelpers

  alias Feather.Content

  setup :create_api_user_and_site

  setup %{site: site} do
    %{path: "/api/v1/sites/#{site.public_id}/posts"}
  end

  describe "index" do
    test "returns an empty list without posts", %{conn: conn, path: path} do
      body = conn |> get(path) |> assert_openapi_response("get", "/sites/{site_id}/posts", 200)

      assert body == %{"data" => [], "meta" => %{"page" => 1, "pages" => 1, "count" => 0}}
    end

    test "lists the newest posts first", %{conn: conn, path: path, scope: scope} do
      post_fixture(scope, title: "Old", publish_at: ~U[2024-01-01 10:00:00Z])
      post_fixture(scope, title: "New", publish_at: ~U[2025-01-01 10:00:00Z])

      body = conn |> get(path) |> json_response(200)

      assert Enum.map(body["data"], & &1["title"]) == ["New", "Old"]
    end

    test "pages with ?p= in pages of 20", %{conn: conn, path: path, scope: scope} do
      for day <- 1..25 do
        post_fixture(scope,
          title: "Post #{day}",
          publish_at: DateTime.new!(Date.new!(2024, 1, day), ~T[10:00:00], "Etc/UTC")
        )
      end

      first = conn |> get(path) |> json_response(200)
      assert length(first["data"]) == 20
      assert first["meta"] == %{"page" => 1, "pages" => 2, "count" => 25}
      assert hd(first["data"])["title"] == "Post 25"

      second = conn |> get(path, p: "2") |> json_response(200)
      assert Enum.map(second["data"], & &1["title"]) == Enum.map(5..1//-1, &"Post #{&1}")
      assert second["meta"] == %{"page" => 2, "pages" => 2, "count" => 25}

      beyond = conn |> get(path, p: "3") |> json_response(200)
      assert beyond["data"] == []
      assert beyond["meta"]["page"] == 3

      for invalid <- ["0", "-1", "abc"] do
        assert conn |> get(path, p: invalid) |> json_response(200) |> get_in(["meta", "page"]) ==
                 1
      end
    end

    test "lists only the site's posts", %{conn: conn, path: path} do
      other_scope = site_scope_fixture()
      post_fixture(other_scope)

      assert conn |> get(path) |> json_response(200) |> Map.fetch!("data") == []
    end
  end

  describe "show" do
    test "returns the post", %{conn: conn, path: path, scope: scope} do
      image = image_fixture(scope)

      post =
        post_fixture(scope,
          title: "My Post",
          slug: "/my-post",
          emoji: "🚀",
          tags: "Elixir, phoenix",
          draft: true,
          publish_at: ~U[2024-05-06 07:08:09.123456Z],
          thumbnail_image_id: image.id
        )

      body =
        conn
        |> get("#{path}/#{post.public_id}")
        |> assert_openapi_response("get", "/sites/{site_id}/posts/{id}", 200)

      assert %{
               "id" => id,
               "title" => "My Post",
               "slug" => "/my-post",
               "emoji" => "🚀",
               "draft" => true,
               "publish_at" => "2024-05-06T07:08:09Z",
               "tags" => ["elixir", "phoenix"],
               "content" => [%{"type" => "paragraph", "text" => "Hello from a post."}],
               "header_image_id" => nil,
               "thumbnail_image_id" => thumbnail_image_id,
               "created_at" => created_at
             } = body["data"]

      assert id == post.public_id
      assert thumbnail_image_id == image.public_id
      assert {:ok, _, 0} = DateTime.from_iso8601(created_at)
    end

    test "returns an empty tag list without tags", %{conn: conn, path: path, scope: scope} do
      post = post_fixture(scope)

      assert conn
             |> get("#{path}/#{post.public_id}")
             |> json_response(200)
             |> get_in(["data", "tags"]) ==
               []
    end

    test "returns 404 for an unknown post", %{conn: conn, path: path} do
      assert conn |> get("#{path}/nonexistent") |> json_response(404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post of another site", %{conn: conn, path: path} do
      other_post = post_fixture(site_scope_fixture())

      assert conn |> get("#{path}/#{other_post.public_id}") |> json_response(404)
    end
  end

  describe "create" do
    test "creates a post", %{conn: conn, path: path, scope: scope} do
      conn =
        json_request(conn, :post, path, %{
          post: %{
            title: "New Post",
            slug: "/new-post",
            publish_at: "2024-01-02T03:04:05+02:00",
            content: [
              %{type: "header", text: "Hello", level: 2},
              %{type: "paragraph", text: "World"}
            ]
          }
        })

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/posts", 201)
      assert body["data"]["slug"] == "/new-post"
      assert body["data"]["publish_at"] == "2024-01-02T01:04:05Z"
      assert length(body["data"]["content"]) == 2

      post = Content.get_post(scope, body["data"]["id"])
      assert [%{"type" => "header", "level" => 2}, %{"type" => "paragraph"}] = post.content
    end

    test "stores and returns inline HTML sanitized", %{conn: conn, path: path} do
      payload =
        ~S|<img src=x onerror="alert(1)">It's <b>b</b> <i>i</i> <u>u</u> <code>c</code> | <>
          ~S|<a href="https://e.com" onclick="x()">a</a><script>alert(1)</script>|

      clean = ~S|It's <b>b</b> <i>i</i> <u>u</u> <code>c</code> <a href="https://e.com">a</a>|

      conn =
        json_request(conn, :post, path, %{
          post: %{
            title: "XSS",
            content: [
              %{type: "paragraph", text: payload},
              %{type: "list", style: "ul", items: [payload]},
              %{type: "table", content: [[payload]]}
            ]
          }
        })

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/posts", 201)

      assert [
               %{"text" => ^clean},
               %{"items" => [%{"content" => ^clean}]},
               %{"content" => [[^clean]]}
             ] = body["data"]["content"]

      conn = get(recycle(conn), "#{path}/#{body["data"]["id"]}")
      assert [%{"text" => ^clean} | _] = json_response(conn, 200)["data"]["content"]
    end

    test "creates a post without content", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{post: %{title: "No content"}})

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/posts", 201)
      assert body["data"]["content"] == []
      assert body["data"]["draft"] == false
      assert body["data"]["publish_at"]
    end

    test "creates a draft with tags", %{conn: conn, path: path} do
      conn =
        json_request(conn, :post, path, %{
          post: %{title: "Draft", draft: true, tags: "ruby, rails"}
        })

      body = json_response(conn, 201)
      assert body["data"]["draft"] == true
      assert body["data"]["tags"] == ["ruby", "rails"]
    end

    test "takes header and thumbnail images by public id",
         %{conn: conn, path: path, scope: scope} do
      header = image_fixture(scope)
      thumbnail = image_fixture(scope)

      conn =
        json_request(conn, :post, path, %{
          post: %{
            title: "With images",
            header_image_id: header.public_id,
            thumbnail_image_id: thumbnail.public_id
          }
        })

      body = json_response(conn, 201)
      assert body["data"]["header_image_id"] == header.public_id
      assert body["data"]["thumbnail_image_id"] == thumbnail.public_id

      post = Content.get_post(scope, body["data"]["id"])
      assert post.header_image_id == header.id
      assert post.thumbnail_image_id == thumbnail.id
    end

    test "rejects images of another site", %{conn: conn, path: path} do
      foreign = image_fixture(site_scope_fixture())

      conn =
        json_request(conn, :post, path, %{
          post: %{title: "x", header_image_id: foreign.public_id, thumbnail_image_id: "nope"}
        })

      assert json_response(conn, 422) == %{
               "error" => "Validation failed",
               "details" => %{
                 "header_image_id" => ["is not an image of this site"],
                 "thumbnail_image_id" => ["is not an image of this site"]
               }
             }
    end

    test "assigns embedded images to the post", %{conn: conn, path: path, scope: scope} do
      image = image_fixture(scope)

      conn =
        json_request(conn, :post, path, %{
          post: %{title: "x", content: [%{type: "image", image_id: image.public_id}]}
        })

      post = Content.get_post(scope, json_response(conn, 201)["data"]["id"])
      assert Feather.Media.get_image(scope, image.public_id).post_id == post.id
    end

    test "ignores fields that are not permitted", %{conn: conn, path: path, site: site} do
      conn =
        json_request(conn, :post, path, %{post: %{title: "x", site_id: Ecto.UUID.generate()}})

      body = json_response(conn, 201)

      assert Feather.Repo.get_by!(Feather.Content.Post, public_id: body["data"]["id"]).site_id ==
               site.id
    end

    test "rejects invalid content blocks", %{conn: conn, path: path} do
      conn =
        json_request(conn, :post, path, %{
          post: %{title: "Bad", content: [%{type: "header", text: "No level"}]}
        })

      assert json_response(conn, 422) == %{
               "error" => "Content validation failed",
               "details" => %{
                 "content" => ["Block 0 (header): missing required fields: level"]
               }
             }
    end

    test "rejects unknown block types", %{conn: conn, path: path} do
      conn =
        json_request(conn, :post, path, %{post: %{title: "Bad", content: [%{type: "fancy"}]}})

      assert [message] = json_response(conn, 422)["details"]["content"]
      assert message =~ "unknown or missing type"
    end

    test "rejects content that is not a list", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{post: %{title: "Bad", content: "Hello"}})

      assert json_response(conn, 422)["details"]["content"] == [
               "Content must be an array of blocks"
             ]
    end

    test "rejects a duplicate slug", %{conn: conn, path: path, scope: scope} do
      post_fixture(scope, slug: "/duplicate")

      conn = json_request(conn, :post, path, %{post: %{title: "Dup", slug: "/duplicate"}})

      assert json_response(conn, 422) == %{
               "error" => "Validation failed",
               "details" => %{"slug" => ["has already been taken"]}
             }
    end

    test "requires the post object", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{title: "Flat"})

      assert json_response(conn, 400)["error"] =~ "post"
    end
  end

  describe "update" do
    setup %{scope: scope} do
      %{post: post_fixture(scope, title: "Original", tags: "old")}
    end

    test "updates fields", %{conn: conn, path: path, post: post, scope: scope} do
      image = image_fixture(scope)

      conn =
        json_request(conn, :patch, "#{path}/#{post.public_id}", %{
          post: %{title: "Updated", tags: "ruby, web", thumbnail_image_id: image.public_id}
        })

      body = assert_openapi_response(conn, "patch", "/sites/{site_id}/posts/{id}", 200)
      assert body["data"]["title"] == "Updated"
      assert body["data"]["tags"] == ["ruby", "web"]
      assert body["data"]["thumbnail_image_id"] == image.public_id
      assert body["data"]["content"] == [hd(post.content)]
    end

    test "clears an image with null", %{conn: conn, path: path, scope: scope} do
      image = image_fixture(scope)
      post = post_fixture(scope, header_image_id: image.id)

      conn =
        json_request(conn, :patch, "#{path}/#{post.public_id}", %{post: %{header_image_id: nil}})

      assert json_response(conn, 200)["data"]["header_image_id"] == nil
    end

    test "replaces the content", %{conn: conn, path: path, post: post} do
      conn =
        json_request(conn, :patch, "#{path}/#{post.public_id}", %{
          post: %{content: [%{type: "paragraph", text: "Updated content", id: "keep-me"}]}
        })

      assert [%{"id" => "keep-me", "text" => "Updated content"}] =
               json_response(conn, 200)["data"]["content"]
    end

    test "clears the content with an empty list", %{conn: conn, path: path, post: post} do
      conn = json_request(conn, :patch, "#{path}/#{post.public_id}", %{post: %{content: []}})

      assert json_response(conn, 200)["data"]["content"] == []
    end

    test "rejects invalid content", %{conn: conn, path: path, post: post, scope: scope} do
      conn =
        json_request(conn, :patch, "#{path}/#{post.public_id}", %{
          post: %{title: "Changed", content: [%{type: "header"}]}
        })

      assert json_response(conn, 422)["error"] == "Content validation failed"
      assert Content.get_post(scope, post.public_id).title == "Original"
    end

    test "returns 404 for an unknown post", %{conn: conn, path: path} do
      conn = json_request(conn, :patch, "#{path}/nonexistent", %{post: %{title: "x"}})

      assert json_response(conn, 404)
    end
  end

  describe "delete" do
    test "deletes the post", %{conn: conn, path: path, scope: scope} do
      post = post_fixture(scope)

      assert conn |> delete("#{path}/#{post.public_id}") |> json_response(200) ==
               %{"message" => "Post deleted"}

      assert Content.list_posts(scope) == []
    end

    test "returns 404 for an unknown post", %{conn: conn, path: path} do
      assert conn |> delete("#{path}/nonexistent") |> json_response(404)
    end
  end
end
