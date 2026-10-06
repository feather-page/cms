defmodule FeatherWeb.ReviewLiveTest do
  # Ports features/book_reviews.feature.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorJsHelpers

  alias Feather.{Books, Content}

  setup [:register_and_log_in_user, :create_site_for_user]

  setup %{scope: scope} do
    %{book: book_fixture(scope, title: "Clean Code", author: "Robert C. Martin")}
  end

  defp review_path(site, book, action),
    do: "/sites/#{site.public_id}/books/#{book.public_id}/review/#{action}"

  test "creates a short review without title", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))
    assert has_element?(lv, "#title-and-slug.d-none")

    lv |> element("#star-rating-5") |> render_click()
    assert has_element?(lv, "#star-rating-5.filled")

    {:ok, _lv, html} =
      lv
      |> form("#review-form")
      |> render_submit(%{
        "post" => %{"content" => editor_json("Great book, highly recommended!")}
      })
      |> follow_redirect(conn, ~p"/sites/#{site.public_id}/books")

    assert html =~ "Review was successfully created."

    book = Books.get_book!(scope, book.public_id)
    assert book.rating == 5
    post = Books.get_review_post(scope, book)
    assert post.title == nil
    assert [%{"text" => "Great book, highly recommended!"}] = post.content
  end

  test "creates a long review with the suggested title changed", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))
    lv |> element("#star-rating-5") |> render_click()

    long = editor_json(String.duplicate("A", 350))
    lv |> element("#review-form") |> render_change(%{"post" => %{"content" => long}})

    refute has_element?(lv, "#title-and-slug.d-none")
    assert has_element?(lv, ~s(#post_title[value="Review: Clean Code"]))

    lv
    |> form("#review-form", post: %{title: "Why Clean Code Changed My Life"})
    |> render_submit(%{"post" => %{"content" => long}})

    book = Books.get_book!(scope, book.public_id)
    assert Books.get_review_post(scope, book).title == "Why Clean Code Changed My Life"
    assert book.rating == 5
  end

  test "edits a review", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, %{book: book}} = Books.create_review(scope, book, %{title: "My Review", content: []})
    {:ok, book} = Books.update_book(scope, book, %{rating: 3})

    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))
    assert has_element?(lv, "#star-rating-3.filled")
    refute has_element?(lv, "#star-rating-4.filled")

    lv |> element("#star-rating-5") |> render_click()

    lv
    |> form("#review-form", post: %{title: "Updated Review Title"})
    |> render_submit(%{"post" => %{"content" => editor_json("Even better on second read...")}})

    book = Books.get_book!(scope, book.public_id)
    post = Books.get_review_post(scope, book)
    assert post.title == "Updated Review Title"
    assert [%{"text" => "Even better on second read..."}] = post.content
    assert book.rating == 5
  end

  test "deletes a review", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, %{post: post}} = Books.create_review(scope, book, %{title: "Review: Clean Code"})

    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))

    {:ok, lv, _html} =
      lv
      |> element("#delete-review")
      |> render_click()
      |> follow_redirect(conn, ~p"/sites/#{site.public_id}/books")

    assert has_element?(lv, "#book-#{book.public_id}")
    refute Books.get_book!(scope, book.public_id).post_id
    assert_raise Ecto.NoResultsError, fn -> Content.get_post!(scope, post.public_id) end

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/books/#{book.public_id}/edit")
    assert has_element?(lv, "#write-review")
  end

  test "only one review per book", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, _} = Books.create_review(scope, book, %{title: "Review: Clean Code"})

    assert {:error, {:live_redirect, %{to: to}}} = live(conn, review_path(site, book, "new"))
    assert to == review_path(site, book, "edit")
  end

  test "editing a missing review goes to the new review", %{conn: conn, site: site, book: book} do
    assert {:error, {:live_redirect, %{to: to}}} = live(conn, review_path(site, book, "edit"))
    assert to == review_path(site, book, "new")
  end

  test "a book of another site is not found", %{conn: conn, site: site} do
    other = book_fixture(site_scope_fixture())

    assert_raise Ecto.NoResultsError, fn -> live(conn, review_path(site, other, "new")) end
  end
end
