defmodule FeatherWeb.PostLiveTest do
  # Ports features/posts.feature and the post parts of book_reviews.feature.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorJsHelpers

  alias Feather.{Books, Content}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp posts_path(site), do: ~p"/sites/#{site.public_id}/posts"

  describe "index" do
    test "shows an empty state", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, posts_path(site))
      assert has_element?(lv, "#no-posts")
      assert has_element?(lv, "#site-title", site.title)
      assert has_element?(lv, "#site-navigation a.active", "Posts")
    end

    test "lists posts newest first with draft badge, tags and excerpts", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      old = post_fixture(scope, title: "Old post", publish_at: ~U[2020-01-01 10:00:00Z])

      new =
        post_fixture(scope,
          title: "New post",
          draft: true,
          tags: "elixir, phoenix",
          publish_at: ~U[2024-01-01 10:00:00Z]
        )

      short =
        post_fixture(scope,
          title: nil,
          slug: nil,
          content: [paragraph("Just a short thought")],
          publish_at: ~U[2023-01-01 10:00:00Z]
        )

      {:ok, lv, html} = live(conn, posts_path(site))

      assert has_element?(lv, "#post-#{new.public_id}", "New post")
      assert has_element?(lv, "#post-#{new.public_id} .list-row__badge--draft")
      assert has_element?(lv, "#post-#{new.public_id} .list-row__tag", "phoenix")
      assert has_element?(lv, "#post-#{old.public_id} .list-row__badge--published")
      assert has_element?(lv, "#post-#{short.public_id}", "Just a short thought")

      [first, second, third] =
        Regex.scan(~r/id="post-([^"]+)"/, html) |> Enum.map(&List.last/1)

      assert [first, second, third] == [new.public_id, short.public_id, old.public_id]
    end

    test "paginates 20 posts per page", %{conn: conn, site: site, scope: scope} do
      for _ <- 1..25, do: post_fixture(scope)

      {:ok, lv, _html} = live(conn, posts_path(site))
      assert has_element?(lv, "#pagination")
      assert lv |> element("#posts") |> render() |> count_rows() == 20

      lv |> element("#pagination a", "2") |> render_click()
      assert_patch(lv, posts_path(site) <> "?page=2")
      assert lv |> element("#posts") |> render() |> count_rows() == 5
    end

    test "deletes a post", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Unwanted Post")
      {:ok, lv, _html} = live(conn, posts_path(site))

      lv |> element("#delete-post-#{post.public_id}") |> render_click()

      refute has_element?(lv, "#post-#{post.public_id}")
      assert render(lv) =~ "Post was successfully deleted."
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(scope, post.public_id) end
    end

    test "marks book reviews, also short ones", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope, title: "Clean Code")

      {:ok, %{post: post}} =
        Books.create_review(scope, book, %{title: nil, slug: nil, content: []})

      {:ok, _book} = Books.update_book(scope, %{book | post_id: post.id}, %{rating: 4})

      {:ok, lv, _html} = live(conn, posts_path(site))
      assert has_element?(lv, "#post-#{post.public_id} .list-row__badge--review", "Clean Code")
      assert has_element?(lv, "#post-#{post.public_id}", "★★★★☆")
    end

    test "deleting a review post from the list removes the review", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      book = book_fixture(scope, title: "Clean Code")

      {:ok, %{post: post}} =
        Books.create_review(scope, book, %{title: "My Clean Code Review", content: []})

      {:ok, lv, _html} = live(conn, posts_path(site))
      assert has_element?(lv, "#post-#{post.public_id}", "My Clean Code Review")
      lv |> element("#delete-post-#{post.public_id}") |> render_click()

      refute Books.get_book!(scope, book.public_id).post_id
    end

    test "another user's site is not found", %{conn: conn} do
      other_site = site_fixture(nil, title: "Not mine")

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, posts_path(other_site))
      end
    end
  end

  describe "new" do
    test "creates a post with a title", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")

      {:ok, _lv, html} =
        lv
        |> form("#post-form", post: %{title: "My First Post"})
        |> render_submit(%{"post" => %{"content" => editor_json("Hello")}})
        |> follow_redirect(conn, posts_path(site))

      assert html =~ "Post was successfully created."
      assert html =~ "My First Post"

      [post] = Content.list_posts(scope)
      assert post.title == "My First Post"
      assert [%{"type" => "paragraph", "text" => "Hello"}] = post.content
    end

    test "creates a post with a custom slug", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")

      lv
      |> form("#post-form", post: %{title: "Hello World", slug: "/hello-world-2024"})
      |> render_submit()

      assert Content.get_post_by_slug(scope, "/hello-world-2024")
    end

    test "suggests a free slug from the title until the slug is edited", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post_fixture(scope, slug: "/hello-world")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")

      lv
      |> element("#post-form")
      |> render_change(%{"post" => %{"title" => "Hello World"}, "_target" => ["post", "title"]})

      assert has_element?(lv, ~s(#post_slug[value="/hello-world1"]))

      lv
      |> element("#post-form")
      |> render_change(%{
        "post" => %{"title" => "Hello World", "slug" => "/mine"},
        "_target" => ["post", "slug"]
      })

      lv
      |> element("#post-form")
      |> render_change(%{
        "post" => %{"title" => "Hello again", "slug" => "/mine"},
        "_target" => ["post", "title"]
      })

      assert has_element?(lv, ~s(#post_slug[value="/mine"]))
    end

    test "hides title and slug for short posts and shows them from 300 characters", %{
      conn: conn,
      site: site
    } do
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")
      assert has_element?(lv, "#title-field.d-none")
      assert has_element?(lv, "#slug-field.d-none")
      assert has_element?(lv, "#content-length", "0 / 300")

      lv
      |> element("#post-form")
      |> render_change(%{"post" => %{"content" => editor_json(String.duplicate("a", 299))}})

      assert has_element?(lv, "#title-field.d-none")
      assert has_element?(lv, "#slug-field.d-none")

      lv
      |> element("#post-form")
      |> render_change(%{"post" => %{"content" => editor_json(String.duplicate("a", 300))}})

      refute has_element?(lv, "#title-field.d-none")
      refute has_element?(lv, "#slug-field.d-none")
      assert has_element?(lv, "#content-length", "300 / 300")
    end

    test "creates a short post without title", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")

      lv
      |> form("#post-form")
      |> render_submit(%{"post" => %{"content" => editor_json("Short and sweet")}})

      [post] = Content.list_posts(scope)
      assert post.title == nil
      assert post.slug == nil
    end

    test "shows validation errors", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")

      html =
        lv
        |> form("#post-form", post: %{title: "Bad", slug: "/posts/reserved"})
        |> render_submit()

      assert html =~ "is reserved"
    end

    test "saves a book block", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope, title: "The Great Gatsby")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")

      content =
        editor_blocks_json([
          %{
            "type" => "book",
            "data" => %{
              "book_public_id" => book.public_id,
              "title" => book.title,
              "author" => book.author
            }
          }
        ])

      lv
      |> form("#post-form", post: %{title: "My Book Review"})
      |> render_submit(%{"post" => %{"content" => content}})

      [post] = Content.list_posts(scope)
      assert [%{"type" => "book", "book_public_id" => public_id}] = post.content
      assert public_id == book.public_id
    end
  end

  describe "edit" do
    test "changes the title", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Draft Post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      assert has_element?(lv, "#post-content-editor[phx-hook=EditorJs][phx-update=ignore]")
      refute has_element?(lv, "#title-field.d-none")
      refute has_element?(lv, "#slug-field.d-none")

      lv
      |> form("#post-form", post: %{title: "Published Post"})
      |> render_submit()

      assert Content.get_post!(scope, post.public_id).title == "Published Post"
    end

    test "sets the publish date", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Scheduled Post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      lv
      |> form("#post-form", post: %{publish_at: "2024-12-25T09:30"})
      |> render_submit()

      assert DateTime.to_date(Content.get_post!(scope, post.public_id).publish_at) ==
               ~D[2024-12-25]
    end

    test "keeps the content when it is not changed", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, content: [paragraph("Keep me")])
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      lv |> form("#post-form") |> render_submit()

      assert [%{"text" => "Keep me"}] = Content.get_post!(scope, post.public_id).content
    end

    test "sanitizes inline HTML before it is stored and handed to the editor", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope)
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      payload = ~S|<img src=x onerror="window.__xss=1"><b>bold</b> <a href="/x">link</a>|

      lv
      |> form("#post-form")
      |> render_submit(%{"post" => %{"content" => editor_json(payload)}})

      assert [%{"text" => ~S|<b>bold</b> <a href="/x">link</a>|}] =
               Content.get_post!(scope, post.public_id).content

      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      [data] =
        lv
        |> element("#post-content-editor-input")
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.attribute("value")

      refute data =~ "onerror"
      assert data =~ "<b>bold</b>"
    end

    test "shows the title, status and a link back to the posts", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, title: "Draft Post", draft: true)
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      assert has_element?(lv, "h1", "Draft Post")
      assert has_element?(lv, "#status-badge", "Draft")
      assert has_element?(lv, ~s(#back-link[href="#{posts_path(site)}"]), "Posts")
      assert has_element?(lv, "#post-details #post_slug[form=post-form]")
      assert has_element?(lv, "#post-details .form-switch #post_draft")
      assert has_element?(lv, "#action-bar #save-post[form=post-form]", "Save")
    end

    test "shows the details card open after a failed save", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, title: "A post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")
      refute has_element?(lv, "#post-details.is-open")

      lv |> form("#post-form", post: %{slug: "/posts/reserved"}) |> render_submit()
      assert has_element?(lv, "#post-details.is-open")
    end

    test "deletes the post", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Unwanted Post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      {:ok, _lv, html} =
        lv
        |> element("#delete-post")
        |> render_click()
        |> follow_redirect(conn, posts_path(site))

      assert html =~ "Post was successfully deleted."
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(scope, post.public_id) end
    end

    test "a post of another site is not found", %{conn: conn, site: site} do
      other_post = post_fixture(site_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, posts_path(site) <> "/#{other_post.public_id}/edit")
      end
    end
  end

  describe "site notices" do
    test "shows notices broadcast for the site", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, posts_path(site))

      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        Feather.Publishing.notices_topic(site),
        {:site_notice, %{message: "Deployed to production", url: "https://example.com"}}
      )

      assert has_element?(lv, "#site-notices", "Deployed to production")
      assert has_element?(lv, ~s(#site-notices a[href="https://example.com"]))

      lv |> element("#site-notices .btn-close") |> render_click()
      refute has_element?(lv, "#site-notices", "Deployed to production")
    end

    test "shows the preview button for the internal staging target", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = Feather.Publishing.get_staging_target(scope)
      {:ok, lv, _html} = live(conn, posts_path(site))
      assert has_element?(lv, ~s(#site-preview-link[href="/preview/#{target.public_id}"]))
    end
  end

  defp count_rows(html) do
    html |> LazyHTML.from_fragment() |> LazyHTML.query(".list-row") |> Enum.count()
  end
end
