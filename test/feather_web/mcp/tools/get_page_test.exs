defmodule FeatherWeb.MCP.Tools.GetPageTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias Feather.Content.BlockValidator
  alias FeatherWeb.MCP.Tools.GetPage

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "gives the page with its fields, content, lock version and links", %{
    site_scope: site_scope,
    scope: scope
  } do
    header = image_fixture(site_scope)
    thumbnail = image_fixture(site_scope)

    page =
      page_fixture(site_scope,
        title: "Bookshelf",
        slug: "/books",
        description: "What I read.",
        emoji: "📚",
        tags: "reading, books",
        page_type: "books",
        add_to_navigation: true,
        header_image_id: header.id,
        thumbnail_image_id: thumbnail.id,
        content: [paragraph("My books."), image_block(header, "A shelf")],
        draft: true
      )

    site = site_scope.site

    assert {:ok, result} =
             GetPage.call(scope, %{"site" => "notes.example", "page" => page.public_id})

    assert %{
             id: page.public_id,
             title: "Bookshelf",
             slug: "/books",
             description: "What I read.",
             emoji: "📚",
             tags: ["reading", "books"],
             page_type: "books",
             in_navigation: true,
             header_image: header.public_id,
             thumbnail_image: thumbnail.public_id,
             content: page.content,
             status: :draft,
             lock_version: 1,
             editor_url:
               "#{FeatherWeb.Endpoint.url()}/sites/#{site.public_id}/pages/#{page.public_id}/edit",
             preview_url: "#{FeatherWeb.Endpoint.url()}/preview/#{site.public_id}/books/"
           } == result

    assert {:ok, _blocks} = BlockValidator.validate(result.content)
  end

  test "the homepage is the page at /", %{site_scope: site_scope, scope: scope} do
    homepage = Content.get_homepage(site_scope)
    site = site_scope.site

    assert {:ok, %{slug: "/", preview_url: preview_url}} =
             GetPage.call(scope, %{"site" => "notes.example", "page" => homepage.public_id})

    assert preview_url == "#{FeatherWeb.Endpoint.url()}/preview/#{site.public_id}/"
  end

  test "a page of another site is missing", %{scope: scope} do
    theirs = page_fixture(site_scope_fixture())

    assert GetPage.call(scope, %{"site" => "notes.example", "page" => theirs.public_id}) ==
             {:error,
              "There is no page #{theirs.public_id} on notes.example. " <>
                "list_pages lists its pages."}
  end
end
