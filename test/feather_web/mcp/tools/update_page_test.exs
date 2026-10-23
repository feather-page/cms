defmodule FeatherWeb.MCP.Tools.UpdatePageTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Content, Sites}
  alias FeatherWeb.MCP.Tools.UpdatePage

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "changes only the fields given into unpublished changes, null clears one", %{
    site_scope: site_scope,
    scope: scope
  } do
    header = image_fixture(site_scope)

    page =
      page_fixture(site_scope,
        title: "About",
        slug: "/about",
        emoji: "👋",
        tags: "me",
        header_image_id: header.id
      )

    assert {:ok, result} =
             UpdatePage.call(scope, %{
               "site" => "notes.example",
               "page" => page.public_id,
               "lock_version" => page.lock_version,
               "title" => "About me",
               "emoji" => nil,
               "header_image" => nil,
               "page_type" => "books",
               "content" => [%{"type" => "paragraph", "text" => "New."}]
             })

    assert %{
             title: "About me",
             emoji: nil,
             tags: ["me"],
             page_type: "books",
             header_image: nil,
             content: [%{"text" => "New."}],
             status: :unpublished_changes
           } = result

    assert result.lock_version == page.lock_version + 1

    published = site_scope |> Content.list_pages() |> Content.as_published()
    assert Enum.find(published, &(&1.id == page.id)).title == "About"
  end

  test "in_navigation adds the page to the navigation and removes it", %{
    site_scope: site_scope,
    scope: scope
  } do
    page = page_fixture(site_scope, title: "About", slug: "/about")

    assert {:ok, %{in_navigation: true, lock_version: lock_version}} =
             UpdatePage.call(scope, %{
               "site" => "notes.example",
               "page" => page.public_id,
               "lock_version" => page.lock_version,
               "in_navigation" => true
             })

    assert [%{page_id: page_id}] = Sites.list_navigation_items(site_scope)
    assert page_id == page.id

    assert {:ok, %{in_navigation: false}} =
             UpdatePage.call(scope, %{
               "site" => "notes.example",
               "page" => page.public_id,
               "lock_version" => lock_version,
               "in_navigation" => false
             })

    assert Sites.list_navigation_items(site_scope) == []
  end

  test "a page changed elsewhere since its lock version is not saved", %{
    site_scope: site_scope,
    scope: scope
  } do
    page = page_fixture(site_scope, title: "About", draft: true)
    {:ok, _page} = Content.update_page(site_scope, page, %{title: "About, from the editor"})

    assert UpdatePage.call(scope, %{
             "site" => "notes.example",
             "page" => page.public_id,
             "lock_version" => page.lock_version,
             "title" => "About, from Claude",
             "in_navigation" => true
           }) ==
             {:error,
              "The page was changed elsewhere since lock_version #{page.lock_version}, " <>
                "so nothing was saved. get_page gives it as it is now."}

    assert Content.get_page!(site_scope, page.public_id).title == "About, from the editor"
    assert Sites.list_navigation_items(site_scope) == []
  end

  test "invalid changes are an error", %{site_scope: site_scope, scope: scope} do
    page = page_fixture(site_scope, draft: true)

    assert UpdatePage.call(scope, %{
             "site" => "notes.example",
             "page" => page.public_id,
             "lock_version" => page.lock_version,
             "slug" => "/images/me"
           }) == {:error, "Invalid page: slug is reserved"}
  end

  test "a page of another site is missing", %{scope: scope} do
    theirs = page_fixture(site_scope_fixture())

    assert UpdatePage.call(scope, %{
             "site" => "notes.example",
             "page" => theirs.public_id,
             "lock_version" => theirs.lock_version,
             "title" => "Mine"
           }) ==
             {:error,
              "There is no page #{theirs.public_id} on notes.example. " <>
                "list_pages lists its pages."}
  end
end
