defmodule Feather.BooksTest do
  use Feather.DataCase

  alias Feather.{Books, Content, Media}
  alias Feather.Books.Book
  alias Feather.Content.Post

  setup do
    %{scope: site_scope_fixture()}
  end

  test "title and author are required", %{scope: scope} do
    assert {:error, changeset} = Books.create_book(scope, %{})
    assert "can't be blank" in errors_on(changeset).title
    assert "can't be blank" in errors_on(changeset).author
  end

  test "rating is 1..5 or nil", %{scope: scope} do
    assert book_fixture(scope, rating: nil).rating == nil
    assert book_fixture(scope, rating: 5).rating == 5

    for rating <- [0, 6] do
      assert {:error, changeset} =
               Books.create_book(scope, %{title: "t", author: "a", rating: rating})

      assert errors_on(changeset).rating != []
    end
  end

  test "finished books default read_at to today", %{scope: scope} do
    book = book_fixture(scope)
    assert book.reading_status == "finished"
    assert book.read_at == Date.utc_today()

    book = book_fixture(scope, reading_status: "want_to_read")
    assert book.read_at == nil

    assert {:error, changeset} =
             Books.create_book(scope, %{title: "t", author: "a", reading_status: "lost"})

    assert "is invalid" in errors_on(changeset).reading_status
  end

  test "list_books/2 orders by read_at and filters by status", %{scope: scope} do
    book_fixture(scope, title: "old", read_at: ~D[2020-01-01])
    book_fixture(scope, title: "new", read_at: ~D[2024-01-01])
    book_fixture(scope, title: "next", reading_status: "want_to_read")

    assert Enum.map(Books.list_books(scope), & &1.title) == ["new", "old", "next"]
    assert Enum.map(Books.list_books(scope, status: :want_to_read), & &1.title) == ["next"]
  end

  test "books_by_public_id/2 finds only the site's books", %{scope: scope} do
    dune = book_fixture(scope, title: "Dune")
    theirs = book_fixture(site_scope_fixture())

    assert Books.books_by_public_id(scope, [dune.public_id, theirs.public_id, "NoSuchBook12"]) ==
             %{dune.public_id => dune}
  end

  test "reviews are posts linked from the book", %{scope: scope} do
    book = book_fixture(scope, title: "Dune", rating: 4)
    assert Book.review_title_suggestion(book) == "Review: Dune"
    refute Book.review?(book)

    assert {:ok, %{book: book, post: post}} =
             Books.create_review(scope, book, %{title: "Review: Dune", slug: "/dune"})

    assert Book.review?(book)
    assert book.post_id == post.id
    assert {:error, :already_reviewed} = Books.create_review(scope, book, %{title: "again"})

    assert {:ok, book} = Books.delete_review(scope, book)
    refute Book.review?(book)
    assert book.rating == nil
    assert_raise Ecto.NoResultsError, fn -> Content.get_post!(scope, post.public_id) end
  end

  test "autosaving a new review creates it with the first valid input", %{scope: scope} do
    book = book_fixture(scope, title: "Dune")

    assert {:ok, %{book: book, post: post}} =
             Books.autosave_review(scope, book, %Post{site_id: scope.site.id}, %{
               "title" => "Review: Dune",
               "slug" => "/posts/reserved"
             })

    assert book.post_id == post.id
    assert {post.title, post.slug} == {"Review: Dune", nil}
    assert Content.draft?(post)

    assert {:ok, %{book: ^book, post: saved}} =
             Books.autosave_review(scope, book, post, %{"slug" => "/dune"})

    assert saved.slug == "/dune"

    assert {:error, :already_reviewed} =
             Books.autosave_review(scope, book, %Post{site_id: scope.site.id}, %{"title" => "x"})
  end

  test "deleting a book deletes its review and cover", %{scope: scope} do
    cover = image_fixture(scope)
    book = book_fixture(scope, cover_image_id: cover.id)
    {:ok, %{book: book, post: post}} = Books.create_review(scope, book, %{title: "Review"})

    assert {:ok, _} = Books.delete_book(scope, book)
    assert Books.list_books(scope) == []
    assert_raise Ecto.NoResultsError, fn -> Content.get_post!(scope, post.public_id) end
    assert Media.get_image(scope, cover.public_id) == nil
  end

  test "the cover must be an image of the site", %{scope: scope} do
    foreign = image_fixture(site_scope_fixture())

    assert {:error, changeset} =
             Books.create_book(scope, %{title: "t", author: "a", cover_image_id: foreign.id})

    assert "is not an image of this site" in errors_on(changeset).cover_image_id
  end

  test "deleting a review post directly leaves the book without review", %{scope: scope} do
    book = book_fixture(scope)
    {:ok, %{post: post}} = Books.create_review(scope, book, %{title: "Review"})
    {:ok, _} = Content.delete_post(scope, post)
    refute Book.review?(Books.get_book!(scope, book.public_id))
  end
end
