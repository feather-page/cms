defmodule FeatherWeb.Api.V1.PageControllerTest do
  use FeatherWeb.ConnCase

  import FeatherWeb.ApiHelpers

  alias Feather.Content

  setup :create_api_user_and_site

  setup %{site: site} do
    %{path: "/api/v1/sites/#{site.public_id}/pages"}
  end

  describe "index" do
    test "lists the homepage first, then by title", %{conn: conn, path: path, scope: scope} do
      page_fixture(scope, title: "Zebra")
      page_fixture(scope, title: "Apple")

      body = conn |> get(path) |> assert_openapi_response("get", "/sites/{site_id}/pages", 200)

      assert Enum.map(body["data"], & &1["slug"]) |> hd() == "/"
      assert body["data"] |> tl() |> Enum.map(& &1["title"]) == ["Apple", "Zebra"]
      assert body["meta"] == %{"page" => 1, "pages" => 1, "count" => 3}
    end

    test "pages with ?p=", %{conn: conn, path: path, scope: scope} do
      for i <- 1..20, do: page_fixture(scope, title: "Page #{i}")

      body = conn |> get(path, p: "2") |> json_response(200)

      assert length(body["data"]) == 1
      assert body["meta"] == %{"page" => 2, "pages" => 2, "count" => 21}
    end
  end

  describe "show" do
    test "returns the page", %{conn: conn, path: path, scope: scope} do
      image = image_fixture(scope)

      page =
        page_fixture(scope,
          title: "About",
          tags: "travel, photos",
          page_type: "books",
          thumbnail_image_id: image.id
        )

      body =
        conn
        |> get("#{path}/#{page.public_id}")
        |> assert_openapi_response("get", "/sites/{site_id}/pages/{id}", 200)

      assert %{
               "title" => "About",
               "tags" => ["travel", "photos"],
               "page_type" => "books",
               "header_image_id" => nil,
               "thumbnail_image_id" => thumbnail_image_id
             } = body["data"]

      assert thumbnail_image_id == image.public_id
    end

    test "returns 404 for an unknown page", %{conn: conn, path: path} do
      assert conn |> get("#{path}/nonexistent") |> json_response(404) == %{"error" => "Not found"}
    end
  end

  describe "create" do
    test "creates a page and normalizes the slug", %{conn: conn, path: path} do
      conn =
        json_request(conn, :post, path, %{
          page: %{
            title: "About Me",
            slug: "about",
            tags: "travel, photos",
            content: [%{type: "paragraph", text: "I am a developer."}]
          }
        })

      body = assert_openapi_response(conn, "post", "/sites/{site_id}/pages", 201)
      assert body["data"]["slug"] == "/about"
      assert body["data"]["page_type"] == "default"
      assert body["data"]["tags"] == ["travel", "photos"]
    end

    test "creates a page with a page type and images", %{conn: conn, path: path, scope: scope} do
      header = image_fixture(scope)
      thumbnail = image_fixture(scope)

      conn =
        json_request(conn, :post, path, %{
          page: %{
            title: "Books",
            slug: "books",
            page_type: "books",
            header_image_id: header.public_id,
            thumbnail_image_id: thumbnail.public_id
          }
        })

      body = json_response(conn, 201)
      assert body["data"]["page_type"] == "books"
      assert body["data"]["header_image_id"] == header.public_id
      assert body["data"]["thumbnail_image_id"] == thumbnail.public_id
    end

    test "creates the homepage with slug / when there is none",
         %{conn: conn, path: path, scope: scope} do
      {:ok, _} = Content.delete_page(scope, Content.get_homepage(scope))

      conn = json_request(conn, :post, path, %{page: %{title: "Home", slug: "/"}})

      assert json_response(conn, 201)["data"]["slug"] == "/"
    end

    test "rejects a second homepage", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{page: %{title: "Home", slug: "/"}})

      assert json_response(conn, 422)["details"]["slug"] == ["has already been taken"]
    end

    test "requires a slug", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{page: %{title: "No Slug"}})

      body = json_response(conn, 422)
      assert body["error"] == "Validation failed"
      assert body["details"]["slug"] != []
    end

    test "rejects an unknown page type", %{conn: conn, path: path} do
      conn = json_request(conn, :post, path, %{page: %{title: "x", slug: "x", page_type: "blog"}})

      assert json_response(conn, 422)["details"]["page_type"] == ["is invalid"]
    end

    test "rejects invalid content blocks", %{conn: conn, path: path} do
      conn =
        json_request(conn, :post, path, %{
          page: %{title: "Bad", slug: "bad", content: [%{type: "list"}]}
        })

      assert json_response(conn, 422) == %{
               "error" => "Content validation failed",
               "details" => %{"content" => ["Block 0 (list): missing required fields: items"]}
             }
    end
  end

  describe "update" do
    setup %{scope: scope} do
      %{page: page_fixture(scope, title: "Original")}
    end

    test "updates fields", %{conn: conn, path: path, page: page} do
      conn =
        json_request(conn, :patch, "#{path}/#{page.public_id}", %{
          page: %{title: "Updated", tags: "travel, photos"}
        })

      body = assert_openapi_response(conn, "patch", "/sites/{site_id}/pages/{id}", 200)
      assert body["data"]["title"] == "Updated"
      assert body["data"]["tags"] == ["travel", "photos"]
      assert body["data"]["slug"] == page.slug
    end

    test "replaces the content", %{conn: conn, path: path, page: page} do
      conn =
        json_request(conn, :patch, "#{path}/#{page.public_id}", %{
          page: %{content: [%{type: "paragraph", text: "New content"}]}
        })

      assert [%{"text" => "New content"}] = json_response(conn, 200)["data"]["content"]
    end

    test "keeps the navigation", %{conn: conn, path: path, scope: scope} do
      page = page_fixture(scope, add_to_navigation: true)

      conn = json_request(conn, :patch, "#{path}/#{page.public_id}", %{page: %{title: "Nav"}})

      assert json_response(conn, 200)
      assert Content.get_page(scope, page.public_id).add_to_navigation
    end
  end

  describe "delete" do
    test "deletes the page", %{conn: conn, path: path, scope: scope} do
      page = page_fixture(scope)

      assert conn |> delete("#{path}/#{page.public_id}") |> json_response(200) ==
               %{"message" => "Page deleted"}

      assert Content.get_page(scope, page.public_id) == nil
    end

    test "returns 404 for an unknown page", %{conn: conn, path: path} do
      assert conn |> delete("#{path}/nonexistent") |> json_response(404)
    end
  end
end
