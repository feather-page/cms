defmodule Feather.ContentTest do
  use Feather.DataCase

  alias Feather.{Content, Media, Sites}
  alias Feather.Content.{Page, Post, Project}

  setup do
    %{scope: site_scope_fixture()}
  end

  describe "slugs" do
    test "are normalized", %{scope: scope} do
      post = post_fixture(scope, slug: "hello/world/")
      assert post.slug == "/hello/world"
    end

    test "must match the slug format", %{scope: scope} do
      for slug <- ["/Hello", "/a b", "/a//b", "/ä", "/a_b"] do
        assert {:error, changeset} = Content.create_post(scope, %{title: "x", slug: slug})
        assert errors_on(changeset).slug != [], "expected #{slug} to be invalid"
      end
    end

    test "only the homepage may own the root", %{scope: scope} do
      assert {:error, changeset} = Content.create_post(scope, %{title: "x", slug: "/"})
      assert "is reserved for the homepage" in errors_on(changeset).slug

      assert {:error, changeset} =
               Content.create_project(scope, %{
                 title: "x",
                 slug: "/",
                 short_description: "d",
                 started_at: ~D[2024-01-01]
               })

      assert "is reserved for the homepage" in errors_on(changeset).slug

      # The site already has its homepage; a second page cannot take "/".
      assert {:error, changeset} = Content.create_page(scope, %{title: "x", slug: "/"})
      assert "has already been taken" in errors_on(changeset).slug
      assert Page.homepage?(Content.get_homepage(scope))
    end

    test "reserved paths are rejected for posts and pages", %{scope: scope} do
      for slug <- ~w(/images /page/2 /posts/x /projects /feed.xml /robots.txt /sitemap.xml) do
        assert {:error, changeset} = Content.create_post(scope, %{title: "x", slug: slug})
        assert "is reserved" in errors_on(changeset).slug, "post #{slug}"

        assert {:error, changeset} = Content.create_page(scope, %{title: "x", slug: slug})
        assert "is reserved" in errors_on(changeset).slug, "page #{slug}"
      end
    end

    test "projects live under projects/ and may use reserved names", %{scope: scope} do
      project = project_fixture(scope, slug: "/posts")
      assert project.slug == "/posts"
    end

    test "post slugs are optional but unique per site", %{scope: scope} do
      {:ok, a} = Content.create_post(scope, %{title: "a", slug: ""})
      {:ok, b} = Content.create_post(scope, %{title: "b"})
      assert a.slug == nil and b.slug == nil

      post_fixture(scope, slug: "/same")
      assert {:error, changeset} = Content.create_post(scope, %{title: "c", slug: "/same"})
      assert "has already been taken" in errors_on(changeset).slug

      other = site_scope_fixture()
      assert {:ok, _} = Content.create_post(other, %{title: "c", slug: "/same"})
    end

    test "pages and projects require a slug", %{scope: scope} do
      assert {:error, changeset} = Content.create_page(scope, %{title: "x"})
      assert "can't be blank" in errors_on(changeset).slug
    end

    test "suggest_slug/2 avoids taken and reserved slugs", %{scope: scope} do
      assert Content.suggest_slug(scope, "Hello World") == "/hello-world"
      post_fixture(scope, slug: "/hello-world")
      page_fixture(scope, slug: "/hello-world1")
      assert Content.suggest_slug(scope, "Hello World") == "/hello-world2"
      assert Content.suggest_slug(scope, "Images") == "/images1"
      assert Content.suggest_slug(scope, "") == ""
    end
  end

  describe "tags and emoji" do
    test "tags are normalized", %{scope: scope} do
      post = post_fixture(scope, tags: "Elixir, phoenix, ELIXIR")
      assert post.tags == "elixir, phoenix"
      assert Content.tag_list(post) == ["elixir", "phoenix"]
    end

    test "emoji must be emoji or blank", %{scope: scope} do
      assert {:error, changeset} = Content.create_post(scope, %{title: "x", emoji: "x"})
      assert "must be an emoji" in errors_on(changeset).emoji

      assert post_fixture(scope, emoji: "📘").emoji == "📘"
      assert post_fixture(scope, emoji: "  ").emoji == nil
      assert page_fixture(scope, emoji: "👩‍💻").emoji == "👩‍💻"
    end
  end

  describe "posts" do
    test "publish_at defaults to now", %{scope: scope} do
      post = post_fixture(scope)
      assert DateTime.diff(DateTime.utc_now(), post.publish_at) in 0..5
    end

    test "published posts are not drafts and not scheduled", %{scope: scope} do
      published = post_fixture(scope, title: "published")
      _draft = post_fixture(scope, title: "draft", draft: true)

      _scheduled =
        post_fixture(scope,
          title: "scheduled",
          publish_at: DateTime.add(DateTime.utc_now(), 3600)
        )

      past = post_fixture(scope, title: "past", publish_at: ~U[2020-01-01 10:00:00Z])

      assert Enum.map(Content.list_published_posts(scope), & &1.title) == ["published", "past"]
      assert Post.published?(published)
      assert Post.published?(past)
      assert length(Content.list_posts(scope)) == 4
    end

    test "posts are scoped to their site", %{scope: scope} do
      post = post_fixture(scope)
      other = site_scope_fixture()

      assert Content.get_post!(scope, post.public_id).id == post.id
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(other, post.public_id) end
      assert_raise FunctionClauseError, fn -> Content.update_post(other, post, %{title: "x"}) end
    end

    test "content accepts the internal format, Editor.js maps and JSON", %{scope: scope} do
      blocks = [%{"id" => "p1", "type" => "paragraph", "text" => "Hi"}]

      editor_js = %{
        "blocks" => [%{"id" => "p1", "type" => "paragraph", "data" => %{"text" => "Hi"}}]
      }

      assert post_fixture(scope, content: blocks).content == blocks
      assert post_fixture(scope, content: editor_js).content == blocks
      assert post_fixture(scope, content: Jason.encode!(editor_js)).content == blocks

      post = post_fixture(scope, content: blocks)
      assert Content.get_post!(scope, post.public_id).content == blocks
    end

    test "content_excerpt/2", %{scope: scope} do
      post =
        post_fixture(scope,
          content: [paragraph("<b>Bold</b> start"), %{"type" => "code", "code" => "x = 1"}]
        )

      assert Content.content_excerpt(post) == "Bold start"
    end

    test "editor_js/2 refreshes book blocks", %{scope: scope} do
      book = book_fixture(scope, title: "Real title")

      post =
        post_fixture(scope,
          content: [%{"type" => "book", "book_public_id" => book.public_id, "title" => "Old"}]
        )

      %{"blocks" => [block]} = Content.editor_js(scope, post)
      assert block["data"]["title"] == "Real title"
    end

    test "content is stored sanitized", %{scope: scope} do
      payload = ~S|<img src=x onerror="alert(1)"><b>b</b> <a href="javascript:alert(1)">a</a>|
      post = post_fixture(scope, content: [paragraph(payload)])

      assert [%{"text" => "<b>b</b> <a>a</a>"}] = post.content
      assert [%{"text" => "<b>b</b> <a>a</a>"}] = Content.get_post!(scope, post.public_id).content
    end

    test "editor_js/2 sanitizes content stored before sanitizing was in place", %{scope: scope} do
      post = post_fixture(scope)
      payload = ~S|<img src=x onerror="alert(1)"><i>kept</i>|

      # Raw SQL: update_all would cast (and sanitize) the content.
      Repo.query!("UPDATE posts SET content = ? WHERE public_id = ?", [
        Jason.encode!([%{"id" => "p1", "type" => "paragraph", "text" => payload}]),
        post.public_id
      ])

      post = Content.get_post!(scope, post.public_id)
      assert [%{"text" => ^payload}] = post.content

      assert %{"blocks" => [%{"data" => %{"text" => "<i>kept</i>"}}]} =
               Content.editor_js(scope, post)
    end
  end

  describe "embedded images" do
    test "saving assigns images referenced by image blocks", %{scope: scope} do
      image = image_fixture(scope)
      post = post_fixture(scope, content: [image_block(image)])
      assert Media.get_image!(scope, image.public_id).post_id == post.id

      page = page_fixture(scope, content: [image_block(image)])
      image = Media.get_image!(scope, image.public_id)
      assert image.page_id == page.id
      assert image.post_id == nil
    end

    test "header and thumbnail images must belong to the site", %{scope: scope} do
      own = image_fixture(scope)
      foreign = image_fixture(site_scope_fixture())

      post = post_fixture(scope, header_image_id: own.id, thumbnail_image_id: own.id)
      assert post.header_image_id == own.id

      assert {:error, changeset} =
               Content.update_post(scope, post, %{header_image_id: foreign.id})

      assert "is not an image of this site" in errors_on(changeset).header_image_id
    end

    test "images of another site are not assigned", %{scope: scope} do
      other = site_scope_fixture()
      image = image_fixture(other)
      post_fixture(scope, content: [image_block(image)])
      assert Media.get_image!(other, image.public_id).post_id == nil
    end

    test "deleting a post deletes its embedded images", %{scope: scope} do
      image = image_fixture(scope)
      post = post_fixture(scope, content: [image_block(image)])
      dir = Media.image_dir(image)

      assert {:ok, _} = Content.delete_post(scope, post)
      assert Media.get_image(scope, image.public_id) == nil
      refute File.exists?(dir)
    end
  end

  describe "pages" do
    test "page_type is validated", %{scope: scope} do
      assert page_fixture(scope).page_type == "default"
      assert page_fixture(scope, page_type: "books").page_type == "books"

      assert {:error, changeset} =
               Content.create_page(scope, %{title: "x", slug: "/x", page_type: "blog"})

      assert "is invalid" in errors_on(changeset).page_type
    end

    test "add_to_navigation adds and removes the page", %{scope: scope} do
      {:ok, page} =
        Content.create_page(scope, %{title: "About", slug: "/about", add_to_navigation: true})

      assert page.add_to_navigation
      assert Sites.in_navigation?(page)
      assert Content.get_page!(scope, page.public_id).add_to_navigation

      {:ok, page} = Content.update_page(scope, page, %{title: "About me"})
      assert Sites.in_navigation?(page), "not given means unchanged"

      {:ok, page} = Content.update_page(scope, page, %{"add_to_navigation" => "false"})
      refute page.add_to_navigation
      refute Sites.in_navigation?(page)

      assert Enum.all?(Content.list_pages(scope), &(&1.add_to_navigation == false))
    end

    test "deleting a page removes it from the navigation", %{scope: scope} do
      a = page_fixture(scope, add_to_navigation: true)
      b = page_fixture(scope, add_to_navigation: true)

      {:ok, _} = Content.delete_page(scope, a)
      assert [%{page_id: page_id, position: 1}] = Sites.list_navigation_items(scope)
      assert page_id == b.id
    end

    test "list_pages/1 lists the homepage first", %{scope: scope} do
      page_fixture(scope, title: "Aardvark")
      assert [%Page{slug: "/"}, %Page{title: "Aardvark"}] = Content.list_pages(scope)
    end
  end

  describe "projects" do
    test "validations", %{scope: scope} do
      assert {:error, changeset} = Content.create_project(scope, %{status: "done"})
      errors = errors_on(changeset)

      for field <- [:title, :slug, :short_description, :started_at] do
        assert "can't be blank" in errors[field], "#{field} is required"
      end

      assert "is invalid" in errors.status

      assert {:error, changeset} =
               Content.create_project(scope, %{
                 title: "x",
                 slug: "/x",
                 short_description: "d",
                 started_at: ~D[2024-01-01],
                 project_type: "hobby"
               })

      assert "is invalid" in errors_on(changeset).project_type
    end

    test "links are embedded", %{scope: scope} do
      project =
        project_fixture(scope,
          links: [
            %{label: "GitHub", url: "https://github.com/x"},
            %{label: "Site", url: "https://x.example"}
          ]
        )

      project = Content.get_project!(scope, project.public_id)
      assert [%{label: "GitHub"}, %{label: "Site"}] = project.links

      assert {:error, changeset} =
               Content.update_project(scope, project, %{links: [%{label: "", url: ""}]})

      assert %{label: ["can't be blank"], url: ["can't be blank"]} in errors_on(changeset).links
    end

    test "display_period/1" do
      assert Project.display_period(%Project{period: "05.2023 - today"}) == "05.2023 - today"

      assert Project.display_period(%Project{started_at: ~D[2023-05-01], ended_at: nil}) ==
               "05.2023 - ongoing"

      assert Project.display_period(%Project{
               period: " ",
               started_at: ~D[2023-05-01],
               ended_at: ~D[2024-02-10]
             }) == "05.2023 - 02.2024"
    end

    test "list_projects/1 orders by start, newest first", %{scope: scope} do
      project_fixture(scope, title: "old", started_at: ~D[2020-01-01])
      project_fixture(scope, title: "new", started_at: ~D[2024-01-01])
      assert Enum.map(Content.list_projects(scope), & &1.title) == ["new", "old"]
    end
  end
end
