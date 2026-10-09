defmodule Feather.ContentTest do
  use Feather.DataCase

  alias Feather.{Content, Media, Sites}
  alias Feather.Content.{Page, PageVersion, Post, PostVersion, Project, ProjectVersion}

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

    test "a post and a page of a site cannot share a slug", %{scope: scope} do
      page_fixture(scope, slug: "/about")
      assert {:error, changeset} = Content.create_post(scope, %{title: "x", slug: "/about"})
      assert "has already been taken" in errors_on(changeset).slug

      post = post_fixture(scope, slug: "/news")
      assert {:error, changeset} = Content.create_page(scope, %{title: "x", slug: "/news"})
      assert "has already been taken" in errors_on(changeset).slug

      page = page_fixture(scope, slug: "/contact")
      assert {:error, changeset} = Content.update_page(scope, page, %{slug: "/news"})
      assert "has already been taken" in errors_on(changeset).slug
      assert {:ok, _post} = Content.update_post(scope, post, %{title: "Keeps its slug"})

      assert project_fixture(scope, slug: "/about").slug == "/about"
      assert {:ok, _} = Content.create_post(site_scope_fixture(), %{title: "x", slug: "/about"})
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

    test "suggest_slug/3 does not avoid the record's own slug", %{scope: scope} do
      post = post_fixture(scope, slug: "/hello")
      page = page_fixture(scope, slug: "/about")

      assert Content.suggest_slug(scope, "Hello", post) == "/hello"
      assert Content.suggest_slug(scope, "About", page) == "/about"
      assert Content.suggest_slug(scope, "About", post) == "/about1"
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

    test "posts are scoped to their site", %{scope: scope} do
      post = post_fixture(scope)
      other = site_scope_fixture()

      assert Content.get_post!(scope, post.public_id).id == post.id
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(other, post.public_id) end
      assert_raise FunctionClauseError, fn -> Content.update_post(other, post, %{title: "x"}) end
    end

    test "content accepts the internal format, also as JSON, and ProseMirror docs",
         %{scope: scope} do
      blocks = [%{"id" => "p1", "type" => "paragraph", "text" => "Hi"}]

      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "attrs" => %{"id" => "p1"},
            "content" => [%{"type" => "text", "text" => "Hi"}]
          }
        ]
      }

      assert post_fixture(scope, content: blocks).content == blocks
      assert post_fixture(scope, content: Jason.encode!(blocks)).content == blocks
      assert post_fixture(scope, content: doc).content == blocks

      post = post_fixture(scope, content: blocks)
      assert Content.get_post!(scope, post.public_id).content == blocks
    end

    test "content rejects other maps and invalid JSON", %{scope: scope} do
      doc_json = ~s({"type": "doc", "content": []})

      for content <- [%{"blocks" => []}, "not json", ~s({"blocks": []}), doc_json] do
        assert {:error, changeset} = Content.create_post(scope, %{content: content})
        assert %{content: [_]} = errors_on(changeset)
      end
    end

    test "content_excerpt/2", %{scope: scope} do
      post =
        post_fixture(scope,
          content: [paragraph("<b>Bold</b> start"), %{"type" => "code", "code" => "x = 1"}]
        )

      assert Content.content_excerpt(post) == "Bold start"
    end

    test "editor_doc/2 refreshes book nodes", %{scope: scope} do
      book = book_fixture(scope, title: "Real title")

      post =
        post_fixture(scope,
          content: [%{"type" => "book", "book_public_id" => book.public_id, "title" => "Old"}]
        )

      %{"content" => [node]} = Content.editor_doc(scope, post)
      assert node["attrs"]["title"] == "Real title"
    end

    test "content is stored sanitized", %{scope: scope} do
      payload = ~S|<img src=x onerror="alert(1)"><b>b</b> <a href="javascript:alert(1)">a</a>|
      post = post_fixture(scope, content: [paragraph(payload)])

      assert [%{"text" => "<b>b</b> <a>a</a>"}] = post.content
      assert [%{"text" => "<b>b</b> <a>a</a>"}] = Content.get_post!(scope, post.public_id).content
    end

    test "editor_doc/2 sanitizes content stored before sanitizing was in place", %{scope: scope} do
      post = post_fixture(scope)
      payload = ~S|<img src=x onerror="alert(1)"><i>kept</i>|

      # Raw SQL: update_all would cast (and sanitize) the content.
      Repo.query!("UPDATE posts SET content = ? WHERE public_id = ?", [
        Jason.encode!([%{"id" => "p1", "type" => "paragraph", "text" => payload}]),
        post.public_id
      ])

      post = Content.get_post!(scope, post.public_id)
      assert [%{"text" => ^payload}] = post.content

      assert %{"content" => [%{"content" => [text]}]} = Content.editor_doc(scope, post)
      assert text == %{"type" => "text", "text" => "kept", "marks" => [%{"type" => "italic"}]}
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

    test "deleting a post keeps its images that other records embed", %{scope: scope} do
      image = image_fixture(scope)
      _other_post = post_fixture(scope, content: [image_block(image)])
      post = post_fixture(scope, content: [image_block(image)])
      page = page_fixture(scope, content: [image_block(image)])
      # The page saved last owns it; make the post the owner again.
      {:ok, post} = Content.update_post(scope, post, %{title: "Owner again"})
      assert Media.get_image!(scope, image.public_id).post_id == post.id

      assert {:ok, _} = Content.delete_post(scope, post)

      kept = Media.get_image!(scope, image.public_id)
      assert {kept.post_id, kept.page_id} != {nil, nil}
      assert kept.post_id != post.id
      assert File.dir?(Media.image_dir(image))

      assert {:ok, _} = Content.delete_page(scope, page)
      assert Media.get_image(scope, image.public_id)
    end

    test "deleting a post keeps its images used as header, thumbnail or cover", %{scope: scope} do
      header = image_fixture(scope)
      cover = image_fixture(scope)
      post = post_fixture(scope, content: [image_block(header), image_block(cover)])
      post_fixture(scope, header_image_id: header.id)
      book_fixture(scope, cover_image_id: cover.id)

      assert {:ok, _} = Content.delete_post(scope, post)

      for image <- [header, cover] do
        kept = Media.get_image!(scope, image.public_id)
        assert {kept.post_id, kept.page_id, kept.project_id} == {nil, nil, nil}
        assert File.dir?(Media.image_dir(image))
      end
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

  describe "publishing" do
    test "turns the current state of a post into a new version that becomes the published version",
         %{scope: scope} do
      image = image_fixture(scope)

      post =
        post_fixture(scope,
          title: "First",
          emoji: "📝",
          tags: "a, b",
          draft: true,
          header_image_id: image.id
        )

      assert Content.draft?(post)
      assert {:ok, post} = Content.publish(scope, post)
      refute Content.draft?(post)

      first = Repo.get!(PostVersion, post.published_version_id)
      assert first.number == 1
      assert first.post_id == post.id
      assert first.published_by_id == scope.user.id
      assert DateTime.diff(DateTime.utc_now(), first.published_at) in 0..5

      assert Map.take(first, PostVersion.copied_fields()) ==
               Map.take(post, PostVersion.copied_fields())

      post = post |> Ecto.Changeset.change(title: "Second") |> Repo.update!()
      assert {:ok, post} = Content.publish(scope, post)

      second = Repo.get!(PostVersion, post.published_version_id)
      assert {second.number, second.title} == {2, "Second"}
      assert Repo.get!(PostVersion, first.id).title == "First"
    end

    test "turns pages and projects into versions", %{scope: scope} do
      page = page_fixture(scope, page_type: "books", draft: true)
      assert {:ok, page} = Content.publish(scope, page)
      version = Repo.get!(PageVersion, page.published_version_id)
      assert version.number == 1

      assert Map.take(version, PageVersion.copied_fields()) ==
               Map.take(page, PageVersion.copied_fields())

      project =
        project_fixture(scope, links: [%{label: "Code", url: "https://example.com"}], draft: true)

      assert {:ok, project} = Content.publish(scope, project)
      version = Repo.get!(ProjectVersion, project.published_version_id)
      assert version.number == 1
      assert [%{label: "Code", url: "https://example.com"}] = version.links

      assert Map.take(version, ProjectVersion.copied_fields() -- [:links]) ==
               Map.take(project, ProjectVersion.copied_fields() -- [:links])
    end

    test "refuses a slug another record of the type is published with", %{scope: scope} do
      published = post_fixture(scope, slug: "/taken")
      {:ok, _moved} = Content.update_post(scope, published, %{slug: "/moved"})
      post = post_fixture(scope, slug: "/taken", draft: true)

      assert Content.publish(scope, post) == {:error, :slug_taken}
      assert Content.draft?(Repo.reload!(post))

      other_site = site_scope_fixture()
      post_fixture(other_site, slug: "/elsewhere")
      project_fixture(scope, slug: "/elsewhere")
      assert {:ok, _post} = Content.publish(scope, post_fixture(scope, slug: "/elsewhere"))

      {:ok, _} = Content.unpublish(scope, published)
      assert {:ok, _post} = Content.publish(scope, post)
    end

    test "refuses a slug a post or page of the other type is published with",
         %{scope: scope} do
      page = page_fixture(scope, slug: "/page-taken")
      {:ok, _moved} = Content.update_page(scope, page, %{slug: "/page-moved"})
      post = post_fixture(scope, slug: "/page-taken", draft: true)
      assert Content.publish(scope, post) == {:error, :slug_taken}

      post = post_fixture(scope, slug: "/post-taken")
      {:ok, _moved} = Content.update_post(scope, post, %{slug: "/post-moved"})
      page = page_fixture(scope, slug: "/post-taken", draft: true)
      assert Content.publish(scope, page) == {:error, :slug_taken}
    end

    test "saving with draft: false refuses a slug another record is published with",
         %{scope: scope} do
      published = post_fixture(scope, slug: "/taken")
      {:ok, _moved} = Content.update_post(scope, published, %{slug: "/moved"})

      assert {:error, changeset} =
               Content.create_post(scope, %{title: "x", slug: "/taken"}, draft: false)

      assert "has already been taken" in errors_on(changeset).slug
      assert Content.get_post_by_slug(scope, "/taken") == nil
    end

    test "only publishes records of the scope's site", %{scope: scope} do
      post = post_fixture(scope)
      assert_raise FunctionClauseError, fn -> Content.publish(site_scope_fixture(), post) end
    end

    test "deleting a record deletes its versions", %{scope: scope} do
      {:ok, post} = Content.publish(scope, post_fixture(scope))
      {:ok, page} = Content.publish(scope, page_fixture(scope))
      {:ok, project} = Content.publish(scope, project_fixture(scope))

      {:ok, _} = Content.delete_post(scope, post)
      {:ok, _} = Content.delete_page(scope, page)
      {:ok, _} = Content.delete_project(scope, project)

      assert Repo.all(from v in PostVersion, where: v.post_id == ^post.id) == []
      assert Repo.all(from v in PageVersion, where: v.page_id == ^page.id) == []
      assert Repo.all(from v in ProjectVersion, where: v.project_id == ^project.id) == []
    end

    test "saving stores the unpublished changes without publishing", %{scope: scope} do
      {:ok, post} = Content.create_post(scope, %{title: "New", slug: "/new"})
      assert Content.draft?(post)
      refute Repo.exists?(from v in PostVersion, where: v.post_id == ^post.id)

      post = post_fixture(scope, title: "First")
      {:ok, changed} = Content.update_post(scope, post, %{title: "Second"})
      assert changed.published_version_id == post.published_version_id
      assert Repo.get!(PostVersion, post.published_version_id).title == "First"
      assert Content.publication_status(changed) == :unpublished_changes

      {:ok, page} = Content.create_page(scope, %{title: "Page", slug: "/a-page"})
      assert Content.draft?(page)

      {:ok, project} =
        Content.create_project(scope, %{
          title: "Project",
          slug: "/project",
          short_description: "New",
          started_at: ~D[2024-01-01]
        })

      assert Content.draft?(project)

      page = page_fixture(scope, title: "Page")
      {:ok, page} = Content.update_page(scope, page, %{title: "Page 2"})
      assert Repo.get!(PageVersion, page.published_version_id).title == "Page"

      project = project_fixture(scope, title: "Project")
      {:ok, project} = Content.update_project(scope, project, %{title: "Project 2"})
      assert Repo.get!(ProjectVersion, project.published_version_id).title == "Project"
    end

    test "saving with draft: false publishes in the same step", %{scope: scope} do
      {:ok, post} = Content.create_post(scope, %{title: "First", slug: "/first"}, draft: false)
      assert Repo.get!(PostVersion, post.published_version_id).title == "First"

      {:ok, post} = Content.update_post(scope, post, %{title: "Second"}, draft: false)
      version = Repo.get!(PostVersion, post.published_version_id)
      assert {version.number, version.title} == {2, "Second"}

      {:ok, saved} = Content.update_post(scope, post, %{title: "Second"}, draft: false)
      assert saved.published_version_id == post.published_version_id

      {:ok, draft} = Content.unpublish(scope, page_fixture(scope, title: "Page"))
      {:ok, page} = Content.update_page(scope, draft, %{title: "Page 2"}, draft: false)
      assert Repo.get!(PageVersion, page.published_version_id).title == "Page 2"

      {:ok, page} = Content.create_page(scope, %{title: "New", slug: "/new-page"}, draft: false)
      refute Content.draft?(page)
    end

    test "saving with draft: true stores the changes and unpublishes", %{scope: scope} do
      {:ok, draft} = Content.create_post(scope, %{title: "D", slug: "/d"}, draft: true)
      assert Content.draft?(draft)
      refute Repo.exists?(from v in PostVersion, where: v.post_id == ^draft.id)

      post = post_fixture(scope, title: "Shown")
      {:ok, post} = Content.update_post(scope, post, %{title: "Hidden"}, draft: true)
      assert Content.draft?(post)
      assert Content.get_post!(scope, post.public_id).title == "Hidden"
      assert Repo.aggregate(from(v in PostVersion, where: v.post_id == ^post.id), :count) == 1

      {:ok, page} = Content.update_page(scope, page_fixture(scope), %{title: "P"}, draft: true)
      assert Content.draft?(page)
    end

    test "a failed save with draft: false publishes nothing", %{scope: scope} do
      post_fixture(scope, slug: "/taken")
      post = post_fixture(scope, slug: "/mine")

      assert {:error, _changeset} =
               Content.update_post(scope, post, %{slug: "/taken"}, draft: false)

      assert Repo.aggregate(from(v in PostVersion, where: v.post_id == ^post.id), :count) == 1
    end

    test "publication_status/1 tells drafts, published records and unpublished changes apart",
         %{scope: scope} do
      assert Content.publication_status(post_fixture(scope, draft: true)) == :draft

      post = post_fixture(scope, content: [paragraph("Hi")], publish_at: ~U[2024-01-01 10:00:00Z])
      assert Content.publication_status(post) == :published
      assert Content.publication_status(Repo.reload!(post)) == :published
      refute Content.publication_status(post) == :unpublished_changes

      {:ok, post} = Content.update_post(scope, post, %{content: [paragraph("Changed")]})
      assert Content.publication_status(post) == :unpublished_changes
      assert Content.publication_status(post) == :unpublished_changes

      {:ok, post} = Content.unpublish(scope, post)
      assert Content.publication_status(post) == :draft
      refute Content.publication_status(post) == :unpublished_changes

      project = project_fixture(scope, links: [%{label: "Code", url: "https://example.com"}])
      assert Content.publication_status(Repo.reload!(project)) == :published
      {:ok, project} = Content.update_project(scope, project, %{links: []})
      assert Content.publication_status(project) == :unpublished_changes

      page = page_fixture(scope)
      {:ok, page} = Content.update_page(scope, page, %{add_to_navigation: true})
      assert Content.publication_status(page) == :published
    end

    test "publishing creates the next version and lists the earlier ones", %{scope: scope} do
      post = post_fixture(scope, title: "Version 1")

      post =
        Enum.reduce(2..3, post, fn n, post ->
          {:ok, post} = Content.update_post(scope, post, %{title: "Version #{n}"})
          {:ok, post} = Content.publish(scope, post)
          post
        end)

      {:ok, post} = Content.update_post(scope, post, %{title: "Changed"})
      assert Content.publication_status(post) == :unpublished_changes
      assert Repo.get!(PostVersion, post.published_version_id).number == 3

      {:ok, post} = Content.publish(scope, post)
      refute Content.publication_status(post) == :unpublished_changes

      assert [
               %PostVersion{number: 4, title: "Changed"} = latest,
               %PostVersion{number: 3},
               %PostVersion{number: 2},
               %PostVersion{number: 1}
             ] = Content.list_versions(scope, post)

      assert latest.id == post.published_version_id
      assert latest.published_by.id == scope.user.id
    end

    test "publishing without unpublished changes creates no version", %{scope: scope} do
      post = post_fixture(scope)
      assert {:ok, same} = Content.publish(scope, post)
      assert same.published_version_id == post.published_version_id
      assert [%PostVersion{number: 1}] = Content.list_versions(scope, post)
    end

    test "list_versions/2 only lists versions of records of the scope's site", %{scope: scope} do
      post = post_fixture(scope)

      assert_raise FunctionClauseError, fn ->
        Content.list_versions(site_scope_fixture(), post)
      end

      assert [%PageVersion{}] = Content.list_versions(scope, page_fixture(scope))
      assert [%ProjectVersion{}] = Content.list_versions(scope, project_fixture(scope))
    end

    test "discarding puts the published version back into the record", %{scope: scope} do
      image = image_fixture(scope)

      post =
        post_fixture(scope,
          title: "Published",
          tags: "a",
          content: [paragraph("Published text")],
          header_image_id: image.id
        )

      {:ok, changed} =
        Content.update_post(scope, post, %{
          title: "Changed",
          tags: "b",
          content: [paragraph("Changed text")],
          header_image_id: nil
        })

      assert {:ok, discarded} = Content.discard_changes(scope, changed)
      assert Content.publication_status(discarded) == :published
      assert discarded.published_version_id == post.published_version_id

      reloaded = Repo.reload!(discarded)

      assert Map.take(reloaded, PostVersion.copied_fields()) ==
               Map.take(Repo.reload!(post), PostVersion.copied_fields())
    end

    test "discards changes of pages and projects", %{scope: scope} do
      page = page_fixture(scope, title: "Page", page_type: "books")
      {:ok, page} = Content.update_page(scope, page, %{title: "Changed", page_type: "default"})
      assert {:ok, page} = Content.discard_changes(scope, page)
      assert {Repo.reload!(page).title, Repo.reload!(page).page_type} == {"Page", "books"}

      project = project_fixture(scope, links: [%{label: "Code", url: "https://example.com"}])
      {:ok, project} = Content.update_project(scope, project, %{title: "Changed", links: []})
      assert {:ok, project} = Content.discard_changes(scope, project)
      reloaded = Repo.reload!(project)
      assert reloaded.title == "A project"
      assert [%{label: "Code", url: "https://example.com"}] = reloaded.links
    end

    test "discarding fails when another record has taken the published slug", %{scope: scope} do
      post = post_fixture(scope, slug: "/taken")
      {:ok, post} = Content.update_post(scope, post, %{slug: "/moved"})
      post_fixture(scope, slug: "/taken", draft: true)

      assert {:error, changeset} = Content.discard_changes(scope, post)
      assert "has already been taken" in errors_on(changeset).slug

      page = page_fixture(scope, slug: "/page-taken")
      {:ok, page} = Content.update_page(scope, page, %{slug: "/page-moved"})
      post_fixture(scope, slug: "/page-taken", draft: true)

      assert {:error, changeset} = Content.discard_changes(scope, page)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "only discards changes of published records of the scope's site", %{scope: scope} do
      post = post_fixture(scope)

      assert_raise FunctionClauseError, fn ->
        Content.discard_changes(site_scope_fixture(), post)
      end

      draft = post_fixture(scope, draft: true)
      assert Content.discard_changes(scope, draft) == {:error, :not_published}
    end

    test "publishing, discarding and restoring act on the stored record", %{scope: scope} do
      post = post_fixture(scope, title: "Published")
      {:ok, mine} = Content.update_post(scope, post, %{title: "Mine"})

      # another tab published the same state: discarding keeps it
      {:ok, _published} = Content.publish(scope, Repo.reload!(mine))
      assert {:ok, discarded} = Content.discard_changes(scope, mine)
      assert Repo.reload!(discarded).title == "Mine"

      # another tab unpublished it: publishing publishes again
      {:ok, _unpublished} = Content.unpublish(scope, Repo.reload!(discarded))
      assert {:ok, republished} = Content.publish(scope, discarded)
      assert Repo.reload!(republished).published_version_id == republished.published_version_id
      assert [%{number: 3} | _] = Content.list_versions(scope, post)

      # another tab unpublished it: there is nothing to discard
      {:ok, _unpublished} = Content.unpublish(scope, Repo.reload!(republished))
      assert Content.discard_changes(scope, republished) == {:error, :not_published}
    end

    test "publishing, discarding and restoring a record changed elsewhere are stale", %{
      scope: scope
    } do
      post = post_fixture(scope, title: "Published")
      {:ok, mine} = Content.update_post(scope, post, %{title: "Mine"})
      {:ok, _elsewhere} = Content.update_post(scope, mine, %{title: "Elsewhere"})

      assert Content.publish(scope, mine) == {:error, :stale}
      assert Content.discard_changes(scope, mine) == {:error, :stale}

      assert Content.restore_version(scope, mine, Content.get_version!(scope, mine, 1)) ==
               {:error, :stale}

      reloaded = Repo.reload!(post)
      assert {reloaded.title, length(Content.list_versions(scope, post))} == {"Elsewhere", 1}
    end

    test "publishing and unpublishing keep the stored updated_at", %{scope: scope} do
      post = post_fixture(scope, title: "Published", draft: true)
      later = DateTime.add(post.updated_at, 60)
      post |> Ecto.Changeset.change(updated_at: later) |> Repo.update!()

      {:ok, _published} = Content.publish(scope, post)
      assert Repo.reload!(post).updated_at == later
      {:ok, _unpublished} = Content.unpublish(scope, post)
      assert Repo.reload!(post).updated_at == later
    end

    test "restoring copies a version into the record and leaves the published version unchanged",
         %{scope: scope} do
      image = image_fixture(scope)

      post =
        post_fixture(scope,
          title: "Version 1",
          slug: "/v1",
          tags: "a",
          content: [paragraph("Text 1")]
        )

      {:ok, post} =
        Content.update_post(scope, post, %{
          title: "Version 2",
          slug: "/v2",
          tags: "b",
          content: [paragraph("Text 2")],
          header_image_id: image.id
        })

      {:ok, post} = Content.publish(scope, post)

      post =
        Enum.reduce(3..4, post, fn n, post ->
          {:ok, post} =
            Content.update_post(scope, post, %{
              title: "Version #{n}",
              slug: "/v#{n}",
              content: [paragraph("Text #{n}")],
              header_image_id: nil
            })

          {:ok, post} = Content.publish(scope, post)
          post
        end)

      version_2 = Content.get_version!(scope, post, 2)
      assert {:ok, restored} = Content.restore_version(scope, post, version_2)

      reloaded = Repo.reload!(restored)

      assert Map.take(reloaded, PostVersion.copied_fields()) ==
               Map.take(version_2, PostVersion.copied_fields())

      assert {reloaded.title, reloaded.slug, reloaded.header_image_id} ==
               {"Version 2", "/v2", image.id}

      assert reloaded.published_version_id == post.published_version_id
      assert Content.publication_status(reloaded) == :unpublished_changes
      assert [%PostVersion{number: 4} | _] = Content.list_versions(scope, reloaded)
    end

    test "restores versions of pages, projects and drafts", %{scope: scope} do
      page = page_fixture(scope, title: "Page", page_type: "books")
      {:ok, page} = Content.update_page(scope, page, %{title: "Changed", page_type: "default"})
      {:ok, page} = Content.publish(scope, page)

      assert {:ok, page} =
               Content.restore_version(scope, page, Content.get_version!(scope, page, 1))

      assert {Repo.reload!(page).title, Repo.reload!(page).page_type} == {"Page", "books"}

      project = project_fixture(scope, links: [%{label: "Code", url: "https://example.com"}])
      {:ok, project} = Content.update_project(scope, project, %{title: "Changed", links: []})
      {:ok, project} = Content.unpublish(scope, project)
      version = Content.get_version!(scope, project, 1)
      assert {:ok, project} = Content.restore_version(scope, project, version)
      reloaded = Repo.reload!(project)
      assert {reloaded.title, reloaded.published_version_id} == {"A project", nil}
      assert [%{label: "Code", url: "https://example.com"}] = reloaded.links
    end

    test "a version of another record or site behaves like a missing one", %{scope: scope} do
      post = post_fixture(scope)
      other_post = post_fixture(scope)
      other_version = Content.get_version!(scope, other_post, 1)

      assert_raise Ecto.NoResultsError, fn -> Content.get_version!(scope, post, 2) end

      assert_raise Ecto.NoResultsError, fn ->
        Content.restore_version(scope, post, other_version)
      end

      foreign_scope = site_scope_fixture()
      foreign_version = Content.get_version!(foreign_scope, post_fixture(foreign_scope), 1)

      assert_raise Ecto.NoResultsError, fn ->
        Content.restore_version(scope, post, foreign_version)
      end

      page_version = Content.get_version!(scope, page_fixture(scope), 1)

      assert_raise Ecto.NoResultsError, fn ->
        Content.restore_version(scope, post, page_version)
      end

      assert_raise FunctionClauseError, fn -> Content.get_version!(foreign_scope, post, 1) end

      assert_raise FunctionClauseError, fn ->
        Content.restore_version(foreign_scope, post, Content.get_version!(scope, post, 1))
      end
    end

    test "restoring a version whose slug another record has taken fails", %{scope: scope} do
      post = post_fixture(scope, slug: "/taken")
      {:ok, post} = Content.update_post(scope, post, %{slug: "/moved"})
      {:ok, post} = Content.publish(scope, post)
      post_fixture(scope, slug: "/taken")

      assert {:error, changeset} =
               Content.restore_version(scope, post, Content.get_version!(scope, post, 1))

      assert "has already been taken" in errors_on(changeset).slug
      assert Repo.reload!(post).slug == "/moved"
    end

    test "restoring a version whose slug a page has taken fails", %{scope: scope} do
      post = post_fixture(scope, slug: "/taken")
      {:ok, post} = Content.update_post(scope, post, %{slug: "/moved"})
      {:ok, post} = Content.publish(scope, post)
      page_fixture(scope, slug: "/taken")

      assert {:error, changeset} =
               Content.restore_version(scope, post, Content.get_version!(scope, post, 1))

      assert "has already been taken" in errors_on(changeset).slug
      assert Repo.reload!(post).slug == "/moved"
    end

    test "unpublishing removes the published version and keeps the versions and the unpublished changes",
         %{scope: scope} do
      post = post_fixture(scope, title: "Published")
      post = post |> Ecto.Changeset.change(title: "Changed") |> Repo.update!()

      assert {:ok, unpublished} = Content.unpublish(scope, post)

      assert unpublished.published_version_id == nil
      assert Content.draft?(unpublished)
      reloaded = Repo.reload!(unpublished)
      assert {reloaded.title, reloaded.updated_at} == {"Changed", post.updated_at}

      assert [%PostVersion{title: "Published"}] =
               Repo.all(from v in PostVersion, where: v.post_id == ^post.id)
    end

    test "unpublishes pages and projects", %{scope: scope} do
      page = page_fixture(scope)
      assert {:ok, page} = Content.unpublish(scope, page)
      assert Repo.reload!(page).published_version_id == nil
      assert Repo.exists?(from v in PageVersion, where: v.page_id == ^page.id)

      project = project_fixture(scope)
      assert {:ok, project} = Content.unpublish(scope, project)
      assert Repo.reload!(project).published_version_id == nil
      assert Repo.exists?(from v in ProjectVersion, where: v.project_id == ^project.id)
    end

    test "only unpublishes records of the scope's site", %{scope: scope} do
      post = post_fixture(scope)
      assert_raise FunctionClauseError, fn -> Content.unpublish(site_scope_fixture(), post) end
    end

    test "as_published/1 shows records as their published versions, without drafts",
         %{scope: scope} do
      image = image_fixture(scope)
      post = post_fixture(scope, title: "Published", header_image_id: image.id)
      post |> Ecto.Changeset.change(title: "Changed", header_image_id: nil) |> Repo.update!()
      draft = post_fixture(scope, title: "Draft", draft: true)

      assert [shown] = Content.as_published([Repo.reload!(post), draft])
      assert {shown.id, shown.title, shown.header_image_id} == {post.id, "Published", image.id}

      project = project_fixture(scope, title: "Project")
      project |> Ecto.Changeset.change(title: "Changed") |> Repo.update!()
      assert [%Project{title: "Project"}] = Content.as_published([Repo.reload!(project)])
    end

    test "a version copies every column of its record" do
      bookkeeping = [
        :id,
        :public_id,
        :site_id,
        :published_version_id,
        :lock_version,
        :inserted_at,
        :updated_at
      ]

      for {record, version} <- [
            {Post, PostVersion},
            {Page, PageVersion},
            {Project, ProjectVersion}
          ] do
        columns = record.__schema__(:fields) -- bookkeeping
        assert Enum.sort(version.copied_fields()) == Enum.sort(columns)
      end
    end
  end

  describe "sync_content/4" do
    setup %{scope: scope} do
      post =
        post_fixture(scope, content: [paragraph("One"), paragraph("Two"), paragraph("Three")])

      %{post: post, ids: Enum.map(post.content, & &1["id"])}
    end

    test "replaces the changed blocks by id and keeps the others", %{
      scope: scope,
      post: post,
      ids: [_, two, _]
    } do
      assert {:ok, synced} =
               Content.sync_content(scope, post, sync(post, nil, [text_node(two, "Two!")]))

      assert texts(post) == ["One", "Two!", "Three"]
      assert synced.lock_version == post.lock_version + 1
      assert Enum.map(synced.content, & &1["text"]) == ["One", "Two!", "Three"]
    end

    test "an order alone rearranges the blocks and drops those it leaves out", %{
      scope: scope,
      post: post,
      ids: [one, _, three]
    } do
      assert {:ok, _synced} = Content.sync_content(scope, post, sync(post, [three, one], []))
      assert texts(post) == ["Three", "One"]
    end

    test "a new block takes its place in the order", %{scope: scope, post: post, ids: ids} do
      [one | rest] = ids
      order = [one, "newBlock01" | rest]

      assert {:ok, _synced} =
               Content.sync_content(
                 scope,
                 post,
                 sync(post, order, [text_node("newBlock01", "New")])
               )

      assert texts(post) == ["One", "New", "Two", "Three"]
      assert Enum.map(Repo.reload!(post).content, & &1["id"]) == order
    end

    test "a block outside the order is not added", %{scope: scope, post: post} do
      assert {:ok, _synced} =
               Content.sync_content(
                 scope,
                 post,
                 sync(post, nil, [text_node("newBlock01", "New")])
               )

      assert texts(post) == ["One", "Two", "Three"]
    end

    test "a repeated sync leaves the same content and saves nothing", %{
      scope: scope,
      post: post,
      ids: [one, two, three]
    } do
      blocks = [text_node(two, "Two!")]
      order = [three, two, one]

      assert {:ok, first} = Content.sync_content(scope, post, sync(post, order, blocks))
      assert {:ok, second} = Content.sync_content(scope, first, sync(first, order, blocks))

      assert texts(post) == ["Three", "Two!", "One"]
      assert second.lock_version == first.lock_version
      assert second.content == first.content
    end

    test "a sync on a stale counter is rejected and saves nothing", %{
      scope: scope,
      post: post,
      ids: [one, _, _]
    } do
      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Changed elsewhere"})

      assert {:error, :stale} =
               Content.sync_content(scope, post, sync(post, [one], [text_node(one, "Mine")]))

      assert texts(post) == ["One", "Two", "Three"]
      assert Repo.reload!(post).title == "Changed elsewhere"
    end

    test "a sync on a stale counter is rejected even when it changes nothing", %{
      scope: scope,
      post: post,
      ids: [one, two, three]
    } do
      {:ok, elsewhere} = Content.update_post(scope, post, %{title: "Changed elsewhere"})
      unchanged = [text_node(one, "One"), text_node(two, "Two"), text_node(three, "Three")]

      assert {:error, :stale} =
               Content.sync_content(scope, post, sync(post, [one, two, three], unchanged))

      # also when it names the newer counter but builds on the older record
      assert {:error, :stale} =
               Content.sync_content(scope, post, sync(elsewhere, [one, two, three], unchanged))
    end

    test "a counter from `base` up to the record's builds on the record", %{
      scope: scope,
      post: post,
      ids: [one, two, _]
    } do
      # e.g. a field save of the same view advanced the counter meanwhile
      {:ok, saved} = Content.update_post(scope, post, %{title: "Field save"})

      assert {:ok, synced} =
               Content.sync_content(scope, saved, sync(post, nil, [text_node(one, "One!")]),
                 base: post.lock_version
               )

      assert synced.lock_version == saved.lock_version + 1

      # a no-op names its counter back
      assert {:ok, same} =
               Content.sync_content(scope, synced, sync(post, nil, [text_node(one, "One!")]),
                 base: post.lock_version
               )

      assert same.lock_version == synced.lock_version

      # a counter from before `base` was built on a state the caller never had
      assert {:error, :stale} =
               Content.sync_content(scope, synced, sync(post, nil, [text_node(two, "Old")]),
                 base: saved.lock_version
               )

      assert texts(post) == ["One!", "Two", "Three"]
    end

    test "synced_doc/1 builds the document of a new record from a sync" do
      sync = %{
        lock_version: nil,
        order: ["b", "a", "missing"],
        blocks: [text_node("a", "A"), "junk", %{"attrs" => "x"}, text_node("b", "B")]
      }

      assert %{
               "type" => "doc",
               "content" => [%{"attrs" => %{"id" => "b"}}, %{"attrs" => %{"id" => "a"}}]
             } =
               Content.synced_doc(sync)

      assert %{"content" => [_a, _b]} = Content.synced_doc(%{sync | order: nil})
    end

    test "sanitizes the synced blocks", %{scope: scope, post: post, ids: [one, _, _]} do
      unsafe = %{
        "type" => "paragraph",
        "attrs" => %{"id" => one},
        "content" => [
          %{"type" => "text", "text" => "<script>alert(1)</script>"},
          %{
            "type" => "text",
            "text" => "link",
            "marks" => [%{"type" => "link", "attrs" => %{"href" => "javascript:alert(1)"}}]
          }
        ]
      }

      assert {:ok, _synced} = Content.sync_content(scope, post, sync(post, nil, [unsafe]))

      [stored | _] = texts(post)
      refute stored =~ "<script>"
      refute stored =~ "javascript:"
      assert stored =~ "&lt;script&gt;"
    end

    test "ignores nodes that are not blocks", %{scope: scope, post: post} do
      blocks = [%{"type" => "unknown", "attrs" => %{"id" => "newBlock01"}}, "junk", nil]

      assert {:ok, _synced} = Content.sync_content(scope, post, sync(post, nil, blocks))
      assert texts(post) == ["One", "Two", "Three"]
    end

    test "syncs pages and projects", %{scope: scope} do
      page = page_fixture(scope, content: [paragraph("Page")])
      [page_block] = page.content

      assert {:ok, synced_page} =
               Content.sync_content(
                 scope,
                 page,
                 sync(page, nil, [text_node(page_block["id"], "P!")])
               )

      assert texts(page) == ["P!"]
      assert synced_page.add_to_navigation == page.add_to_navigation

      project = project_fixture(scope, content: [paragraph("Project")])
      [project_block] = project.content

      assert {:ok, _synced} =
               Content.sync_content(
                 scope,
                 project,
                 sync(project, nil, [text_node(project_block["id"], "Pr!")])
               )

      assert texts(project) == ["Pr!"]
    end

    test "keeps image blocks only for images of the site", %{
      scope: scope,
      post: post,
      ids: [one, two, three]
    } do
      own = image_fixture(scope)
      foreign = image_fixture(site_scope_fixture())

      blocks = [
        image_node("ownImage01", own.public_id, "Mine"),
        image_node("foreign001", foreign.public_id, "Theirs"),
        image_node("missing001", "NoSuchImage1", "Gone"),
        image_node("noImage001", nil, "Empty")
      ]

      order = [one, "ownImage01", "foreign001", "missing001", "noImage001", two, three]
      assert {:ok, synced} = Content.sync_content(scope, post, sync(post, order, blocks))

      assert Enum.map(synced.content, & &1["id"]) == [one, "ownImage01", two, three]
      assert Enum.at(synced.content, 1)["image_id"] == own.public_id
      assert Media.get_image!(scope, own.public_id).post_id == post.id
    end

    test "keeps book blocks only for books of the site, with the bookshelf's details", %{
      scope: scope,
      post: post,
      ids: [one, two, three]
    } do
      own = book_fixture(scope, title: "Dune", author: "Frank Herbert", emoji: "🏜️")
      foreign = book_fixture(site_scope_fixture(), title: "Theirs")

      blocks = [
        book_node("ownBook001", own.public_id, "Forged title"),
        book_node("foreign001", foreign.public_id, "Theirs"),
        book_node("missing001", "NoSuchBook12", "Gone"),
        book_node("noBook0001", nil, nil)
      ]

      order = [one, "ownBook001", "foreign001", "missing001", "noBook0001", two, three]
      assert {:ok, synced} = Content.sync_content(scope, post, sync(post, order, blocks))

      assert Enum.map(synced.content, & &1["id"]) == [one, "ownBook001", two, three]

      assert %{
               "book_public_id" => book_public_id,
               "title" => "Dune",
               "author" => "Frank Herbert",
               "emoji" => "🏜️"
             } = Enum.at(synced.content, 1)

      assert book_public_id == own.public_id
    end

    test "a record of another site is out of reach", %{scope: scope} do
      other = post_fixture(site_scope_fixture())

      assert_raise FunctionClauseError, fn ->
        Content.sync_content(scope, other, sync(other, nil, []))
      end
    end
  end

  describe "lock_version" do
    test "every save of the record increments it", %{scope: scope} do
      post = post_fixture(scope, title: "Version 1")
      {:ok, post} = Content.update_post(scope, post, %{title: "Changed"})
      assert post.lock_version == 2

      {:ok, post} = Content.discard_changes(scope, post)
      assert post.lock_version == 3

      version = Content.get_version!(scope, post, 1)
      {:ok, post} = Content.update_post(scope, post, %{title: "Again"})
      {:ok, post} = Content.restore_version(scope, post, version)
      assert post.lock_version == 5
      assert Repo.reload!(post).lock_version == 5
    end

    test "publishing and unpublishing leave it", %{scope: scope} do
      post = post_fixture(scope, draft: true)
      {:ok, published} = Content.publish(scope, post)
      {:ok, unpublished} = Content.unpublish(scope, published)

      assert Repo.reload!(unpublished).lock_version == post.lock_version
    end

    test "a save based on an older state is rejected", %{scope: scope} do
      post = post_fixture(scope, title: "Original")
      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Elsewhere"})

      assert {:error, changeset} = Content.update_post(scope, post, %{title: "Mine"})
      assert "was changed elsewhere" in errors_on(changeset).lock_version
      assert {:error, _changeset} = Content.discard_changes(scope, post)
      assert Repo.reload!(post).title == "Elsewhere"
    end
  end

  describe "autosave/4" do
    test "saves the valid fields and leaves out the invalid ones", %{scope: scope} do
      post = post_fixture(scope, title: "Old", slug: "/old", tags: "a")

      assert {:ok, saved} =
               Content.autosave(scope, post, %{
                 "title" => "New",
                 "slug" => "/posts/reserved",
                 "tags" => "a, b"
               })

      assert {saved.title, saved.slug, saved.tags} == {"New", "/old", "a, b"}
      assert saved.lock_version == post.lock_version + 1
      assert Repo.reload!(post).title == "New"
    end

    test "leaves out a slug another record has", %{scope: scope} do
      post_fixture(scope, slug: "/taken")
      post = post_fixture(scope, title: "Mine", slug: "/mine")

      assert {:ok, saved} = Content.autosave(scope, post, %{"slug" => "/taken", "title" => "T"})
      assert {saved.title, saved.slug} == {"T", "/mine"}
    end

    test "saves nothing when a project's form is sent unchanged", %{scope: scope} do
      project =
        project_fixture(scope, title: "P", links: [%{label: "Code", url: "https://a.example"}])

      attrs = %{
        "title" => "P",
        "slug" => project.slug,
        "started_at" => Date.to_iso8601(project.started_at),
        "links" => %{"0" => %{"label" => "Code", "url" => "https://a.example"}},
        "links_sort" => ["0"],
        "links_drop" => [""]
      }

      assert {:ok, saved} = Content.autosave(scope, project, attrs)
      assert saved.lock_version == project.lock_version
    end

    test "saves nothing without changes", %{scope: scope} do
      post = post_fixture(scope, title: "Same")

      assert {:ok, saved} = Content.autosave(scope, post, %{"title" => "Same"})
      assert saved.lock_version == post.lock_version
    end

    test "a save on a stale record is rejected", %{scope: scope} do
      post = post_fixture(scope, title: "Original")
      {:ok, _elsewhere} = Content.update_post(scope, post, %{title: "Elsewhere"})

      assert Content.autosave(scope, post, %{"title" => "Mine"}) == {:error, :stale}
      assert Repo.reload!(post).title == "Elsewhere"
    end

    test "fields built on another counter than the record's are stale unless unchanged",
         %{scope: scope} do
      post = post_fixture(scope, title: "Original")
      {:ok, current} = Content.update_post(scope, post, %{title: "Elsewhere"})
      old = [lock_version: post.lock_version]

      assert Content.autosave(scope, current, %{"title" => "Mine"}, old) == {:error, :stale}
      assert {:ok, ^current} = Content.autosave(scope, current, %{"title" => "Elsewhere"}, old)

      assert Content.autosave(scope, current, %{"title" => "Mine"}, lock_version: nil) ==
               {:error, :stale}

      assert {:ok, %{title: "Mine"}} =
               Content.autosave(scope, current, %{"title" => "Mine"},
                 lock_version: current.lock_version
               )
    end

    test "creates a new record as a draft", %{scope: scope} do
      assert {:ok, %Post{id: id} = post} =
               Content.autosave(scope, %Post{site_id: scope.site.id}, %{
                 "title" => "First input",
                 "slug" => "/posts/reserved"
               })

      assert id
      assert {post.title, post.slug} == {"First input", nil}
      assert Content.draft?(post)
    end

    test "keeps image blocks only for images of the site", %{scope: scope} do
      own = image_fixture(scope)
      foreign = image_fixture(site_scope_fixture())

      doc = %{
        "type" => "doc",
        "content" => [
          image_node("ownImage01", own.public_id, "Mine"),
          image_node("foreign001", foreign.public_id, "Theirs")
        ]
      }

      assert {:ok, post} =
               Content.autosave(scope, %Post{site_id: scope.site.id}, %{"content" => doc})

      assert [%{"id" => "ownImage01", "image_id" => image_id}] = post.content
      assert image_id == own.public_id
    end

    test "keeps book blocks only for books of the site", %{scope: scope} do
      own = book_fixture(scope, title: "Dune")
      foreign = book_fixture(site_scope_fixture(), title: "Theirs")

      doc = %{
        "type" => "doc",
        "content" => [
          book_node("ownBook001", own.public_id, "Dune"),
          book_node("foreign001", foreign.public_id, "Theirs"),
          book_node("noBook0001", nil, nil)
        ]
      }

      assert {:ok, post} =
               Content.autosave(scope, %Post{site_id: scope.site.id}, %{"content" => doc})

      assert [%{"id" => "ownBook001", "book_public_id" => book_public_id}] = post.content
      assert book_public_id == own.public_id
    end

    test "creates a new record only once its required fields are valid", %{scope: scope} do
      project = %Project{site_id: scope.site.id}

      assert {:error, %Ecto.Changeset{}} = Content.autosave(scope, project, %{"title" => "P"})
      assert Content.list_projects(scope) == []

      assert {:ok, %Project{id: id}} =
               Content.autosave(scope, project, %{
                 "title" => "P",
                 "slug" => "/p",
                 "short_description" => "Short",
                 "started_at" => "2024-01-01",
                 "links" => %{"0" => %{"label" => "Code", "url" => ""}}
               })

      assert %Project{links: []} = Repo.get!(Project, id)
    end

    test "saves pages and their navigation flag", %{scope: scope} do
      page = page_fixture(scope, title: "About", slug: "/about")

      assert {:ok, saved} =
               Content.autosave(scope, page, %{
                 "title" => "About us",
                 "add_to_navigation" => "true"
               })

      assert saved.title == "About us"
      assert Sites.in_navigation?(saved)
    end

    test "only saves records of the scope's site", %{scope: scope} do
      other = post_fixture(site_scope_fixture())

      assert_raise FunctionClauseError, fn ->
        Content.autosave(scope, other, %{"title" => "Taken over"})
      end
    end
  end

  defp sync(record, order, blocks),
    do: %{lock_version: record.lock_version, order: order, blocks: blocks}

  defp text_node(id, text) do
    %{
      "type" => "paragraph",
      "attrs" => %{"id" => id},
      "content" => [%{"type" => "text", "text" => text}]
    }
  end

  defp image_node(id, image_id, caption) do
    %{
      "type" => "image",
      "attrs" => %{"id" => id, "image_id" => image_id, "src" => "/elsewhere.png"},
      "content" => [%{"type" => "text", "text" => caption}]
    }
  end

  defp book_node(id, book_public_id, title) do
    %{
      "type" => "book",
      "attrs" => %{
        "id" => id,
        "book_public_id" => book_public_id,
        "title" => title,
        "author" => "Someone",
        "cover_url" => nil,
        "emoji" => nil
      }
    }
  end

  defp texts(record), do: Enum.map(Repo.reload!(record).content, & &1["text"])
end
