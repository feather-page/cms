defmodule FeatherWeb.ReviewLiveTest do
  # Ports features/book_reviews.feature.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorHelpers

  alias Feather.{Books, Content}

  setup [:register_and_log_in_user, :create_site_for_user]

  setup %{scope: scope} do
    %{book: book_fixture(scope, title: "Clean Code", author: "Robert C. Martin")}
  end

  defp review_path(site, book, action),
    do: "/sites/#{site.public_id}/books/#{book.public_id}/review/#{action}"

  defp sync_new(lv, text) do
    lv
    |> element("#review-content-editor")
    |> render_hook("sync", %{
      "lock_version" => nil,
      "order" => nil,
      "blocks" => [paragraph_node("block00001", text)]
    })
  end

  test "the first input creates a short review without title", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))
    assert has_element?(lv, "#title-field.d-none")
    assert has_element?(lv, "#slug-field.d-none")

    sync_new(lv, "Great book, highly recommended!")

    assert_reply(lv, %{status: "saved"})
    assert_patch(lv, review_path(site, book, "edit"))
    post = Books.get_review_post(scope, Books.get_book!(scope, book.public_id))
    assert post.title == nil
    assert [%{"text" => "Great book, highly recommended!"}] = post.content
    assert Content.draft?(post)
  end

  test "refuses a rating outside one to five stars", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))

    for rating <- ["9", "0", "x", ""], do: render_click(lv, "rate", %{"rating" => rating})
    render_click(lv, "rate", %{})

    assert Books.get_book!(scope, book.public_id).rating == nil
    lv |> element("#star-rating-4") |> render_click()
    assert Books.get_book!(scope, book.public_id).rating == 4
  end

  test "a long review suggests a title, which saves with the next change", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))

    sync_new(lv, String.duplicate("A", 350))

    refute has_element?(lv, "#title-field.d-none")
    refute has_element?(lv, "#slug-field.d-none")
    assert has_element?(lv, ~s(#post_title[value="Review: Clean Code"]))

    lv
    |> form("#review-form", post: %{title: "Why Clean Code Changed My Life"})
    |> render_change()

    book = Books.get_book!(scope, book.public_id)
    assert Books.get_review_post(scope, book).title == "Why Clean Code Changed My Life"
  end

  test "the rating belongs to the book: it saves at once and is not versioned", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))
    lv |> element("#star-rating-5") |> render_click()

    assert has_element?(lv, "#star-rating-5.filled")
    assert Books.get_book!(scope, book.public_id).rating == 5
    refute Books.get_book!(scope, book.public_id).post_id

    {:ok, %{book: book, post: post}} = Books.create_review(scope, book, %{title: "My Review"})
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))
    assert has_element?(lv, "#star-rating-5.filled")

    lv |> element("#star-rating-3") |> render_click()

    assert Books.get_book!(scope, book.public_id).rating == 3
    assert Feather.Repo.reload!(post).lock_version == post.lock_version
    assert Content.list_versions(scope, post) == []
  end

  test "edits a review", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, %{book: book, post: post}} =
      Books.create_review(scope, book, %{title: "My Review", content: [paragraph("Good")]})

    [%{"id" => id}] = post.content
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))

    lv |> form("#review-form", post: %{title: "Updated Review Title"}) |> render_change()

    lv
    |> element("#review-content-editor")
    |> render_hook("sync", sync_params(post, nil, [paragraph_node(id, "Even better")]))

    assert_reply(lv, %{status: "saved"})
    post = Books.get_review_post(scope, book)
    assert post.title == "Updated Review Title"
    assert [%{"text" => "Even better"}] = post.content
  end

  test "an invalid field of a review is not saved", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, %{book: book}} = Books.create_review(scope, book, %{title: "Mine", slug: "/mine"})
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))

    lv |> form("#review-form", post: %{title: "New", slug: "/posts/x"}) |> render_change()

    assert has_element?(lv, "#slug-field .invalid-feedback", "is reserved")
    assert has_element?(lv, "#publish-review[disabled]")
    assert %{title: "New", slug: "/mine"} = Books.get_review_post(scope, book)
  end

  test "unpublishes a review", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, %{post: post}} = Books.create_review(scope, book, %{title: "My Review", content: []})
    {:ok, post} = Content.publish(scope, post)
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))
    assert has_element?(lv, "#status-badge", "Published")
    refute has_element?(lv, "#post_draft")

    lv |> element("#unpublish-review") |> render_click()

    assert has_element?(lv, "#status-badge", "Draft")
    assert Content.draft?(Content.get_post!(scope, post.public_id))
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

  test "a new review is a draft until it is published", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, lv, _html} = live(conn, review_path(site, book, "new"))
    sync_new(lv, "Worth it.")
    post = Books.get_review_post(scope, Books.get_book!(scope, book.public_id))
    assert Content.draft?(post)

    html =
      lv |> element("#review-content-editor") |> render_hook("publish", %{"editor" => "saved"})

    assert html =~ "Review was published."
    assert Content.publication_status(Content.get_post!(scope, post.public_id)) == :published
  end

  test "publishes and discards the changes of a review", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, %{post: post}} = Books.create_review(scope, book, %{title: "First take"})
    assert Content.draft?(post)
    {:ok, _post} = Content.publish(scope, post)

    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))
    assert has_element?(lv, "#version-1", "Published")
    refute has_element?(lv, "#discard-review")

    lv |> form("#review-form", post: %{title: "Second take"}) |> render_change()
    lv |> element("#review-content-editor") |> render_hook("publish", %{"editor" => "saved"})

    assert has_element?(lv, "#version-2", "Published")

    book = Books.get_book!(scope, book.public_id)
    post = Books.get_review_post(scope, book)
    {:ok, _post} = Content.update_post(scope, post, %{title: "Third take"})
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))
    assert has_element?(lv, "#status-badge", "Unpublished changes")

    {:ok, lv, _html} =
      lv
      |> element("#discard-review")
      |> render_click()
      |> follow_redirect(conn, review_path(site, book, "edit"))

    assert has_element?(lv, "#status-badge", "Published")
    assert Books.get_review_post(scope, book).title == "Second take"
  end

  test "restores an earlier version of a review", %{
    conn: conn,
    site: site,
    scope: scope,
    book: book
  } do
    {:ok, %{post: post}} = Books.create_review(scope, book, %{title: "First take"})
    {:ok, post} = Content.publish(scope, post)
    {:ok, post} = Content.update_post(scope, post, %{title: "Second take"})
    {:ok, _post} = Content.publish(scope, post)
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))

    {:ok, lv, _html} =
      lv
      |> element("#restore-version-1")
      |> render_click()
      |> follow_redirect(conn, review_path(site, book, "edit"))

    assert has_element?(lv, "#status-badge", "Unpublished changes")
    book = Books.get_book!(scope, book.public_id)
    assert Books.get_review_post(scope, book).title == "First take"
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

  test "autosaves the content of a review", %{conn: conn, site: site, scope: scope, book: book} do
    {:ok, %{post: post}} = Books.create_review(scope, book, %{content: [paragraph("Good")]})
    [%{"id" => id}] = post.content
    {:ok, lv, _html} = live(conn, review_path(site, book, "edit"))

    lv
    |> element("#review-content-editor")
    |> render_hook("sync", sync_params(post, nil, [paragraph_node(id, "Very good")]))

    assert_reply(lv, %{status: "saved"})
    assert [%{"text" => "Very good"}] = Feather.Repo.reload!(post).content
  end
end
