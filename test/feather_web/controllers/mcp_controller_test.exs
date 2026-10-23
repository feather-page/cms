defmodule FeatherWeb.MCPControllerTest do
  use FeatherWeb.ConnCase

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content, Sites}
  alias Feather.Content.BlockValidator

  setup do
    user = user_fixture()
    %{access_token: access_token} = connected_app_fixture(user)
    %{user: user, access_token: access_token}
  end

  @tools ~w(list_sites deploy_site search_books list_books add_book update_book
            list_posts get_post create_post update_post publish_post
            list_pages get_page create_page update_page publish_page
            list_images add_image_from_url update_image)

  defp tool_names(conn),
    do: for(tool <- json_response(conn, 200)["result"]["tools"], do: tool["name"])

  describe "a client of revision 2025-11-25" do
    test "is answered after initialize and lists the tools", %{access_token: access_token} do
      conn =
        access_token
        |> mcp_conn()
        |> post_json(%{
          "jsonrpc" => "2.0",
          "id" => 0,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2025-11-25",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "claude-ai", "version" => "0.1.0"}
          }
        })

      assert %{
               "protocolVersion" => "2025-11-25",
               "capabilities" => %{"tools" => %{}},
               "serverInfo" => %{"name" => "feather.page"}
             } = json_response(conn, 200)["result"]

      assert get_resp_header(conn, "mcp-session-id") == []

      initialized = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      assert access_token |> mcp_conn() |> post_json(initialized) |> response(202) == ""

      conn =
        access_token
        |> mcp_conn()
        |> put_req_header("mcp-protocol-version", "2025-11-25")
        |> post_json(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"})

      assert tool_names(conn) == @tools
    end
  end

  describe "a client of revision 2026-07-28" do
    test "discovers the server", %{access_token: access_token} do
      result =
        access_token
        |> mcp_request("server/discover")
        |> json_response(200)
        |> Map.fetch!("result")

      assert %{
               "resultType" => "complete",
               "supportedVersions" => ["2026-07-28", "2025-11-25"],
               "capabilities" => %{"tools" => %{}},
               "_meta" => %{"io.modelcontextprotocol/serverInfo" => %{"name" => "feather.page"}}
             } = result
    end

    test "lists the tools and calls one", %{user: user, access_token: access_token} do
      site_fixture(user, title: "Notes", domain: "notes.example")

      assert access_token |> mcp_request("tools/list") |> tool_names() == @tools

      assert %{"resultType" => "complete", "isError" => false, "structuredContent" => result} =
               call_tool(access_token, "list_sites")

      assert [%{"domain" => "notes.example", "title" => "Notes"}] = result["sites"]
    end

    test "gets the version error for a version the server does not speak", %{
      access_token: access_token
    } do
      conn =
        access_token
        |> mcp_conn()
        |> put_req_header("mcp-protocol-version", "1900-01-01")
        |> put_req_header("mcp-method", "tools/list")
        |> post_json(mcp_body("tools/list", %{}, "1900-01-01"))

      assert json_response(conn, 400) == %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "error" => %{
                 "code" => -32_022,
                 "message" => "Unsupported protocol version",
                 "data" => %{
                   "supported" => ["2026-07-28", "2025-11-25"],
                   "requested" => "1900-01-01"
                 }
               }
             }
    end

    test "is refused when the headers do not match the body", %{access_token: access_token} do
      conn =
        access_token
        |> mcp_conn()
        |> put_req_header("mcp-protocol-version", "2026-07-28")
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "deploy_site")
        |> post_json(mcp_body("tools/call", %{"name" => "list_sites"}))

      assert %{"error" => %{"code" => -32_020}} = json_response(conn, 400)
    end
  end

  describe "books" do
    test "adds a book from a search result with its cover", %{
      user: user,
      access_token: access_token
    } do
      site = site_fixture(user, domain: "notes.example")

      Req.Test.stub(Feather.OpenLibrary, fn conn ->
        Req.Test.json(conn, %{
          "docs" => [
            %{
              "title" => "Dune",
              "author_name" => ["Frank Herbert"],
              "isbn" => ["0441013597", "9780441013593"],
              "cover_i" => 11_481_354
            }
          ]
        })
      end)

      image = File.read!(test_image_path())

      Req.Test.stub(Feather.Media, fn conn ->
        assert conn.host == "covers.openlibrary.org"
        Plug.Conn.send_resp(conn, 200, image)
      end)

      assert %{"structuredContent" => %{"books" => [result]}} =
               call_tool(access_token, "search_books", %{"query" => "dune"})

      arguments =
        result
        |> Map.take(~w(title author isbn cover_url))
        |> Map.merge(%{"site" => "notes.example", "rating" => 5, "read_at" => "2026-10-20"})

      assert %{"isError" => false, "structuredContent" => book} =
               call_tool(access_token, "add_book", arguments)

      assert %{
               "title" => "Dune",
               "author" => "Frank Herbert",
               "isbn" => "9780441013593",
               "reading_status" => "finished",
               "rating" => 5,
               "read_at" => "2026-10-20",
               "has_cover" => true
             } = book

      scope = user |> Scope.for_user() |> Scope.put_site(site)
      [saved] = Books.list_books(scope, preload: [:cover_image])
      assert saved.public_id == book["id"]
      assert saved.cover_image.source_url == "https://covers.openlibrary.org/b/id/11481354-M.jpg"
    end
  end

  describe "posts" do
    setup %{user: user} do
      site = site_fixture(user, domain: "notes.example")
      %{site: site, scope: user |> Scope.for_user() |> Scope.put_site(site)}
    end

    test "are created, updated and published, and the site deployed", %{
      site: site,
      scope: scope,
      access_token: access_token
    } do
      target = deployment_target_fixture(scope)

      assert %{"isError" => false, "structuredContent" => created} =
               call_tool(access_token, "create_post", %{
                 "site" => "notes.example",
                 "title" => "Hello",
                 "content" => [%{"type" => "paragraph", "text" => "A first draft."}]
               })

      assert %{"status" => "draft", "slug" => "/hello", "lock_version" => 1} = created

      assert created["editor_url"] ==
               "#{FeatherWeb.Endpoint.url()}/sites/#{site.public_id}/posts/#{created["id"]}/edit"

      assert created["preview_url"] ==
               "#{FeatherWeb.Endpoint.url()}/preview/#{site.public_id}/hello/"

      assert %{"isError" => false, "structuredContent" => updated} =
               call_tool(access_token, "update_post", %{
                 "site" => "notes.example",
                 "post" => created["id"],
                 "lock_version" => created["lock_version"],
                 "content" => [%{"type" => "paragraph", "text" => "The final text."}]
               })

      assert %{"status" => "draft", "lock_version" => 2} = updated

      assert %{"isError" => false, "structuredContent" => %{"status" => "published"}} =
               call_tool(access_token, "publish_post", %{
                 "site" => "notes.example",
                 "post" => created["id"],
                 "lock_version" => updated["lock_version"]
               })

      assert %{"isError" => false} =
               call_tool(access_token, "deploy_site", %{"site" => "notes.example"})

      assert_received {:deploy_requested, %{id: target_id}}
      assert target_id == target.id

      [published] = scope |> Content.list_posts() |> Content.as_published()
      assert [%{"text" => "The final text."}] = published.content
    end

    test "a post becomes the review of a book", %{scope: scope, access_token: access_token} do
      book = book_fixture(scope, title: "Dune")

      assert %{"isError" => false, "structuredContent" => review} =
               call_tool(access_token, "create_post", %{
                 "site" => "notes.example",
                 "book" => book.public_id,
                 "title" => "Review: Dune"
               })

      assert review["book"] == book.public_id
      book = Books.get_book!(scope, book.public_id)
      assert Books.get_review_post(scope, book).public_id == review["id"]
    end

    test "invalid blocks come back as the block validator's messages", %{
      scope: scope,
      access_token: access_token
    } do
      assert %{"isError" => true, "content" => [%{"type" => "text", "text" => text}]} =
               call_tool(access_token, "create_post", %{
                 "site" => "notes.example",
                 "title" => "Hello",
                 "content" => [%{"type" => "header", "text" => "Hi"}, %{"type" => "fancy"}]
               })

      assert text ==
               "Invalid content: Block 0 (header): missing required fields: level; " <>
                 "Block 1: unknown or missing type 'fancy'. " <>
                 "Valid types: #{Enum.join(BlockValidator.types(), ", ")}"

      assert Content.list_posts(scope) == []
    end

    test "an update based on an older lock version keeps the change made in the editor", %{
      scope: scope,
      access_token: access_token
    } do
      post = post_fixture(scope, title: "Hello", draft: true)
      {:ok, post} = Content.update_post(scope, post, %{title: "Hello again"})
      {:ok, _post} = Content.update_post(scope, post, %{title: "Hello"})

      assert %{"structuredContent" => %{"lock_version" => 3}} =
               call_tool(access_token, "get_post", %{
                 "site" => "notes.example",
                 "post" => post.public_id
               })

      post = Content.get_post!(scope, post.public_id)
      {:ok, %{lock_version: 4}} = Content.autosave(scope, post, %{"title" => "Hello, editor"})

      assert %{"isError" => true, "content" => [%{"text" => text}]} =
               call_tool(access_token, "update_post", %{
                 "site" => "notes.example",
                 "post" => post.public_id,
                 "lock_version" => 3,
                 "title" => "Hello, Claude"
               })

      assert text =~ "was changed elsewhere"
      assert Content.get_post!(scope, post.public_id).title == "Hello, editor"
    end
  end

  describe "pages" do
    setup %{user: user} do
      site = site_fixture(user, domain: "notes.example")
      %{site: site, scope: user |> Scope.for_user() |> Scope.put_site(site)}
    end

    test "a page is created in the navigation and published", %{
      site: site,
      scope: scope,
      access_token: access_token
    } do
      assert %{"isError" => false, "structuredContent" => created} =
               call_tool(access_token, "create_page", %{
                 "site" => "notes.example",
                 "title" => "About",
                 "in_navigation" => true,
                 "content" => [%{"type" => "paragraph", "text" => "Who writes here."}]
               })

      assert %{
               "status" => "draft",
               "slug" => "/about",
               "page_type" => "default",
               "in_navigation" => true,
               "lock_version" => 1
             } = created

      assert created["editor_url"] ==
               "#{FeatherWeb.Endpoint.url()}/sites/#{site.public_id}/pages/#{created["id"]}/edit"

      assert created["preview_url"] ==
               "#{FeatherWeb.Endpoint.url()}/preview/#{site.public_id}/about/"

      assert [%{page: %{public_id: page_id}}] = Sites.list_navigation_items(scope)
      assert page_id == created["id"]

      assert %{"isError" => false, "structuredContent" => %{"status" => "published"}} =
               call_tool(access_token, "publish_page", %{
                 "site" => "notes.example",
                 "page" => created["id"],
                 "lock_version" => created["lock_version"]
               })

      assert %{"structuredContent" => %{"pages" => pages}} =
               call_tool(access_token, "list_pages", %{"site" => "notes.example"})

      assert %{"slug" => "/about", "in_navigation" => true, "status" => "published"} =
               Enum.find(pages, &(&1["id"] == created["id"]))
    end
  end

  describe "images" do
    setup %{user: user} do
      site = site_fixture(user, domain: "notes.example")
      %{scope: user |> Scope.for_user() |> Scope.put_site(site)}
    end

    test "an image added by URL becomes a post's header image", %{
      scope: scope,
      access_token: access_token
    } do
      file = File.read!(test_image_path())

      Req.Test.stub(Feather.Media, fn conn ->
        assert conn.host == "photos.example"
        Plug.Conn.send_resp(conn, 200, file)
      end)

      assert %{"isError" => false, "structuredContent" => image} =
               call_tool(access_token, "add_image_from_url", %{
                 "site" => "notes.example",
                 "url" => "https://photos.example/lighthouse.png"
               })

      assert %{"filename" => "lighthouse.png", "width" => 64, "height" => 48} = image

      assert %{"isError" => false, "structuredContent" => %{"alt" => "A lighthouse in fog"}} =
               call_tool(access_token, "update_image", %{
                 "site" => "notes.example",
                 "image" => image["id"],
                 "alt" => "A lighthouse in fog"
               })

      assert %{"isError" => false, "structuredContent" => post} =
               call_tool(access_token, "create_post", %{
                 "site" => "notes.example",
                 "title" => "Coast",
                 "header_image" => image["id"]
               })

      assert post["header_image"] == image["id"]

      [saved] = scope |> Content.list_posts() |> Content.preload_post_details()
      assert saved.header_image.public_id == image["id"]
      assert saved.header_image.alt == "A lighthouse in fog"
      assert saved.header_image.source_url == "https://photos.example/lighthouse.png"
    end
  end

  describe "a super admin's agent" do
    test "sees and reaches only the sites they are a member of" do
      admin = super_admin_fixture()
      %{access_token: access_token} = connected_app_fixture(admin)
      site_fixture(admin, domain: "own.example")
      site_fixture(user_fixture(), domain: "friend.example")

      %{"structuredContent" => %{"sites" => sites}} = call_tool(access_token, "list_sites")
      assert Enum.map(sites, & &1["domain"]) == ["own.example"]

      tools = json_response(mcp_request(access_token, "tools/list"), 200)["result"]["tools"]

      site_tools =
        for %{"inputSchema" => %{"required" => required} = schema} = tool <- tools,
            "site" in required,
            do: {tool["name"], Map.new(required, &{&1, sample(schema["properties"][&1])})}

      assert {"deploy_site", _arguments} = List.keyfind(site_tools, "deploy_site", 0)

      for {name, arguments} <- site_tools, domain <- ["friend.example", "missing.example"] do
        assert %{"isError" => true, "content" => [%{"type" => "text", "text" => text}]} =
                 call_tool(access_token, name, %{arguments | "site" => domain})

        assert text == "There is no site #{domain}. list_sites lists the sites you can work on.",
               "#{name}: #{text}"
      end

      refute_received {:deploy_requested, _target}
    end
  end

  defp sample(%{"type" => "integer"}), do: 1
  defp sample(%{"type" => "string"}), do: "x"

  test "a GET is refused", %{access_token: access_token} do
    conn = access_token |> mcp_conn() |> get(~p"/mcp")

    assert response(conn, 405) == ""
    assert get_resp_header(conn, "allow") == ["POST"]
  end

  test "a request from a web page of another origin is refused", %{access_token: access_token} do
    for conn <- [mcp_conn(access_token), build_conn()] do
      conn =
        conn
        |> put_req_header("origin", "https://evil.example")
        |> mcp_request("tools/list")

      assert response(conn, 403) == ""
    end
  end
end
