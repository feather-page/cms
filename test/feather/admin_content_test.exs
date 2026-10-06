defmodule Feather.AdminContentTest do
  # Context functions added for the content admin.
  use Feather.DataCase

  alias Feather.{Books, Content, Media, OpenLibrary, Pagination, Unsplash}
  alias Feather.Content.Blocks

  setup do
    %{scope: site_scope_fixture()}
  end

  describe "Content.paginate_posts/2" do
    test "pages posts newest first with preloads", %{scope: scope} do
      for n <- 1..21 do
        post_fixture(scope, publish_at: DateTime.add(~U[2024-01-01 00:00:00Z], n, :day))
      end

      first = Content.paginate_posts(scope, 1)
      assert %Pagination{page: 1, total_pages: 2, total_entries: 21} = first
      assert length(first.entries) == 20

      assert Enum.map(first.entries, & &1.publish_at) ==
               Enum.sort(Enum.map(first.entries, & &1.publish_at), {:desc, DateTime})

      assert %{book: nil, thumbnail_image: nil} = hd(first.entries)

      assert %Pagination{page: 2, entries: [_]} = Content.paginate_posts(scope, "2")
      assert %Pagination{page: 2} = Content.paginate_posts(scope, "99")
      assert %Pagination{page: 1} = Content.paginate_posts(scope, "nope")
    end

    test "only sees the scope's site", %{scope: scope} do
      post_fixture(site_scope_fixture())
      assert %Pagination{entries: [], total_pages: 1} = Content.paginate_posts(scope, 1)
    end
  end

  test "Content.paginate_pages_outside_navigation/2 skips navigation pages", %{scope: scope} do
    in_nav = page_fixture(scope, title: "In nav", add_to_navigation: true)
    other = page_fixture(scope, title: "Other")

    ids = Content.paginate_pages_outside_navigation(scope, 1).entries |> Enum.map(& &1.id)
    assert other.id in ids
    refute in_nav.id in ids
    assert hd(Content.paginate_pages_outside_navigation(scope, 1).entries).slug == "/"
  end

  describe "Blocks.content_length/1" do
    test "counts text like the Rails EditorJsContentLengthCalculator" do
      blocks = [
        %{"type" => "paragraph", "text" => "12345"},
        %{"type" => "header", "level" => 2, "text" => "123"},
        %{"type" => "quote", "text" => "12", "caption" => "1"},
        %{"type" => "code", "code" => "1234"},
        %{"type" => "table", "content" => [["1", "22"], ["333", ""]]},
        %{
          "type" => "list",
          "items" => [%{"content" => "12", "items" => [%{"content" => "3", "items" => []}]}]
        },
        %{"type" => "book", "book_public_id" => "x", "title" => "Not counted"}
      ]

      assert Blocks.content_length(blocks) == 5 + 3 + 3 + 4 + 6 + 3
      assert Blocks.content_length(nil) == 0
    end
  end

  describe "Books" do
    test "lookup_books/2 finds recent books or matches", %{scope: scope} do
      book_fixture(scope, title: "A_b", author: "X")
      book_fixture(scope, title: "Axb", author: "Y")

      assert [%{title: "A_b"}] = Books.lookup_books(scope, "a_b")
      assert length(Books.lookup_books(scope, nil)) == 2
      assert [%{author: "Y"}] = Books.lookup_books(scope, "y")
    end

    test "attach_cover_from_url/3 downloads the cover and replaces the old one", %{scope: scope} do
      image = File.read!(test_image_path())
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, image))

      book = book_fixture(scope)
      {:ok, book} = Books.attach_cover_from_url(scope, book, "https://example.com/1.png")
      first_cover_id = book.cover_image_id
      assert first_cover_id

      {:ok, book} = Books.attach_cover_from_url(scope, book, "https://example.com/2.png")
      assert book.cover_image_id != first_cover_id
      assert [%{source_url: "https://example.com/2.png"}] = Media.list_images(scope)
    end

    test "attach_cover_from_url/3 reports failed downloads", %{scope: scope} do
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 404, "missing"))
      book = book_fixture(scope)

      assert {:error, message} =
               Books.attach_cover_from_url(scope, book, "https://example.com/x.png")

      assert message =~ "404"
    end

    test "get_review_post/2 returns the review post", %{scope: scope} do
      book = book_fixture(scope)
      assert Books.get_review_post(scope, book) == nil

      {:ok, %{book: book, post: post}} = Books.create_review(scope, book, %{title: "Review"})
      assert Books.get_review_post(scope, book).id == post.id
    end
  end

  describe "Unsplash" do
    setup do
      previous = Application.get_env(:feather, :unsplash_access_key)
      on_exit(fn -> Application.put_env(:feather, :unsplash_access_key, previous) end)
      :ok
    end

    test "is disabled without an access key" do
      Application.put_env(:feather, :unsplash_access_key, nil)
      refute Unsplash.configured?()
      assert {:error, _} = Unsplash.search("nature")
    end

    test "searches photos" do
      Application.put_env(:feather, :unsplash_access_key, "key")

      Req.Test.stub(Feather.Unsplash, fn conn ->
        Req.Test.json(conn, %{
          "results" => [
            %{
              "id" => "abc",
              "alt_description" => "Trees",
              "urls" => %{"thumb" => "t.jpg", "regular" => "r.jpg"},
              "user" => %{"name" => "Jane", "links" => %{"html" => "https://unsplash.com/@jane"}},
              "links" => %{"download_location" => "dl"}
            }
          ]
        })
      end)

      assert {:ok, [photo]} = Unsplash.search("trees")
      assert photo.description == "Trees"
      assert photo.full_url == "r.jpg"

      assert Unsplash.unsplash_data(photo) == %{
               "photographer_name" => "Jane",
               "photographer_url" => "https://unsplash.com/@jane",
               "download_location" => "dl"
             }

      assert {:ok, []} = Unsplash.search("t")
    end

    @tag capture_log: true
    test "reports errors" do
      Application.put_env(:feather, :unsplash_access_key, "key")
      Req.Test.stub(Feather.Unsplash, &Req.Test.transport_error(&1, :timeout))
      assert {:error, _} = Unsplash.search("trees")
    end
  end

  test "OpenLibrary.search/1 maps results and skips short queries" do
    Req.Test.stub(Feather.OpenLibrary, fn conn ->
      Req.Test.json(conn, %{"docs" => [%{"title" => "Dune", "key" => "/works/1"}]})
    end)

    assert {:ok, [%{title: "Dune", author: nil, isbn: nil, cover_url: nil, key: "/works/1"}]} =
             OpenLibrary.search("dune")

    assert {:ok, []} = OpenLibrary.search("du")
  end
end
