defmodule FeatherWeb.BookLookupControllerTest do
  # The search of the editor's book block (assets/js/editor/books.js).
  use FeatherWeb.ConnCase

  setup [:register_and_log_in_user, :create_site_for_user]

  defp lookup(conn, site, params \\ %{}),
    do: conn |> get(~p"/sites/#{site.public_id}/books/lookup", params) |> json_response(200)

  test "returns the 5 most recently read books without a query", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    for n <- 1..6, do: book_fixture(scope, title: "Book #{n}", read_at: Date.new!(2020, n, 1))

    books = lookup(conn, site)
    assert Enum.map(books, & &1["title"]) == ["Book 6", "Book 5", "Book 4", "Book 3", "Book 2"]
  end

  test "searches title and author case-insensitively", %{conn: conn, site: site, scope: scope} do
    gatsby =
      book_fixture(scope, title: "The Great Gatsby", author: "F. Scott Fitzgerald", emoji: "🥂")

    book_fixture(scope, title: "To Kill a Mockingbird", author: "Harper Lee")

    assert [book] = lookup(conn, site, %{q: "mockingBIRD"})
    assert book["title"] == "To Kill a Mockingbird"

    assert [book] = lookup(conn, site, %{q: "fitzgerald"})

    assert book == %{
             "public_id" => gatsby.public_id,
             "title" => "The Great Gatsby",
             "author" => "F. Scott Fitzgerald",
             "cover_url" => nil,
             "emoji" => "🥂"
           }

    assert lookup(conn, site, %{q: "100%"}) == []
  end

  test "includes the cover URL", %{conn: conn, site: site, scope: scope} do
    cover = image_fixture(scope)
    book = book_fixture(scope, cover_image_id: cover.id)

    assert [%{"cover_url" => url}] = lookup(conn, site)
    assert url == "/sites/#{site.public_id}/images/#{cover.public_id}?variant=mobile_x1.webp"
    assert book.cover_image_id == cover.id
  end

  test "does not list books of other sites", %{conn: conn, site: site} do
    book_fixture(site_scope_fixture(), title: "Not mine")
    assert lookup(conn, site) == []

    assert_error_sent 404, fn ->
      get(conn, ~p"/sites/#{site_fixture().public_id}/books/lookup")
    end
  end
end
