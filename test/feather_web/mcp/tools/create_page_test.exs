defmodule FeatherWeb.MCP.Tools.CreatePageTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Content, Sites}
  alias Feather.Content.BlockValidator
  alias FeatherWeb.MCP.Tools.CreatePage

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "saves a draft with the fields given, images named by id", %{
    site_scope: site_scope,
    scope: scope
  } do
    header = image_fixture(site_scope)
    thumbnail = image_fixture(site_scope)

    assert {:ok, result} =
             CreatePage.call(scope, %{
               "site" => "notes.example",
               "title" => "Projects",
               "slug" => "/work",
               "description" => "What I built.",
               "emoji" => "🛠️",
               "tags" => ["Code", "work"],
               "page_type" => "projects",
               "header_image" => header.public_id,
               "thumbnail_image" => thumbnail.public_id,
               "content" => [
                 %{"type" => "paragraph", "text" => "Things I made."},
                 %{"type" => "image", "image_id" => header.public_id}
               ]
             })

    assert %{
             title: "Projects",
             slug: "/work",
             description: "What I built.",
             emoji: "🛠️",
             tags: ["code", "work"],
             page_type: "projects",
             in_navigation: false,
             header_image: header_id,
             thumbnail_image: thumbnail_id,
             content: [%{"text" => "Things I made."}, %{"image_id" => image_id}],
             status: :draft,
             lock_version: 1
           } = result

    assert {header_id, thumbnail_id, image_id} ==
             {header.public_id, thumbnail.public_id, header.public_id}

    page = Content.get_page!(site_scope, result.id)
    assert Content.draft?(page)
    assert page.header_image_id == header.id
    assert Sites.list_navigation_items(site_scope) == []
  end

  test "in_navigation appends the page to the navigation", %{
    site_scope: site_scope,
    scope: scope
  } do
    listed = page_fixture(site_scope, title: "Now", slug: "/now", add_to_navigation: true)

    assert {:ok, %{id: id, in_navigation: true}} =
             CreatePage.call(scope, %{
               "site" => "notes.example",
               "title" => "About",
               "in_navigation" => true
             })

    assert site_scope |> Sites.list_navigation_items() |> Enum.map(& &1.page.public_id) ==
             [listed.public_id, id]
  end

  test "suggests the slug from the title", %{site_scope: site_scope, scope: scope} do
    post_fixture(site_scope, title: "About", slug: "/about")

    assert {:ok, %{slug: "/about1"}} =
             CreatePage.call(scope, %{"site" => "notes.example", "title" => "About"})
  end

  test "a page needs a slug or a title", %{site_scope: site_scope, scope: scope} do
    assert CreatePage.call(scope, %{"site" => "notes.example"}) ==
             {:error, "Invalid page: slug can't be blank"}

    assert [_homepage] = Content.list_pages(site_scope)
  end

  test "the slug / makes a homepage, which a site has once", %{scope: scope} do
    assert CreatePage.call(scope, %{"site" => "notes.example", "title" => "Home", "slug" => "/"}) ==
             {:error, "Invalid page: slug has already been taken"}
  end

  test "an image of another site is missing", %{site_scope: site_scope, scope: scope} do
    theirs = image_fixture(site_scope_fixture())

    assert CreatePage.call(scope, %{
             "site" => "notes.example",
             "title" => "About",
             "header_image" => theirs.public_id
           }) ==
             {:error, "header_image: there is no image #{theirs.public_id} on notes.example."}

    assert [_homepage] = Content.list_pages(site_scope)
  end

  test "invalid blocks are an error with the block validator's messages", %{scope: scope} do
    assert CreatePage.call(scope, %{
             "site" => "notes.example",
             "title" => "About",
             "content" => [%{"type" => "header", "text" => "Hi", "level" => 1}]
           }) == {:error, "Invalid content: Block 0 (header): /level must be one of: 2, 3, 4"}
  end

  test "takes content in the block validator's schema and the page types" do
    %{inputSchema: schema} = CreatePage.definition()

    assert Map.delete(schema["properties"]["content"], "description") ==
             BlockValidator.content_schema()

    assert schema["$defs"] == BlockValidator.definitions()
    assert schema["properties"]["page_type"]["enum"] == ~w(default books projects)
  end
end
