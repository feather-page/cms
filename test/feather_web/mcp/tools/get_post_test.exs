defmodule FeatherWeb.MCP.Tools.GetPostTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Content.BlockValidator
  alias FeatherWeb.MCP.Tools.GetPost

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "gives the post with its fields, content, lock version and links", %{
    site_scope: site_scope,
    scope: scope
  } do
    header = image_fixture(site_scope)
    thumbnail = image_fixture(site_scope)

    post =
      post_fixture(site_scope,
        title: "Hello",
        slug: "/hello",
        meta_title: "Hello there",
        description: "A first post.",
        emoji: "👋",
        tags: "elixir, phoenix",
        publish_at: ~U[2026-10-01 09:00:00.123456Z],
        header_image_id: header.id,
        thumbnail_image_id: thumbnail.id,
        content: [paragraph("Hi."), image_block(header, "A photo")],
        draft: true
      )

    site = site_scope.site

    assert {:ok, result} =
             GetPost.call(scope, %{"site" => "notes.example", "post" => post.public_id})

    assert %{
             id: post.public_id,
             title: "Hello",
             slug: "/hello",
             meta_title: "Hello there",
             description: "A first post.",
             emoji: "👋",
             tags: ["elixir", "phoenix"],
             publish_at: ~U[2026-10-01 09:00:00.123456Z],
             header_image: header.public_id,
             thumbnail_image: thumbnail.public_id,
             content: post.content,
             book: nil,
             status: :draft,
             lock_version: 1,
             editor_url:
               "#{FeatherWeb.Endpoint.url()}/sites/#{site.public_id}/posts/#{post.public_id}/edit",
             preview_url: "#{FeatherWeb.Endpoint.url()}/preview/#{site.public_id}/hello/"
           } == result

    assert {:ok, _blocks} = BlockValidator.validate(result.content)
  end

  test "leaves out block fields without a value, so the content can be sent back", %{
    site_scope: site_scope,
    scope: scope
  } do
    book = book_fixture(site_scope, title: "Dune")
    block = %{"type" => "book", "book_public_id" => book.public_id}
    post = post_fixture(site_scope, content: [block], draft: true)

    assert {:ok, %{content: [content_block]}} =
             GetPost.call(scope, %{"site" => "notes.example", "post" => post.public_id})

    refute Enum.any?(content_block, fn {_key, value} -> is_nil(value) end)
    assert {:ok, _blocks} = BlockValidator.validate([content_block])
  end

  test "a post without slug has no preview link yet", %{site_scope: site_scope, scope: scope} do
    post = post_fixture(site_scope, title: nil, slug: nil, draft: true)

    assert {:ok, %{preview_url: nil}} =
             GetPost.call(scope, %{"site" => "notes.example", "post" => post.public_id})
  end

  test "a post of another site is missing", %{scope: scope} do
    theirs = post_fixture(site_scope_fixture())

    assert GetPost.call(scope, %{"site" => "notes.example", "post" => theirs.public_id}) ==
             {:error,
              "There is no post #{theirs.public_id} on notes.example. " <>
                "list_posts lists its posts."}
  end
end
