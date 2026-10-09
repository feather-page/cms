defmodule FeatherWeb.PostLiveTest do
  # Ports features/posts.feature and the post parts of book_reviews.feature.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorHelpers

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
      assert has_element?(lv, "#post-#{new.public_id} .badge", "Draft")
      assert has_element?(lv, "#post-#{new.public_id} .list-row__tag", "phoenix")
      assert has_element?(lv, "#post-#{old.public_id} .badge", "Published")
      assert has_element?(lv, "#post-#{short.public_id}", "Just a short thought")

      # The whole row links to the editor; deleting needs no menu.
      assert has_element?(
               lv,
               ~s(#post-#{old.public_id} a.stretched-link[href="#{posts_path(site)}/#{old.public_id}/edit"])
             )

      refute has_element?(lv, "#post-#{old.public_id}-menu-toggle")

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
      assert has_element?(lv, "#post-#{post.public_id} .list-row__review", "Clean Code")
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
    defp new_post(conn, site), do: live(conn, posts_path(site) <> "/new")

    defp created_post(scope) do
      [post] = Content.list_posts(scope)
      post
    end

    test "the first input creates the post as a draft and goes on as its edit view", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = new_post(conn, site)
      refute has_element?(lv, "#post-content-editor[data-lock-version]")
      assert has_element?(lv, "#publish-post[disabled]")
      assert Content.list_posts(scope) == []

      lv |> form("#post-form", post: %{title: "My First Post"}) |> render_change()

      post = created_post(scope)
      assert post.title == "My First Post"
      assert Content.draft?(post)
      # the editor has no counter yet and learns it from the event
      lock_version = post.lock_version
      assert_push_event(lv, "lock_version", %{lock_version: ^lock_version})
      assert_patch(lv, posts_path(site) <> "/#{post.public_id}/edit")
      assert has_element?(lv, "h1", "My First Post")
      assert has_element?(lv, ~s(#post-content-editor[data-lock-version="#{post.lock_version}"]))
      assert has_element?(lv, "#status-badge", "Draft")

      lv |> form("#post-form", post: %{title: "My First Post!"}) |> render_change()
      assert [%{title: "My First Post!"}] = Content.list_posts(scope)
    end

    test "the first sync of the editor creates the post with its content", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = new_post(conn, site)

      lv
      |> element("#post-content-editor")
      |> render_hook("sync", %{
        "lock_version" => nil,
        "order" => ["block00001"],
        "blocks" => [paragraph_node("block00001", "Hello")]
      })

      post = created_post(scope)
      lock_version = post.lock_version
      assert_reply(lv, %{status: "saved", lock_version: ^lock_version})
      assert [%{"type" => "paragraph", "text" => "Hello", "id" => "block00001"}] = post.content
      assert {post.title, post.slug} == {nil, nil}
      assert_patch(lv, posts_path(site) <> "/#{post.public_id}/edit")
    end

    test "a malformed first sync is refused", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = new_post(conn, site)

      lv
      |> element("#post-content-editor")
      |> render_hook("sync", %{
        "lock_version" => nil,
        "order" => ["block00001"],
        "blocks" => ["junk", %{"attrs" => "x"}, nil]
      })

      assert_reply(lv, %{status: _status})
      assert render(lv) =~ "post-content-editor"
    end

    test "suggests a free slug from the title until the slug is edited", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post_fixture(scope, slug: "/hello-world")
      {:ok, lv, _html} = new_post(conn, site)

      lv
      |> element("#post-form")
      |> render_change(%{"post" => %{"title" => "Hello World"}, "_target" => ["post", "title"]})

      assert has_element?(lv, ~s(#post_slug[value="/hello-world1"]))
      assert Content.get_post_by_slug(scope, "/hello-world1")

      lv
      |> element("#post-form")
      |> render_change(%{
        "post" => %{"title" => "Hello World "},
        "_target" => ["post", "title"]
      })

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
      assert Content.get_post_by_slug(scope, "/mine").title == "Hello again"
    end

    test "hides title and slug for short posts and shows them from 300 characters", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = new_post(conn, site)
      assert has_element?(lv, "#title-field.d-none")
      assert has_element?(lv, "#slug-field.d-none")
      assert has_element?(lv, "#content-length", "0 / 300")

      sync = fn lock_version, text ->
        lv
        |> element("#post-content-editor")
        |> render_hook("sync", %{
          "lock_version" => lock_version,
          "order" => nil,
          "blocks" => [paragraph_node("block00001", text)]
        })
      end

      sync.(nil, String.duplicate("a", 299))
      assert_reply(lv, %{status: "saved"})
      assert has_element?(lv, "#title-field.d-none")
      assert has_element?(lv, "#slug-field.d-none")

      sync.(created_post(scope).lock_version, String.duplicate("a", 300))
      assert_reply(lv, %{status: "saved"})
      refute has_element?(lv, "#title-field.d-none")
      refute has_element?(lv, "#slug-field.d-none")
      assert has_element?(lv, "#content-length", "300 / 300")
    end

    test "an invalid field shows its error and the valid ones are saved", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = new_post(conn, site)

      lv
      |> form("#post-form", post: %{title: "Bad", slug: "/posts/reserved"})
      |> render_change()

      assert has_element?(lv, "#slug-field .invalid-feedback", "is reserved")
      assert has_element?(lv, ~s(#post-content-editor[data-form-status="invalid"]))
      assert has_element?(lv, "#post-details.is-open")
      assert %{title: "Bad", slug: nil} = created_post(scope)
    end

    test "saves a book block", %{conn: conn, site: site, scope: scope} do
      book = book_fixture(scope, title: "The Great Gatsby")
      {:ok, lv, _html} = new_post(conn, site)

      book_node = %{
        "type" => "book",
        "attrs" => %{
          "id" => "block00001",
          "book_public_id" => book.public_id,
          "title" => book.title,
          "author" => book.author
        }
      }

      lv
      |> element("#post-content-editor")
      |> render_hook("sync", %{"lock_version" => nil, "order" => nil, "blocks" => [book_node]})

      assert [%{"type" => "book", "book_public_id" => public_id}] = created_post(scope).content
      assert public_id == book.public_id
    end
  end

  describe "edit" do
    test "changes the title", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Draft Post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      assert has_element?(lv, "#post-content-editor[phx-hook=ProseMirror]")

      assert has_element?(
               lv,
               "#post-content-editor > #post-content-editor-document[phx-update=ignore]"
             )

      refute has_element?(lv, "#title-field.d-none")
      refute has_element?(lv, "#slug-field.d-none")

      lv |> form("#post-form", post: %{title: "Published Post"}) |> render_change()

      assert Content.get_post!(scope, post.public_id).title == "Published Post"
      assert has_element?(lv, ~s(#post-content-editor[data-form-status="saved"]))
    end

    test "the editor gets the site's image endpoints", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope)
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      editor = "#post-content-editor"

      assert has_element?(
               lv,
               ~s(#{editor}[data-image-upload-url="/sites/#{site.public_id}/images"])
             )

      assert has_element?(
               lv,
               ~s(#{editor}[data-image-from-url-url="/sites/#{site.public_id}/images/from-url"])
             )

      assert has_element?(lv, "#{editor}[data-csrf-token]")
    end

    test "the editor gets the site's book lookup", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope)
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      assert has_element?(
               lv,
               ~s(#post-content-editor[data-book-lookup-url="/sites/#{site.public_id}/books/lookup"])
             )
    end

    test "sets the publish date", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Scheduled Post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      lv |> form("#post-form", post: %{publish_at: "2024-12-25T09:30"}) |> render_change()

      assert DateTime.to_date(Content.get_post!(scope, post.public_id).publish_at) ==
               ~D[2024-12-25]
    end

    test "keeps the content when it is not changed", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, content: [paragraph("Keep me")])
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      lv |> form("#post-form", post: %{title: "New title"}) |> render_change()

      assert [%{"text" => "Keep me"}] = Content.get_post!(scope, post.public_id).content
    end

    test "sanitizes inline HTML before it is stored and handed to the editor", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, content: [paragraph("Old")])
      [%{"id" => id}] = post.content
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      node = %{
        "type" => "paragraph",
        "attrs" => %{"id" => id},
        "content" => [
          %{"type" => "text", "text" => ~S|<img src=x onerror="x()">|},
          %{"type" => "text", "text" => "bold", "marks" => [%{"type" => "bold"}]},
          %{
            "type" => "text",
            "text" => "link",
            "marks" => [%{"type" => "link", "attrs" => %{"href" => "javascript:x()"}}]
          }
        ]
      }

      lv |> element("#post-content-editor") |> render_hook("sync", sync_params(post, nil, [node]))

      assert [%{"text" => ~S|&lt;img src=x onerror="x()"&gt;<b>bold</b><a>link</a>|}] =
               Content.get_post!(scope, post.public_id).content

      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")

      [data] =
        lv
        |> element("#post-content-editor-document")
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.attribute("data-doc")

      assert %{"content" => [%{"content" => [_text, bold, _link]}]} = Jason.decode!(data)
      assert bold["marks"] == [%{"type" => "bold"}]
      refute data =~ "javascript:"
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
      refute has_element?(lv, "#post_draft")
      refute has_element?(lv, "#unpublish-post")
      assert has_element?(lv, "#action-bar #publish-post")
      refute has_element?(lv, "#save-post")
    end

    test "unpublishes a published post and keeps its unpublished changes", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, title: "Live post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")
      assert has_element?(lv, "#status-badge", "Published")

      lv |> form("#post-form", post: %{title: "Edited title"}) |> render_change()
      lv |> element("#unpublish-post") |> render_click()

      assert has_element?(lv, "#status-badge", "Draft")
      refute has_element?(lv, "#unpublish-post")
      assert has_element?(lv, "#post_title[value='Edited title']")

      post = Content.get_post!(scope, post.public_id)
      assert Content.draft?(post)
      assert post.title == "Edited title"
    end

    test "shows the details card open while a field is invalid", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, title: "A post")
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/#{post.public_id}/edit")
      refute has_element?(lv, "#post-details.is-open")

      lv |> form("#post-form", post: %{slug: "/posts/reserved"}) |> render_change()
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

  describe "publishing" do
    defp edit_path(site, post), do: posts_path(site) <> "/#{post.public_id}/edit"

    defp post_at_version_3(scope) do
      post = post_fixture(scope, title: "Version 1")

      Enum.reduce(2..3, post, fn n, post ->
        {:ok, post} = Content.update_post(scope, post, %{title: "Version #{n}"})
        {:ok, post} = Content.publish(scope, post)
        post
      end)
    end

    test "a change keeps the published version and shows the unpublished changes", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      assert has_element?(lv, "#status-badge", "Published")
      refute has_element?(lv, "#discard-post")

      lv
      |> element("#post-content-editor")
      |> render_hook(
        "sync",
        sync_params(post, ["block00001"], [paragraph_node("block00001", "Changed")])
      )

      assert has_element?(lv, "#status-badge", "Unpublished changes")
      assert has_element?(lv, "#discard-post")

      {:ok, list, _html} = live(conn, posts_path(site))
      assert has_element?(list, "#post-#{post.public_id} .badge", "Unpublished changes")

      [published] = Content.as_published([Content.get_post!(scope, post.public_id)])
      assert published.title == "Version 3"
      refute published.content == [paragraph("Changed")]
    end

    test "publishing creates a new version of the saved changes", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      lv |> form("#post-form", post: %{title: "Version 4"}) |> render_change()

      html =
        lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

      assert html =~ "Post was published."
      assert has_element?(lv, "#status-badge", "Published")
      assert has_element?(lv, "#version-4", "Published")
      assert has_element?(lv, "#version-3")
      assert has_element?(lv, "#version-4", scope.user.email)

      post = Content.get_post!(scope, post.public_id)
      assert post.title == "Version 4"
      assert [%{number: 4, id: id} | _] = Content.list_versions(scope, post)
      assert post.published_version_id == id
    end

    # Scenario: Publishing is blocked by an invalid field
    test "an invalid field is not saved and blocks publishing until it is valid", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post_fixture(scope, slug: "/taken")
      post = post_at_version_3(scope)
      {:ok, post} = Content.update_post(scope, post, %{title: "Unpublished", slug: "/mine"})
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      assert has_element?(lv, "#status-badge", "Unpublished changes")

      lv |> form("#post-form", post: %{slug: "/taken"}) |> render_change()

      assert has_element?(lv, "#slug-field .invalid-feedback", "has already been taken")
      assert has_element?(lv, ~s(#post-content-editor[data-form-status="invalid"]))
      assert Content.get_post!(scope, post.public_id).slug == "/mine"

      assert has_element?(lv, "#publish-post[disabled]")
      html = render_hook(lv, "publish", %{})
      assert html =~ "Not published: fix the marked fields first."
      assert [%{number: 3} | _] = Content.list_versions(scope, post)

      lv |> form("#post-form", post: %{slug: "/free"}) |> render_change()
      refute has_element?(lv, "#publish-post[disabled]")
      lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

      post = Content.get_post!(scope, post.public_id)
      assert post.slug == "/free"
      assert [%{number: 4, slug: "/free"} | _] = Content.list_versions(scope, post)
    end

    test "discards the unpublished changes", %{conn: conn, site: site, scope: scope} do
      post = post_at_version_3(scope)
      {:ok, _post} = Content.update_post(scope, post, %{title: "Unpublished"})
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      {:ok, lv, html} =
        lv
        |> element("#discard-post")
        |> render_click()
        |> follow_redirect(conn, edit_path(site, post))

      assert html =~ "Changes were discarded."
      assert has_element?(lv, "#status-badge", "Published")
      assert has_element?(lv, "#post_title[value='Version 3']")
      assert Content.get_post!(scope, post.public_id).title == "Version 3"
    end

    test "restores an earlier version into the unpublished changes", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      refute has_element?(lv, "#restore-version-3")

      {:ok, lv, html} =
        lv
        |> element("#restore-version-2")
        |> render_click()
        |> follow_redirect(conn, edit_path(site, post))

      assert html =~ "Version 2 was restored."
      assert has_element?(lv, "#post_title[value='Version 2']")
      assert has_element?(lv, "#status-badge", "Unpublished changes")
      assert has_element?(lv, "#version-3", "Published")

      [published] = Content.as_published([Content.get_post!(scope, post.public_id)])
      assert published.title == "Version 3"
    end

    test "shows why a version could not be restored", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, title: "Old", slug: "/taken")
      {:ok, post} = Content.update_post(scope, post, %{slug: "/moved"})
      {:ok, post} = Content.publish(scope, post)
      post_fixture(scope, slug: "/taken")
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      html = lv |> element("#restore-version-1") |> render_click()

      assert html =~ "Version 1 could not be restored: slug has already been taken."
      assert Content.get_post!(scope, post.public_id).slug == "/moved"
    end

    test "shows why the changes could not be discarded", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, slug: "/taken")
      {:ok, post} = Content.update_post(scope, post, %{slug: "/moved"})
      post_fixture(scope, slug: "/taken", draft: true)
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      html = lv |> element("#discard-post") |> render_click()

      assert html =~ "The changes could not be discarded: slug has already been taken."
      assert Content.get_post!(scope, post.public_id).slug == "/moved"
    end

    defp publish(lv),
      do: lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

    test "does not publish a slug another post is published with", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      other = post_fixture(scope, slug: "/taken")
      {:ok, _other} = Content.update_post(scope, other, %{slug: "/moved"})
      post = post_fixture(scope, slug: "/taken", draft: true)
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      assert publish(lv) =~ "Not published: another post is published with this slug."
      assert Content.draft?(Content.get_post!(scope, post.public_id))
    end

    test "Publish lets the editor send its pending edits first", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      assert has_element?(lv, ~s(#publish-post[phx-click*="feather:publish"]))
      refute has_element?(lv, ~s(#publish-post[phx-click*="push"]))

      html =
        lv
        |> element("#post-content-editor")
        |> render_hook("publish", %{"editor" => "unsaved"})

      assert html =~ "Not published: the content is not saved yet."
      assert [%{number: 3} | _] = Content.list_versions(scope, post)
    end

    test "does not publish a post changed elsewhere", %{conn: conn, site: site, scope: scope} do
      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Elsewhere"})

      assert publish(lv) =~ "Not published: this was changed elsewhere"
      assert has_element?(lv, ~s(#post-content-editor[data-form-status="conflict"]))
      assert [%{number: 3} | _] = Content.list_versions(scope, post)
    end

    test "publishes a post unpublished elsewhere again", %{conn: conn, site: site, scope: scope} do
      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      {:ok, _elsewhere} = Content.unpublish(scope, post)

      assert publish(lv) =~ "Post was published."
      assert [%{number: 4, id: id} | _] = Content.list_versions(scope, post)
      assert Content.get_post!(scope, post.public_id).published_version_id == id
    end

    test "does not discard the changes of a post unpublished or changed elsewhere", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_at_version_3(scope)
      {:ok, post} = Content.update_post(scope, post, %{title: "Mine"})
      {:ok, lv, _html} = live(conn, edit_path(site, post))
      {:ok, _elsewhere} = Content.unpublish(scope, post)

      assert lv |> element("#discard-post") |> render_click() =~
               "The changes could not be discarded: it is not published."

      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Elsewhere"})

      assert lv |> element("#discard-post") |> render_click() =~
               "The changes could not be discarded: it was changed elsewhere"

      assert Content.get_post!(scope, post.public_id).title == "Elsewhere"
    end

    test "refuses crafted events instead of crashing", %{conn: conn, site: site, scope: scope} do
      {:ok, new, _html} = live(conn, posts_path(site) <> "/new")

      for {event, params} <- [
            {"discard", %{}},
            {"unpublish", %{}},
            {"restore", %{"number" => "1"}},
            {"publish", %{}}
          ],
          do: render_click(new, event, params)

      assert Content.list_posts(scope) == []

      post = post_at_version_3(scope)
      {:ok, lv, _html} = live(conn, edit_path(site, post))

      for params <- [%{"number" => "x"}, %{"number" => "99"}, %{"number" => "1.5"}, %{}] do
        assert render_click(lv, "restore", params) =~ "could not be restored"
      end

      draft = post_fixture(scope, title: "Draft", draft: true)
      {:ok, draft_lv, _html} = live(conn, edit_path(site, draft))
      assert render_click(draft_lv, "discard", %{}) =~ "it is not published"
      assert Content.get_post!(scope, post.public_id).title == "Version 3"
    end

    test "publishes a new post", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, posts_path(site) <> "/new")
      refute has_element?(lv, "#versions")

      lv |> form("#post-form", post: %{title: "Out now", slug: "/out-now"}) |> render_change()
      lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

      post = Content.get_post_by_slug(scope, "/out-now")
      assert Content.publication_status(post) == :published
      assert has_element?(lv, "#version-1", "Published")
    end
  end

  describe "autosave" do
    setup %{scope: scope} do
      post = post_fixture(scope, content: [paragraph("One"), paragraph("Two")])
      %{post: post, ids: Enum.map(post.content, & &1["id"])}
    end

    defp sync(lv, params) do
      lv |> element("#post-content-editor") |> render_hook("sync", params)
    end

    defp edit_post(conn, site, post),
      do: live(conn, posts_path(site) <> "/#{post.public_id}/edit")

    defp texts(scope, post),
      do: Enum.map(Content.get_post!(scope, post.public_id).content, & &1["text"])

    test "the editor builds on the post's counter and shows the save status", %{
      conn: conn,
      site: site,
      post: post
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)

      assert has_element?(lv, ~s(#post-content-editor[data-lock-version="#{post.lock_version}"]))
      assert has_element?(lv, ~s(#post-content-editor[data-form-status="saved"]))
      assert has_element?(lv, "#post-content-editor-status[phx-update=ignore]", "Saved")
      assert has_element?(lv, "#post-content-editor-reload[hidden]")
    end

    test "saves the changed blocks and replies with the new counter", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [_one, two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)

      sync(lv, sync_params(post, nil, [paragraph_node(two, "Two, edited")]))

      lock_version = post.lock_version + 1
      assert_reply(lv, %{status: "saved", lock_version: ^lock_version})
      assert texts(scope, post) == ["One", "Two, edited"]
      assert has_element?(lv, "#status-badge", "Unpublished changes")
    end

    test "an order alone rearranges the blocks", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)

      sync(lv, sync_params(post, [two, one], []))

      assert_reply(lv, %{status: "saved"})
      assert texts(scope, post) == ["Two", "One"]
    end

    test "a repeated sync leaves the same content", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)
      order = [two, one, "newBlock01"]
      blocks = [paragraph_node(one, "One!"), paragraph_node("newBlock01", "New")]

      sync(lv, sync_params(post, order, blocks))
      assert_reply(lv, %{status: "saved", lock_version: lock_version})

      sync(lv, sync_params(%{post | lock_version: lock_version}, order, blocks))
      assert_reply(lv, %{status: "saved", lock_version: ^lock_version})

      assert texts(scope, post) == ["Two", "One!", "New"]
    end

    test "a sync after the post changed elsewhere is rejected and saves nothing", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, _two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)
      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Changed elsewhere"})

      sync(lv, sync_params(post, nil, [paragraph_node(one, "Mine")]))

      assert_reply(lv, %{status: "stale"})
      assert texts(scope, post) == ["One", "Two"]
    end

    test "sanitizes unsafe HTML in a synced block", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, _two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)

      link = %{"type" => "link", "attrs" => %{"href" => "javascript:alert(1)"}}

      node = %{
        "type" => "paragraph",
        "attrs" => %{"id" => one},
        "content" => [%{"type" => "text", "text" => "Click", "marks" => [link]}]
      }

      sync(lv, sync_params(post, nil, [node]))

      assert_reply(lv, %{status: "saved"})
      assert [stored, "Two"] = texts(scope, post)
      assert stored =~ "Click"
      refute stored =~ "javascript:"
    end

    test "rejects a malformed sync", %{conn: conn, site: site, scope: scope, post: post} do
      {:ok, lv, _html} = edit_post(conn, site, post)

      for params <- [
            %{"lock_version" => "1", "order" => nil, "blocks" => []},
            %{"lock_version" => post.lock_version, "order" => [1], "blocks" => []},
            %{"lock_version" => post.lock_version, "order" => nil, "blocks" => %{}},
            %{}
          ] do
        sync(lv, params)
        assert_reply(lv, %{status: "invalid"})
      end

      assert texts(scope, post) == ["One", "Two"]
    end

    test "only reaches the edited post", %{conn: conn, site: site, post: post, ids: [one, two]} do
      other_scope = site_scope_fixture()
      other = post_fixture(other_scope, content: [paragraph("Other")])
      [%{"id" => other_id}] = other.content
      {:ok, lv, _html} = edit_post(conn, site, post)

      sync(lv, sync_params(post, [one, two, other_id], [paragraph_node(other_id, "Taken over")]))

      assert_reply(lv, %{status: "saved"})
      assert [%{"text" => "Other"}] = Feather.Repo.reload!(other).content
    end

    test "field saves and editor syncs of one view never conflict", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)
      sync(lv, sync_params(post, nil, [paragraph_node(one, "One!")]))
      assert_reply(lv, %{status: "saved", lock_version: synced})

      lv |> form("#post-form", post: %{title: "New title"}) |> render_change()
      saved = Content.get_post!(scope, post.public_id)
      assert {saved.title, saved.lock_version} == {"New title", post.lock_version + 2}
      assert has_element?(lv, ~s(#post-content-editor[data-lock-version="#{saved.lock_version}"]))

      # The editor has not seen the field save's counter yet.
      sync(lv, sync_params(%{post | lock_version: synced}, nil, [paragraph_node(two, "Two!")]))

      lock_version = post.lock_version + 3
      assert_reply(lv, %{status: "saved", lock_version: ^lock_version})
      assert texts(scope, post) == ["One!", "Two!"]
    end

    test "a field change after the post changed elsewhere is not saved", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)
      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Changed elsewhere"})

      lv |> form("#post-form", post: %{title: "Mine"}) |> render_change()

      assert has_element?(lv, ~s(#post-content-editor[data-form-status="conflict"]))
      assert has_element?(lv, "#publish-post[disabled]")
      assert Content.get_post!(scope, post.public_id).title == "Changed elsewhere"
    end

    # A no-op sync on a stale counter must not let the view build on the
    # other tab's counter.
    test "a sync after the post changed elsewhere is rejected even when it changes nothing", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, two]
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)
      lv |> form("#post-form", post: %{tags: "mine"}) |> render_change()

      {:ok, _elsewhere} =
        Content.update_post(scope, Feather.Repo.reload!(post), %{title: "Elsewhere"})

      sync(
        lv,
        sync_params(post, [one, two], [paragraph_node(one, "One"), paragraph_node(two, "Two")])
      )

      assert_reply(lv, %{status: "stale"})

      lv |> form("#post-form", post: %{tags: "mine, again"}) |> render_change()
      saved = Content.get_post!(scope, post.public_id)
      assert {saved.title, saved.tags} == {"Elsewhere", "mine"}
    end

    # A reconnect mounts the view again; the editor sends its last counter.
    test "after a remount a sync on the counter of the earlier view is saved unless the post changed elsewhere",
         %{conn: conn, site: site, scope: scope, post: post, ids: [one, two]} do
      {:ok, lv, _html} = edit_post(conn, site, post)
      lv |> form("#post-form", post: %{title: "Field save"}) |> render_change()
      handed_out = post.lock_version + 1
      assert_push_event(lv, "lock_version", %{lock_version: ^handed_out})

      {:ok, rejoined, _html} = edit_post(conn, site, post)

      sync(
        rejoined,
        sync_params(%{post | lock_version: handed_out}, nil, [paragraph_node(one, "One!")])
      )

      assert_reply(rejoined, %{status: "saved"})

      {:ok, _elsewhere} =
        Content.update_post(scope, Content.get_post!(scope, post.public_id), %{title: "Elsewhere"})

      {:ok, rejoined, _html} = edit_post(conn, site, post)

      sync(
        rejoined,
        sync_params(%{post | lock_version: handed_out + 1}, nil, [paragraph_node(two, "Mine")])
      )

      assert_reply(rejoined, %{status: "stale"})
      assert texts(scope, post) == ["One!", "Two"]
    end

    # LiveView sends the form's values from before a reconnect to the new
    # mount as "recover", with the counter the earlier view rendered.
    test "recovers the form after a reconnect unless the post changed elsewhere", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post
    } do
      {:ok, lv, _html} = edit_post(conn, site, post)
      assert has_element?(lv, ~s(#post-form[phx-auto-recover="recover"]))

      assert has_element?(
               lv,
               ~s(#post-form input[name="lock_version"][value="#{post.lock_version}"])
             )

      render_change(lv, "recover", %{
        "lock_version" => "#{post.lock_version}",
        "post" => %{"title" => "Typed offline"}
      })

      saved = Content.get_post!(scope, post.public_id)
      assert saved.title == "Typed offline"

      {:ok, _elsewhere} = Content.update_post(scope, saved, %{title: "Elsewhere"})
      {:ok, rejoined, _html} = edit_post(conn, site, post)

      render_change(rejoined, "recover", %{
        "lock_version" => "#{saved.lock_version}",
        "post" => %{"title" => "Typed offline"}
      })

      assert has_element?(rejoined, ~s(#post-content-editor[data-form-status="conflict"]))
      assert Content.get_post!(scope, post.public_id).title == "Elsewhere"
    end

    test "a sync on a counter from before the view was opened is rejected", %{
      conn: conn,
      site: site,
      scope: scope,
      post: post,
      ids: [one, _two]
    } do
      {:ok, post} = Content.update_post(scope, post, %{title: "Newer"})
      {:ok, lv, _html} = edit_post(conn, site, post)

      sync(
        lv,
        sync_params(%{post | lock_version: post.lock_version - 1}, nil, [
          paragraph_node(one, "Old tab")
        ])
      )

      assert_reply(lv, %{status: "stale"})
      assert has_element?(lv, ~s(#post-content-editor[data-form-status="conflict"]))
      assert texts(scope, post) == ["One", "Two"]
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
