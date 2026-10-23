defmodule FeatherWeb.MCP.Tools.ListPostsTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content}
  alias FeatherWeb.MCP.Tools.ListPosts

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "lists the site's posts, newest first", %{site_scope: site_scope, scope: scope} do
    older =
      post_fixture(site_scope,
        title: "Older",
        slug: "/older",
        publish_at: ~U[2026-10-01 09:00:00.123456Z]
      )

    short =
      post_fixture(site_scope,
        title: nil,
        slug: nil,
        content: [paragraph("Just a quick note.")],
        publish_at: ~U[2026-10-02 09:00:00Z],
        draft: true
      )

    post_fixture(site_scope_fixture(), title: "Elsewhere")

    assert ListPosts.call(scope, %{"site" => "notes.example"}) ==
             {:ok,
              %{
                posts: [
                  %{
                    id: short.public_id,
                    title: nil,
                    excerpt: "Just a quick note.",
                    slug: nil,
                    publish_at: ~U[2026-10-02 09:00:00.000000Z],
                    status: :draft,
                    book: nil
                  },
                  %{
                    id: older.public_id,
                    title: "Older",
                    excerpt: nil,
                    slug: "/older",
                    publish_at: ~U[2026-10-01 09:00:00.123456Z],
                    status: :published,
                    book: nil
                  }
                ]
              }}
  end

  test "names the book a review is about", %{site_scope: site_scope, scope: scope} do
    book = book_fixture(site_scope, title: "Dune")
    {:ok, _review} = Books.create_review(site_scope, book, %{title: "Review: Dune"})

    assert {:ok, %{posts: [%{book: book_id}]}} =
             ListPosts.call(scope, %{"site" => "notes.example"})

    assert book_id == book.public_id
  end

  test "shows unpublished changes", %{site_scope: site_scope, scope: scope} do
    post = post_fixture(site_scope, title: "Hello")
    {:ok, _post} = Content.update_post(site_scope, post, %{title: "Hello, world"})

    assert {:ok, %{posts: [%{title: "Hello, world", status: :unpublished_changes}]}} =
             ListPosts.call(scope, %{"site" => "notes.example"})
  end
end
