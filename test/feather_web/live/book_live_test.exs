defmodule FeatherWeb.BookLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Books, Media, Repo}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp books_path(site), do: ~p"/sites/#{site.public_id}/books"

  defp configure_hardcover(token) do
    previous = Application.get_env(:feather, :hardcover_token)
    Application.put_env(:feather, :hardcover_token, token)
    on_exit(fn -> Application.put_env(:feather, :hardcover_token, previous) end)
  end

  defp hardcover_hits(documents) do
    hits = Enum.map(documents, &%{"document" => &1})
    %{"data" => %{"search" => %{"results" => %{"hits" => hits}}}}
  end

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
      assert has_element?(lv, "#book-#{recent.public_id} .sr-only", "Rated 4 out of 5")
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

    test "creates a book from a Hardcover search result with its cover", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      configure_hardcover("secret")

      Req.Test.stub(Feather.Hardcover, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/graphql"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer secret"]
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["variables"] == %{"query" => "clean code"}

        Req.Test.json(
          conn,
          hardcover_hits([
            %{
              "title" => "Clean Code",
              "author_names" => ["Robert C. Martin"],
              "isbns" => ["0132350882", "9780132350884"],
              "image" => %{"url" => "https://assets.hardcover.app/edition/1/cover.jpeg"}
            }
          ])
        )
      end)

      image = File.read!(test_image_path())

      Req.Test.stub(Feather.Media, fn conn ->
        assert conn.host == "assets.hardcover.app"
        assert conn.request_path == "/edition/1/cover.jpeg"
        Plug.Conn.send_resp(conn, 200, image)
      end)

      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      assert has_element?(lv, ~s(label[for="book-search"]), "Search Hardcover")

      lv |> form("#book-search-form", query: "cl") |> render_change()
      refute has_element?(lv, "#book-search-results")

      lv |> form("#book-search-form", query: "clean code") |> render_change()
      assert has_element?(lv, "#book-search-result-0", "Robert C. Martin")

      lv |> element("#book-search-result-0") |> render_click()
      assert has_element?(lv, ~s(#book_title[value="Clean Code"]))
      assert has_element?(lv, ~s(#book_isbn[value="9780132350884"]))

      assert has_element?(
               lv,
               ~s(#book-cover-preview img[src="https://assets.hardcover.app/edition/1/cover.jpeg"])
             )

      lv |> form("#book-form", book: %{reading_status: "want_to_read"}) |> render_submit()

      [book] = Books.list_books(scope, preload: [:cover_image])
      assert book.title == "Clean Code"
      assert book.author == "Robert C. Martin"
      assert book.isbn == "9780132350884"
      assert book.cover_image.source_url == "https://assets.hardcover.app/edition/1/cover.jpeg"
    end

    test "searches OpenLibrary without a Hardcover token", %{conn: conn, site: site} do
      configure_hardcover(nil)

      Req.Test.stub(Feather.OpenLibrary, fn conn ->
        assert conn.query_params["fields"] =~ "isbn"

        Req.Test.json(conn, %{
          "docs" => [
            %{
              "title" => "Clean Code",
              "author_name" => ["Robert C. Martin"],
              "isbn" => ["0132350882", "9780132350884"]
            }
          ]
        })
      end)

      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      assert has_element?(lv, ~s(label[for="book-search"]), "Search OpenLibrary")

      lv |> form("#book-search-form", query: "clean code") |> render_change()
      lv |> element("#book-search-result-0") |> render_click()
      assert has_element?(lv, ~s(#book_isbn[value="9780132350884"]))
    end

    test "searches at the top of a new book and in the cover block of an existing one", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      configure_hardcover(nil)

      Req.Test.stub(Feather.OpenLibrary, fn conn ->
        Req.Test.json(conn, %{
          "docs" => [%{"title" => "Clean Code", "author_name" => ["Robert C. Martin"]}]
        })
      end)

      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      assert has_element?(lv, "#book-search-form #book-search")

      book = book_fixture(scope, title: "Refactoring")
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")
      refute has_element?(lv, "#book-search-form #book-search")
      assert has_element?(lv, ~s(#book-form fieldset #book-search[form="book-search-form"]))
      assert has_element?(lv, ~s(label[for="book-search"]), "Find a cover")

      lv |> form("#book-search-form", query: "clean code") |> render_change()
      assert has_element?(lv, "#book-search-result-0", "Clean Code")
    end

    test "a search result sets only the cover and the ISBN of an existing book", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      configure_hardcover("secret")

      Req.Test.stub(Feather.Hardcover, fn conn ->
        Req.Test.json(
          conn,
          hardcover_hits([
            %{
              "title" => "Swann's Way",
              "author_names" => ["Marcel Proust", "Lydia Davis"],
              "isbns" => ["9780142437964"],
              "image" => %{"url" => "https://assets.hardcover.app/edition/2/cover.jpeg"}
            }
          ])
        )
      end)

      image = File.read!(test_image_path())
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, image))
      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      book =
        book_fixture(scope, title: "Swann's Way (Remembrance of Things Past 1)", author: "Proust")

      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")
      lv |> form("#book-search-form", query: "swann's way") |> render_change()
      lv |> element("#book-search-result-0") |> render_click()

      assert has_element?(lv, ~s|#book_title[value="Swann's Way (Remembrance of Things Past 1)"]|)
      assert has_element?(lv, ~s(#book_isbn[value="9780142437964"]))

      lv |> form("#book-form") |> render_submit()

      book = Books.preload_cover_image(Books.get_book!(scope, book.public_id))
      assert book.title == "Swann's Way (Remembrance of Things Past 1)"
      assert book.author == "Proust"
      assert book.isbn == "9780142437964"
      assert book.cover_image.source_url == "https://assets.hardcover.app/edition/2/cover.jpeg"
    end

    @tag capture_log: true
    test "shows search errors", %{conn: conn, site: site} do
      configure_hardcover(nil)

      Req.Test.stub(Feather.OpenLibrary, fn conn ->
        conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"error" => "boom"})
      end)

      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      lv |> form("#book-search-form", query: "anything") |> render_change()
      assert has_element?(lv, "#book-search-error")
    end

    @tag capture_log: true
    test "shows an invalid Hardcover token without asking OpenLibrary", %{
      conn: conn,
      site: site
    } do
      configure_hardcover("expired")

      Req.Test.stub(Feather.Hardcover, fn conn ->
        conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "invalid_token"})
      end)

      Req.Test.stub(Feather.OpenLibrary, fn _conn -> flunk("OpenLibrary must not be asked") end)
      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      lv |> form("#book-search-form", query: "anything") |> render_change()
      assert has_element?(lv, "#book-search-error", "Hardcover token is invalid or expired")
    end

    test "uploads a cover for a new book", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")

      lv
      |> file_input("#book-form", :cover, [
        %{name: "cover.png", content: File.read!(test_image_path()), type: "image/png"}
      ])
      |> render_upload("cover.png")

      assert has_element?(lv, "#book-cover-preview img")

      lv
      |> form("#book-form", book: %{title: "Unlisted", author: "Nobody"})
      |> render_submit()

      [book] = Books.list_books(scope, preload: [:cover_image])
      assert book.cover_image.filename == "cover.png"
    end

    test "rejects a cover that is not JPG, PNG or WebP", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")

      lv
      |> file_input("#book-form", :cover, [
        %{name: "cover.gif", content: File.read!(test_image_path()), type: "image/gif"}
      ])
      |> render_upload("cover.gif")

      lv |> form("#book-form") |> render_change()
      assert has_element?(lv, "#book-cover-error", "Only JPG, PNG and WebP")
      refute has_element?(lv, "#book-cover-preview img")

      lv
      |> form("#book-form", book: %{title: "Unlisted", author: "Nobody"})
      |> render_submit()

      assert [%{cover_image_id: nil}] = Books.list_books(scope)
    end

    test "the cover chosen last wins", %{conn: conn, site: site, scope: scope} do
      configure_hardcover("secret")

      Req.Test.stub(Feather.Hardcover, fn conn ->
        Req.Test.json(
          conn,
          hardcover_hits([
            %{
              "title" => "Clean Code",
              "author_names" => ["Robert C. Martin"],
              "image" => %{"url" => "https://assets.hardcover.app/edition/1/cover.jpeg"}
            }
          ])
        )
      end)

      image = File.read!(test_image_path())
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, image))
      Req.Test.set_req_test_to_shared()
      on_exit(&Req.Test.set_req_test_to_private/0)

      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      upload = %{name: "own.png", content: File.read!(test_image_path()), type: "image/png"}
      lv |> file_input("#book-form", :cover, [upload]) |> render_upload("own.png")

      lv |> form("#book-search-form", query: "clean code") |> render_change()
      lv |> element("#book-search-result-0") |> render_click()

      assert has_element?(
               lv,
               ~s(#book-cover-preview img[src="https://assets.hardcover.app/edition/1/cover.jpeg"])
             )

      lv |> file_input("#book-form", :cover, [upload]) |> render_upload("own.png")
      refute has_element?(lv, ~s(#book-cover-preview img[src^="https://"]))

      lv |> form("#book-form") |> render_submit()

      [book] = Books.list_books(scope, preload: [:cover_image])
      assert book.cover_image.filename == "own.png"
    end

    test "an uploaded cover replaces the previous one", %{conn: conn, site: site, scope: scope} do
      {:ok, old_cover} = Media.create_image_from_upload(scope, test_image_path(), "old.png")
      book = book_fixture(scope, title: "Refactoring")
      {:ok, book} = Books.update_book(scope, book, %{cover_image_id: old_cover.id})

      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")

      lv
      |> file_input("#book-form", :cover, [
        %{name: "new.png", content: File.read!(test_image_path()), type: "image/png"}
      ])
      |> render_upload("new.png")

      lv |> form("#book-form") |> render_submit()

      book = Books.preload_cover_image(Books.get_book!(scope, book.public_id))
      assert book.cover_image.filename == "new.png"
      assert Repo.get(Media.Image, old_cover.id) == nil
    end

    test "shows validation errors", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, books_path(site) <> "/new")
      html = lv |> form("#book-form", book: %{title: "No author"}) |> render_submit()
      assert html =~ "Can&#39;t be blank"
    end

    test "deletes a book", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope)
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")

      assert asked(lv, "#delete-book").text ==
               "Removes the book from Feather. It stays on the live site until the next deploy."

      {:ok, _lv, _html} =
        lv |> confirm_click("#delete-book") |> follow_redirect(conn, books_path(site))

      assert Books.list_books(scope) == []
    end

    test "deleting a book deleted in another tab goes back to the list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      book = book_fixture(scope)
      {:ok, lv, _html} = live(conn, books_path(site) <> "/#{book.public_id}/edit")
      {:ok, _} = Books.delete_book(scope, book)

      {:ok, _lv, html} =
        lv |> confirm_click("#delete-book") |> follow_redirect(conn, books_path(site))

      assert html =~ "This book no longer exists."
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
