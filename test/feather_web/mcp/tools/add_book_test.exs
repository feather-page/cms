defmodule FeatherWeb.MCP.Tools.AddBookTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Books
  alias FeatherWeb.MCP.Tools.AddBook

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "puts a book on the bookshelf", %{site_scope: site_scope, scope: scope} do
    assert {:ok, book} =
             AddBook.call(scope, %{
               "site" => "notes.example",
               "title" => "Dune",
               "author" => "Frank Herbert",
               "isbn" => "9780441013593",
               "emoji" => "🏜️",
               "reading_status" => "reading",
               "rating" => 4,
               "read_at" => "2026-10-20"
             })

    [saved] = Books.list_books(site_scope)

    assert book == %{
             id: saved.public_id,
             title: "Dune",
             author: "Frank Herbert",
             isbn: "9780441013593",
             emoji: "🏜️",
             reading_status: "reading",
             rating: 4,
             read_at: ~D[2026-10-20],
             has_cover: false
           }
  end

  test "a finished book is read today unless told otherwise", %{scope: scope} do
    assert {:ok, %{reading_status: "finished", read_at: read_at}} =
             AddBook.call(scope, %{"site" => "notes.example", "title" => "Dune", "author" => "F"})

    assert read_at == Date.utc_today()
  end

  @tag :capture_log
  test "a cover that cannot be downloaded leaves the book without one", %{
    site_scope: site_scope,
    scope: scope
  } do
    Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 404, ""))

    assert {:ok, %{has_cover: false, cover_error: cover_error}} =
             AddBook.call(scope, %{
               "site" => "notes.example",
               "title" => "Dune",
               "author" => "Frank Herbert",
               "cover_url" => "https://covers.example/dune.jpg"
             })

    assert cover_error == "The cover could not be downloaded: Image could not be fetched"
    assert [%{title: "Dune"}] = Books.list_books(site_scope)
  end

  test "an invalid book is an error and nothing is downloaded", %{
    site_scope: site_scope,
    scope: scope
  } do
    Req.Test.stub(Feather.Media, fn _conn -> flunk("the cover must not be downloaded") end)

    assert AddBook.call(scope, %{
             "site" => "notes.example",
             "title" => "Dune",
             "author" => " ",
             "rating" => 6,
             "cover_url" => "https://covers.example/dune.jpg"
           }) == {:error, "Invalid book: author can't be blank; rating must be between 1 and 5"}

    assert Books.list_books(site_scope) == []
  end
end
