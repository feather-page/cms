defmodule FeatherWeb.MCP.Tools.UpdateBookTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Books
  alias FeatherWeb.MCP.Tools.UpdateBook

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "changes only the fields given, null clears one", %{site_scope: site_scope, scope: scope} do
    book =
      book_fixture(site_scope,
        title: "Dune",
        author: "Frank Herbert",
        reading_status: "reading",
        rating: 3
      )

    assert {:ok, result} =
             UpdateBook.call(scope, %{
               "site" => "notes.example",
               "book" => book.public_id,
               "reading_status" => "finished",
               "rating" => nil
             })

    assert %{title: "Dune", author: "Frank Herbert", reading_status: "finished", rating: nil} =
             result

    assert result.id == book.public_id
    assert result.read_at == Date.utc_today()
    assert Books.get_book!(site_scope, book.public_id).rating == nil
  end

  test "replaces the cover with the one at cover_url", %{site_scope: site_scope, scope: scope} do
    book = book_fixture(site_scope)
    image = File.read!(test_image_path())
    Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, image))

    assert {:ok, %{has_cover: true}} =
             UpdateBook.call(scope, %{
               "site" => "notes.example",
               "book" => book.public_id,
               "cover_url" => "https://covers.example/dune.jpg"
             })

    book = Books.preload_cover_image(Books.get_book!(site_scope, book.public_id))
    assert book.cover_image.source_url == "https://covers.example/dune.jpg"
  end

  test "an invalid change is an error", %{site_scope: site_scope, scope: scope} do
    book = book_fixture(site_scope, title: "Dune")

    assert UpdateBook.call(scope, %{
             "site" => "notes.example",
             "book" => book.public_id,
             "read_at" => "last week"
           }) == {:error, "Invalid book: read_at is invalid"}
  end

  test "a book of another site is missing", %{scope: scope} do
    theirs = book_fixture(site_scope_fixture())

    assert UpdateBook.call(scope, %{
             "site" => "notes.example",
             "book" => theirs.public_id,
             "title" => "Mine"
           }) ==
             {:error,
              "There is no book #{theirs.public_id} on notes.example. " <>
                "list_books lists its books."}
  end
end
