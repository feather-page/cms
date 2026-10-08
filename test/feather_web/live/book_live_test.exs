defmodule FeatherWeb.BookLiveTest do
  # Ports features/books.feature plus the bookshelf and the OpenLibrary search.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Books

  setup [:register_and_log_in_user, :create_site_for_user]

  defp books_path(site), do: ~p"/sites/#{site.public_id}/books"

  describe "bookshelf" do
    test "shows an empty state", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, books_path(site))
      assert has_element?(lv, "#no-books")
    end

    test "groups books by status and finished books by year", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      reading = book_fixture(scope, title: "Reading now", reading_status: "reading")
      want = book_fixture(scope, title: "Some day", reading_status: "want_to_read")
      recent = book_fixture(scope, title: "Recent", read_at: ~D[2024-05-01], rating: 4)
      older = book_fixture(scope, title: "Older", read_at: ~D[2021-02-01])

      {:ok, lv, _html} = live(conn, books_path(site))

      assert has_element?(lv, "#books-reading #book-#{reading.public_id}")
      assert has_element?(lv, "#books-want-to-read #book-#{want.public_id}")
      assert has_element?(lv, "#books-finished-2024[open] #book-#{recent.public_id}", "★★★★☆")
      assert has_element?(lv, "#books-finished-2021 #book-#{older.public_id}")
      refute has_element?(lv, "#books-finished-2021[open]")
    end
  end

  describe "form" do
    test "marks a book as finished", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope, title: "Refactoring", reading_status: "reading")
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")

      {:ok, _lv, html} =
        lv
        |> form("#book-form", book: %{reading_status: "finished"})
        |> render_submit()
        |> follow_redirect(conn, books_path(site))

      assert html =~ "The book was successfully updated."
      assert Books.get_book!(scope, book.public_id).reading_status == "finished"
    end

    test "creates a book from an OpenLibrary search result with its cover", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      Req.Test.stub(Feather.OpenLibrary, fn conn ->
        assert conn.request_path == "/search.json"
        assert conn.query_params["q"] == "clean code"

        Req.Test.json(conn, %{
          "docs" => [
            %{
              "title" => "Clean Code",
              "author_name" => ["Robert C. Martin"],
              "isbn" => ["9780132350884"],
              "key" => "/works/OL123W",
              "cover_i" => 42
            }
          ]
        })
      end)

      image = File.read!(test_image_path())

      Req.Test.stub(Feather.Media, fn conn ->
        assert conn.host == "covers.openlibrary.org"
        assert conn.request_path == "/b/id/42-M.jpg"
        Plug.Conn.send_resp(conn, 200, image)
      end)

      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")

      lv |> form("#book-search-form", query: "cl") |> render_change()
      refute has_element?(lv, "#book-search-results")

      lv |> form("#book-search-form", query: "clean code") |> render_change()
      assert has_element?(lv, "#book-search-result-0", "Robert C. Martin")

      lv |> element("#book-search-result-0") |> render_click()
      assert has_element?(lv, ~s(#book_title[value="Clean Code"]))
      assert has_element?(lv, ~s(#book_isbn[value="9780132350884"]))

      assert has_element?(
               lv,
               ~s(#book-cover-preview img[src="https://covers.openlibrary.org/b/id/42-M.jpg"])
             )

      lv |> form("#book-form", book: %{reading_status: "want_to_read"}) |> render_submit()

      [book] = Books.list_books(scope, preload: [:cover_image])
      assert book.title == "Clean Code"
      assert book.author == "Robert C. Martin"
      assert book.open_library_key == "/works/OL123W"
      assert book.cover_image.source_url == "https://covers.openlibrary.org/b/id/42-M.jpg"
    end

    @tag capture_log: true
    test "shows search errors", %{conn: conn, site: site} do
      Req.Test.stub(Feather.OpenLibrary, fn conn ->
        conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"error" => "boom"})
      end)

      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      lv |> form("#book-search-form", query: "anything") |> render_change()
      assert has_element?(lv, "#book-search-error")
    end

    test "shows validation errors", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      html = lv |> form("#book-form", book: %{title: "No author"}) |> render_submit()
      assert html =~ "can&#39;t be blank"
    end

    test "deletes a book", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope)
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")

      {:ok, _lv, _html} =
        lv |> element("#delete-book") |> render_click() |> follow_redirect(conn, books_path(site))

      assert Books.list_books(scope) == []
    end

    test "links to writing or editing the review", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope, title: "Clean Code")
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")
      assert has_element?(lv, "#write-review")
      refute has_element?(lv, "#edit-review")

      {:ok, _} = Books.create_review(scope, book, %{title: "Review: Clean Code"})
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")
      assert has_element?(lv, "#edit-review")
      refute has_element?(lv, "#write-review")
    end

    test "a book of another site is not found", %{conn: conn, site: site} do
      other = book_fixture(site_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, books_path(site) <> "/#{other.public_id}/edit")
      end
    end
  end
end
