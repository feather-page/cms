defmodule FeatherWeb.MCP.Tools.ListPagesTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Content, Sites}
  alias FeatherWeb.MCP.Tools.ListPages

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "lists the site's pages, the homepage first, then by title", %{
    site_scope: site_scope,
    scope: scope
  } do
    homepage = Content.get_homepage(site_scope)
    shelf = page_fixture(site_scope, title: "Bookshelf", slug: "/books", page_type: "books")

    about =
      page_fixture(site_scope,
        title: "About",
        slug: "/about",
        add_to_navigation: true,
        draft: true
      )

    page_fixture(site_scope_fixture(), title: "Elsewhere")

    assert ListPages.call(scope, %{"site" => "notes.example"}) ==
             {:ok,
              %{
                pages: [
                  %{
                    id: homepage.public_id,
                    title: homepage.title,
                    slug: "/",
                    page_type: "default",
                    in_navigation: false,
                    status: :published
                  },
                  %{
                    id: about.public_id,
                    title: "About",
                    slug: "/about",
                    page_type: "default",
                    in_navigation: true,
                    status: :draft
                  },
                  %{
                    id: shelf.public_id,
                    title: "Bookshelf",
                    slug: "/books",
                    page_type: "books",
                    in_navigation: false,
                    status: :published
                  }
                ]
              }}

    assert [%{page: %{id: about_id}}] = Sites.list_navigation_items(site_scope)
    assert about_id == about.id
  end

  test "shows unpublished changes", %{site_scope: site_scope, scope: scope} do
    page = page_fixture(site_scope, title: "About", slug: "/about")
    {:ok, _page} = Content.update_page(site_scope, page, %{title: "About me"})

    assert {:ok, %{pages: pages}} = ListPages.call(scope, %{"site" => "notes.example"})

    assert %{title: "About me", status: :unpublished_changes} =
             Enum.find(pages, &(&1.id == page.public_id))
  end
end
