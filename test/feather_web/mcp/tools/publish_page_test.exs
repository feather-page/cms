defmodule FeatherWeb.MCP.Tools.PublishPageTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias FeatherWeb.MCP.Tools.PublishPage

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  defp publish(scope, page),
    do:
      PublishPage.call(scope, %{
        "site" => "notes.example",
        "page" => page.public_id,
        "lock_version" => page.lock_version
      })

  test "publishes the page in the state of its lock version", %{
    site_scope: site_scope,
    scope: scope
  } do
    page = page_fixture(site_scope, title: "About", add_to_navigation: true, draft: true)
    {:ok, page} = Content.update_page(site_scope, page, %{title: "About, from the editor"})

    assert {:ok, %{status: :published, title: "About, from the editor", in_navigation: true}} =
             publish(scope, page)

    published = site_scope |> Content.list_pages() |> Content.as_published()
    assert Enum.find(published, &(&1.id == page.id)).title == "About, from the editor"
  end

  test "a page changed elsewhere since its lock version is not published", %{
    site_scope: site_scope,
    scope: scope
  } do
    page = page_fixture(site_scope, title: "About", draft: true)
    {:ok, _page} = Content.update_page(site_scope, page, %{title: "Half written"})

    assert publish(scope, page) ==
             {:error,
              "Not published: the page was changed elsewhere since lock_version " <>
                "#{page.lock_version}. get_page gives it as it is now."}

    assert Content.draft?(Content.get_page!(site_scope, page.public_id))
  end

  test "a slug another published page has is an error", %{site_scope: site_scope, scope: scope} do
    other = page_fixture(site_scope, slug: "/about")
    {:ok, _other} = Content.update_page(site_scope, other, %{slug: "/moved"})
    page = page_fixture(site_scope, slug: "/about", draft: true)

    assert publish(scope, page) ==
             {:error, "Not published: another post or page is published with the slug /about."}

    assert Content.draft?(Content.get_page!(site_scope, page.public_id))
  end

  test "a page of another site is missing", %{scope: scope} do
    theirs = page_fixture(site_scope_fixture(), draft: true)

    assert publish(scope, theirs) ==
             {:error,
              "There is no page #{theirs.public_id} on notes.example. " <>
                "list_pages lists its pages."}
  end
end
