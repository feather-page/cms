defmodule FeatherWeb.MCP.Tools.ListBooksTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias FeatherWeb.MCP.Tools.ListBooks

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "lists the site's books, optionally with one reading status", %{
    site_scope: site_scope,
    scope: scope
  } do
    dune =
      book_fixture(site_scope,
        title: "Dune",
        author: "Frank Herbert",
        isbn: "9780441013593",
        emoji: "🏜️",
        rating: 5,
        read_at: ~D[2026-10-20]
      )

    hyperion = book_fixture(site_scope, title: "Hyperion", reading_status: "want_to_read")
    book_fixture(site_scope_fixture(), title: "Elsewhere")

    assert {:ok, %{books: [first, second]}} = ListBooks.call(scope, %{"site" => "notes.example"})

    assert first == %{
             id: dune.public_id,
             title: "Dune",
             author: "Frank Herbert",
             isbn: "9780441013593",
             emoji: "🏜️",
             reading_status: "finished",
             rating: 5,
             read_at: ~D[2026-10-20],
             has_cover: false
           }

    assert second.id == hyperion.public_id

    assert {:ok, %{books: [%{id: id}]}} =
             ListBooks.call(scope, %{
               "site" => "notes.example",
               "reading_status" => "want_to_read"
             })

    assert id == hyperion.public_id
  end
end
