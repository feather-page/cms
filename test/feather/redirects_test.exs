defmodule Feather.RedirectsTest do
  use Feather.DataCase

  alias Feather.{Content, Redirects}
  alias Feather.Redirects.Redirect
  alias Feather.Sites.Site

  setup do
    %{scope: site_scope_fixture()}
  end

  describe "create_redirect/2" do
    test "stores a post, page or project the target leads to as the record", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/rule-of-72"})
      page = page_fixture(scope, %{slug: "/about"})
      project = project_fixture(scope, %{slug: "/feather"})

      assert {:ok, to_post} =
               Redirects.create_redirect(scope, %{
                 old_path: "/posts/rule-of-72",
                 target: "/rule-of-72/"
               })

      assert {:ok, to_page} =
               Redirects.create_redirect(scope, %{old_path: "/me", target: "about"})

      assert {:ok, to_project} =
               Redirects.create_redirect(scope, %{
                 old_path: "/work/feather",
                 target: "/projects/feather"
               })

      assert {to_post.post_id, to_post.target_path} == {post.id, nil}
      assert {to_page.page_id, to_page.target_path} == {page.id, nil}
      assert {to_project.project_id, to_project.target_path} == {project.id, nil}
      assert to_post.kind == :permanent
      assert String.length(to_post.public_id) == 12
    end

    test "stores any other target as its path", %{scope: scope} do
      generated_image = "/images/#{String.duplicate("a", 64)}.png"

      for {given, stored} <- [
            {"/", "/"},
            {"/page/2", "/page/2/"},
            {"feed.xml", "/feed.xml"},
            {generated_image, generated_image},
            {"llms.txt", "/llms.txt"},
            {"/index.md", "/index.md"}
          ] do
        assert {:ok, %Redirect{target_path: ^stored, post_id: nil, page_id: nil}} =
                 Redirects.create_redirect(scope, %{
                   old_path: "/old#{System.unique_integer([:positive])}",
                   target: given
                 })
      end
    end

    test "refuses the Markdown alternate of a post, page or project as the target, not /index.md",
         %{scope: scope} do
      post_fixture(scope, %{slug: "/hello"})
      page_fixture(scope, %{slug: "/about", draft: true})
      project_fixture(scope, %{slug: "/cms"})

      for target <- ["/hello/index.md", "about/index.md", "/projects/cms/index.md"] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: "/old", target: target})

        assert "is the Markdown alternate of a page: choose the page itself" in errors_on(
                 changeset
               ).target
      end

      assert {:ok, %Redirect{target_path: "/index.md"}} =
               Redirects.create_redirect(scope, %{old_path: "/old", target: "/index.md"})
    end

    test "normalizes the old path: a leading slash, no trailing slash, .html kept",
         %{scope: scope} do
      for {given, stored} <- [
            {"posts/rule-of-72/", "/posts/rule-of-72"},
            {" /2013/01/22/how-to-manage.html ", "/2013/01/22/how-to-manage.html"},
            {"/atom.xml", "/atom.xml"}
          ] do
        assert {:ok, %Redirect{old_path: ^stored}} =
                 Redirects.create_redirect(scope, %{old_path: given, target: "/"})
      end
    end

    test "refuses an old path that is a URL where content lives, drafts and generated files included",
         %{scope: scope} do
      page_fixture(scope, %{slug: "/about", draft: true})

      for old_path <- ["/about/", "/feed.xml", "/llms.txt", "/", "/index.md", "/page/2"] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: old_path, target: "/"})

        assert "is already a URL of the site" in errors_on(changeset).old_path
      end
    end

    test "refuses an old path of a file the export writes that is no URL", %{scope: scope} do
      post_fixture(scope, %{slug: "/x"})

      for old_path <- [
            "/404.html",
            "/.htaccess",
            "/404.html.gz",
            "/index.html.br",
            "/x/index.html.gz",
            "/style.css.br",
            "/feed.xml.gz",
            "/#{scope.site.indexnow_key}.txt",
            "/#{scope.site.indexnow_key}.txt.gz"
          ] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: old_path, target: "/"})

        assert "is already a URL of the site" in errors_on(changeset).old_path
      end

      assert {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/x.gz", target: "/"})
      assert {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/old.html.gz", target: "/"})
    end

    test "refuses the /index.html form of a URL where content lives", %{scope: scope} do
      page_fixture(scope, %{slug: "/foo"})
      project_fixture(scope, %{slug: "/cms"})

      for old_path <- ["/foo/index.html", "/projects/cms/index.html"] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: old_path, target: "/"})

        assert "is already a URL of the site" in errors_on(changeset).old_path
      end
    end

    test "refuses the Markdown alternate of a URL where content lives and its precompressed copies",
         %{scope: scope} do
      page_fixture(scope, %{slug: "/foo", draft: true})
      project_fixture(scope, %{slug: "/cms"})

      for old_path <- ["/foo/index.md", "/foo/index.md.br", "/projects/cms/index.md.gz"] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: old_path, target: "/"})

        assert "is already a URL of the site" in errors_on(changeset).old_path
      end

      assert {:ok, _} =
               Redirects.create_redirect(scope, %{old_path: "/bar/index.md", target: "/"})
    end

    test "refuses an old path a published version serves", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, _} = Content.update_post(scope, post, %{slug: "/b"})
      project = project_fixture(scope, %{slug: "/cms"})
      {:ok, _} = Content.update_project(scope, project, %{slug: "/feather"})
      slugless = post_fixture(scope, %{slug: nil})
      {:ok, _} = Content.update_post(scope, slugless, %{slug: "/named"})

      for old_path <- [
            "/a",
            "/a.html",
            "/a/index.md",
            "/projects/cms",
            "/projects/cms/index.md",
            "/posts/#{slugless.public_id}"
          ] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: old_path, target: "/b/"})

        assert "is already a URL of the site" in errors_on(changeset).old_path
      end
    end

    test "refuses an old path towards a redirect: the target is content", %{scope: scope} do
      post_fixture(scope, %{slug: "/b"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a", target: "/b/"})

      assert {:error, changeset} =
               Redirects.create_redirect(scope, %{old_path: "/b", target: "/"})

      assert "is already a URL of the site" in errors_on(changeset).old_path

      assert {:error, changeset} =
               Redirects.create_redirect(scope, %{old_path: "/c", target: "/a"})

      assert "does not lead to anything on the site" in errors_on(changeset).target
    end

    test "refuses another redirect's old path, of the site only", %{scope: scope} do
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/"})

      assert {:error, changeset} =
               Redirects.create_redirect(scope, %{old_path: "/old/", target: "/feed.xml"})

      assert "already has a redirect" in errors_on(changeset).old_path

      assert {:ok, _} =
               Redirects.create_redirect(site_scope_fixture(), %{old_path: "/old", target: "/"})
    end

    test "refuses an old path with a query, a fragment, a space or a line break", %{scope: scope} do
      for old_path <- ["/old?p=1", "/old#top", "/old post", "/old\npost", "/old\rpost"] do
        assert {:error, changeset} =
                 Redirects.create_redirect(scope, %{old_path: old_path, target: "/"})

        assert "may only contain the characters of a URL path, without ? or #" in errors_on(
                 changeset
               ).old_path
      end
    end

    test "requires an old path and a target that resolves, on the site", %{scope: scope} do
      other_post = post_fixture(site_scope_fixture(), %{slug: "/elsewhere"})

      assert {:error, changeset} = Redirects.create_redirect(scope, %{old_path: "", target: ""})
      assert "can't be blank" in errors_on(changeset).old_path
      assert "can't be blank" in errors_on(changeset).target

      assert {:error, changeset} =
               Redirects.create_redirect(scope, %{old_path: "/x", target: other_post.slug})

      assert "does not lead to anything on the site" in errors_on(changeset).target
    end

    test "stores a temporary redirect", %{scope: scope} do
      assert {:ok, %Redirect{kind: :temporary}} =
               Redirects.create_redirect(scope, %{old_path: "/x", target: "/", kind: "temporary"})
    end

    test "moves the site's updated_at", %{scope: scope} do
      before = site_updated_at(scope)
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/"})

      assert DateTime.after?(site_updated_at(scope), before)
    end
  end

  describe "create_redirects/2" do
    test "saves the valid lines as permanent redirects and returns each line with its result",
         %{scope: scope} do
      post = post_fixture(scope, %{slug: "/rule-of-72"})
      page_fixture(scope, %{slug: "/about"})

      text = """
      /posts/rule-of-72   /rule-of-72/

      /about /
      \t/old\t/nowhere\r
      /lonely
      """

      assert [
               {"/posts/rule-of-72   /rule-of-72/", {:ok, %Redirect{} = saved}},
               {"/about /", {:error, held}},
               {"/old\t/nowhere", {:error, unresolvable}},
               {"/lonely", {:error, missing}}
             ] = Redirects.create_redirects(scope, text)

      assert {saved.old_path, saved.post_id, saved.kind} ==
               {"/posts/rule-of-72", post.id, :permanent}

      assert "is already a URL of the site" in errors_on(held).old_path
      assert "does not lead to anything on the site" in errors_on(unresolvable).target
      assert "can't be blank" in errors_on(missing).target
      assert [%{old_path: "/posts/rule-of-72"}] = Redirects.list_redirects(scope)
    end

    test "refuses a line whose target is the Markdown alternate of a post, not one to /index.md",
         %{scope: scope} do
      post_fixture(scope, %{slug: "/hello"})

      assert [{"/a /hello/index.md", {:error, changeset}}, {"/b /index.md", {:ok, saved}}] =
               Redirects.create_redirects(scope, "/a /hello/index.md\n/b /index.md")

      assert "is the Markdown alternate of a page: choose the page itself" in errors_on(changeset).target
      assert saved.target_path == "/index.md"
      assert [%{old_path: "/b"}] = Redirects.list_redirects(scope)
    end

    test "refuses a line whose old path an earlier line took", %{scope: scope} do
      assert [{_, {:ok, _}}, {_, {:error, changeset}}] =
               Redirects.create_redirects(scope, "/old /\n/old/ /feed.xml")

      assert "already has a redirect" in errors_on(changeset).old_path
    end

    test "returns nothing for blank text", %{scope: scope} do
      assert Redirects.create_redirects(scope, " \n\n") == []
    end
  end

  describe "find_active_redirect/2" do
    test "finds the redirect of an old path, with and without a trailing slash",
         %{scope: scope} do
      post_fixture(scope, %{slug: "/rule-of-72"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/posts/rule-of-72", target: "/"})

      {:ok, _} =
        Redirects.create_redirect(scope, %{
          old_path: "/2013/how-to.html",
          target: "/rule-of-72/"
        })

      assert %Redirect{old_path: "/posts/rule-of-72", target: "/"} =
               Redirects.find_active_redirect(scope, "posts/rule-of-72")

      assert %Redirect{old_path: "/posts/rule-of-72"} =
               Redirects.find_active_redirect(scope, "/posts/rule-of-72/")

      assert %Redirect{target: "/rule-of-72/"} =
               Redirects.find_active_redirect(scope, ["2013", "how-to.html"])

      assert Redirects.find_active_redirect(scope, "/posts") == nil
      assert Redirects.find_active_redirect(site_scope_fixture(), "/posts/rule-of-72") == nil
    end

    test "finds the redirect of an old path without an extension at its index.html, after an active one from that file",
         %{scope: scope} do
      post_fixture(scope, %{slug: "/neu"})
      page = page_fixture(scope, %{slug: "/other"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/alt", target: "/neu"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/b.html", target: "/neu"})

      assert %Redirect{old_path: "/alt", target: "/neu/"} =
               Redirects.find_active_redirect(scope, ["alt", "index.html"])

      assert Redirects.find_active_redirect(scope, "/b.html/index.html") == nil

      {:ok, _} =
        Redirects.create_redirect(scope, %{old_path: "/alt/index.html", target: "/other"})

      assert %Redirect{old_path: "/alt/index.html", target: "/other/"} =
               Redirects.find_active_redirect(scope, "/alt/index.html")

      assert %Redirect{old_path: "/alt"} = Redirects.find_active_redirect(scope, "/alt/")

      {:ok, _} = Content.unpublish(scope, page)

      assert %Redirect{old_path: "/alt"} =
               Redirects.find_active_redirect(scope, "/alt/index.html")
    end

    test "leads an old path's index.md to the Markdown alternate of the target, or to a target without one",
         %{scope: scope} do
      post = post_fixture(scope, %{slug: "/neu"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/alt", target: "/neu"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/start", target: "/"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/rss", target: "/feed.xml"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/b.html", target: "/neu"})
      {:ok, _} = Content.update_post(scope, post, %{slug: "/unpublished"})

      assert %Redirect{old_path: "/alt", target: "/unpublished/index.md"} =
               Redirects.find_active_redirect(scope, ["alt", "index.md"])

      assert %Redirect{target: "/unpublished/"} = Redirects.find_active_redirect(scope, "/alt/")

      assert %Redirect{target: "/index.md"} =
               Redirects.find_active_redirect(scope, "/start/index.md")

      assert %Redirect{target: "/feed.xml"} =
               Redirects.find_active_redirect(scope, "/rss/index.md")

      assert Redirects.find_active_redirect(scope, "/b.html/index.md") == nil

      {:ok, _} =
        Redirects.create_redirect(scope, %{old_path: "/alt/index.md", target: "/llms.txt"})

      assert %Redirect{old_path: "/alt/index.md", target: "/llms.txt"} =
               Redirects.find_active_redirect(scope, "/alt/index.md")
    end

    test "leaves out an inactive redirect", %{scope: scope} do
      page = page_fixture(scope, %{slug: "/target"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/target"})
      {:ok, _} = Content.unpublish(scope, page)

      assert Redirects.find_active_redirect(scope, "/old") == nil
    end
  end

  describe "update_redirect/3" do
    test "changes old path, target and kind and moves the site's updated_at", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/now"})
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/"})
      redirect = Redirects.get_redirect!(scope, redirect.public_id)
      before = site_updated_at(scope)

      assert {:ok, updated} =
               Redirects.update_redirect(scope, redirect, %{
                 old_path: "/current",
                 target: "/now/",
                 kind: "temporary"
               })

      assert {updated.old_path, updated.post_id, updated.target_path, updated.kind} ==
               {"/current", post.id, nil, :temporary}

      assert DateTime.after?(site_updated_at(scope), before)
    end

    test "keeps the stored target when it is not changed", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/now"})
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/now"})
      redirect = Redirects.get_redirect!(scope, redirect.public_id)

      assert redirect.target == "/now/"

      assert {:ok, %Redirect{post_id: post_id, kind: :temporary}} =
               Redirects.update_redirect(scope, redirect, %{kind: "temporary", target: "/now/"})

      assert post_id == post.id
    end

    test "leaves the site's updated_at when nothing changes", %{scope: scope} do
      post_fixture(scope, %{slug: "/now"})
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/now"})
      redirect = Redirects.get_redirect!(scope, redirect.public_id)
      Repo.update_all(Site, set: [updated_at: ~U[2026-01-01 00:00:00.000000Z]])

      assert {:ok, _} =
               Redirects.update_redirect(scope, redirect, %{
                 old_path: "/x/",
                 target: "/now",
                 kind: "permanent"
               })

      assert site_updated_at(scope) == ~U[2026-01-01 00:00:00.000000Z]
      assert Repo.reload!(redirect).updated_at == redirect.updated_at
    end

    test "refuses the Markdown alternate of a post as the target, not /index.md", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/hello"})
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/hello"})
      redirect = Redirects.get_redirect!(scope, redirect.public_id)

      assert {:error, changeset} =
               Redirects.update_redirect(scope, redirect, %{target: "/hello/index.md"})

      assert "is the Markdown alternate of a page: choose the page itself" in errors_on(changeset).target
      assert Repo.reload!(redirect).post_id == post.id

      assert {:ok, %Redirect{target_path: "/index.md", post_id: nil}} =
               Redirects.update_redirect(scope, redirect, %{target: "/index.md"})
    end

    test "keeps its own old path", %{scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/"})
      redirect = Redirects.get_redirect!(scope, redirect.public_id)

      assert {:ok, _} = Redirects.update_redirect(scope, redirect, %{old_path: "/x/"})
    end
  end

  describe "delete_redirect/2" do
    test "deletes the redirect and moves the site's updated_at", %{scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/"})
      before = site_updated_at(scope)

      assert {:ok, _} = Redirects.delete_redirect(scope, redirect)
      assert Redirects.list_redirects(scope) == []
      assert DateTime.after?(site_updated_at(scope), before)
    end
  end

  describe "a redirect deleted elsewhere" do
    test "is neither updated nor deleted", %{scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/"})
      {:ok, _} = Redirects.delete_redirect(scope, redirect)

      assert Redirects.update_redirect(scope, redirect, %{old_path: "/y"}) == {:error, :stale}
      assert Redirects.delete_redirect(scope, redirect) == {:error, :stale}
    end
  end

  describe "listing and lookup" do
    test "lists the site's redirects by old path, with the URL the target is published at",
         %{scope: scope} do
      post = post_fixture(scope, %{title: "Old", slug: "/old-slug"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/b", target: "/feed.xml"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a", target: "/old-slug/"})
      {:ok, post} = Content.update_post(scope, post, %{title: "New", slug: "/new-slug"})
      {:ok, _} = Redirects.create_redirect(site_scope_fixture(), %{old_path: "/c", target: "/"})

      assert [
               %{old_path: "/a", target: "/old-slug/", post: %{id: post_id, title: "Old"}},
               %{old_path: "/b"}
             ] = Redirects.list_redirects(scope)

      assert post_id == post.id

      {:ok, _} = Content.publish(scope, post)
      redirect = Redirects.find_active_redirect(scope, "/a")
      assert redirect.target == "/new-slug/"
      assert Redirects.get_redirect!(scope, redirect.public_id).target == "/new-slug/"
    end

    test "shows a draft target at its current URL", %{scope: scope} do
      page = page_fixture(scope, %{slug: "/later", draft: true})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/soon", target: "/later"})

      assert [%{target: "/later/", page: %{id: page_id}}] = Redirects.list_redirects(scope)
      assert page_id == page.id
    end

    test "finds a redirect of another site nowhere", %{scope: scope} do
      {:ok, redirect} =
        Redirects.create_redirect(site_scope_fixture(), %{old_path: "/x", target: "/"})

      assert Redirects.get_redirect(scope, redirect.public_id) == nil

      assert_raise Ecto.NoResultsError, fn ->
        Redirects.get_redirect!(scope, redirect.public_id)
      end
    end

    test "deleting the target record deletes its redirects", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/target"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/x", target: "/target"})

      {:ok, _} = Content.delete_post(scope, post)

      assert Redirects.list_redirects(scope) == []
    end
  end

  describe "active?/2" do
    test "a redirect is active while its target record is published", %{scope: scope} do
      page = page_fixture(scope, %{slug: "/target"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/target"})
      [redirect] = Redirects.list_redirects(scope)
      assert Redirects.active?(scope, redirect)

      {:ok, _} = Content.unpublish(scope, page)
      [redirect] = Redirects.list_redirects(scope)
      refute Redirects.active?(scope, redirect)
    end

    test "a redirect to a scheduled post is inactive until the post is due", %{scope: scope} do
      post_fixture(scope, %{slug: "/later", publish_at: DateTime.add(DateTime.utc_now(), 1, :day)})

      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/later/"})

      [redirect] = Redirects.list_redirects(scope)
      refute Redirects.active?(scope, redirect)
      assert Redirects.find_active_redirect(scope, "/old") == nil
    end

    test "a redirect to a path is active while the path resolves", %{scope: scope} do
      image = image_fixture(scope)
      target = "/images/#{image.public_id}/480.webp"
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/old.jpg", target: target})
      [redirect] = Redirects.list_redirects(scope)
      assert redirect.target_path == target
      assert Redirects.active?(scope, redirect)

      Repo.delete!(image)
      refute Redirects.active?(scope, redirect)
    end
  end

  describe "publishing a record under a new URL" do
    test "renaming back to an old slug deletes its redirect and redirects the URL it leaves",
         %{scope: scope} do
      post = post_fixture(scope, %{slug: "/b"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a", target: "/b/"})

      {:ok, post} = Content.update_post(scope, post, %{slug: "/a"})
      {:ok, _post} = Content.publish(scope, post)

      assert [%Redirect{old_path: "/b", kind: :permanent} = redirect] =
               Redirects.list_redirects(scope)

      assert redirect.post_id == post.id
    end

    test "publishing deletes a redirect to the record from its URL's /index.html form, not from the .html form",
         %{scope: scope} do
      post = post_fixture(scope, %{slug: "/b"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a/index.html", target: "/b/"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a.html", target: "/b/"})

      {:ok, post} = Content.update_post(scope, post, %{slug: "/a"})
      {:ok, _post} = Content.publish(scope, post)

      assert scope |> Redirects.list_redirects() |> Enum.map(& &1.old_path) == ["/a.html", "/b"]
    end

    test "publishing deletes a redirect from its URL's Markdown alternate", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/b"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a/index.md", target: "/b/"})

      {:ok, post} = Content.update_post(scope, post, %{slug: "/a"})
      {:ok, _post} = Content.publish(scope, post)

      assert scope |> Redirects.list_redirects() |> Enum.map(& &1.old_path) == ["/b"]
    end

    test "redirects the old URL of a page and of a project, under /projects/", %{scope: scope} do
      page = page_fixture(scope, %{slug: "/about"})
      project = project_fixture(scope, %{slug: "/cms"})

      {:ok, page} = Content.update_page(scope, page, %{slug: "/me"})
      {:ok, _} = Content.publish(scope, page)
      {:ok, project} = Content.update_project(scope, project, %{slug: "/feather"})
      {:ok, _} = Content.publish(scope, project)

      assert [
               %Redirect{old_path: "/about", page_id: page_id},
               %Redirect{old_path: "/projects/cms", project_id: project_id}
             ] = Redirects.list_redirects(scope)

      assert {page_id, project_id} == {page.id, project.id}
    end

    test "redirects the public id URL of a post that got a slug", %{scope: scope} do
      post = post_fixture(scope, %{slug: nil})
      {:ok, post} = Content.update_post(scope, post, %{slug: "/named"})
      {:ok, _} = Content.publish(scope, post)

      old_path = "/posts/" <> String.downcase(post.public_id)
      assert [%Redirect{old_path: ^old_path, target: "/named/"}] = Redirects.list_redirects(scope)
    end

    test "stores no redirect from an old URL another record holds, draft included",
         %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, post} = Content.update_post(scope, post, %{slug: "/b"})
      page_fixture(scope, %{slug: "/a", draft: true})

      {:ok, _} = Content.publish(scope, post)

      assert Redirects.list_redirects(scope) == []
    end

    test "stores no redirect from an old URL another record is published at", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, post} = Content.unpublish(scope, post)
      {:ok, post} = Content.update_post(scope, post, %{slug: "/b"})
      other = page_fixture(scope, %{slug: "/a"})
      {:ok, _} = Content.update_page(scope, other, %{slug: "/elsewhere"})

      {:ok, _} = Content.publish(scope, post)

      assert Redirects.list_redirects(scope) == []
    end

    test "stores no redirect from an old URL that is no valid old path", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})

      # Imported versions may hold slugs the slug format refuses.
      Repo.update_all(from(v in Feather.Content.PostVersion, where: v.post_id == ^post.id),
        set: [slug: "/Old Post?"]
      )

      {:ok, post} = Content.update_post(scope, post, %{slug: "/b"})

      assert {:ok, _} = Content.publish(scope, post)
      assert Redirects.list_redirects(scope) == []
    end

    test "stores no redirect from the site root a homepage leaves", %{scope: scope} do
      {:ok, page} = Content.publish(scope, Content.get_homepage(scope))
      {:ok, page} = Content.update_page(scope, page, %{slug: "/welcome"})
      {:ok, _} = Content.publish(scope, page)

      assert Redirects.list_redirects(scope) == []
    end

    test "replaces a redirect from the old URL", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, post} = Content.update_post(scope, post, %{slug: "/b"})

      # Saving it is refused now that the post is published at /a; older data may hold one.
      %Redirect{site_id: scope.site.id, old_path: "/a", kind: :temporary, target_path: "/"}
      |> Ecto.Changeset.change()
      |> Feather.PublicId.put()
      |> Repo.insert!()

      {:ok, _} = Content.publish(scope, post)

      assert [%Redirect{old_path: "/a", kind: :permanent, target_path: nil, post_id: post_id}] =
               Redirects.list_redirects(scope)

      assert post_id == post.id
    end

    test "redirects the URL it was last published at after an unpublish", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, post} = Content.unpublish(scope, post)
      {:ok, post} = Content.update_post(scope, post, %{slug: "/b"})

      {:ok, _} = Content.publish(scope, post)

      assert [%Redirect{old_path: "/a"}] = Redirects.list_redirects(scope)
    end

    test "moves the site's updated_at", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, post} = Content.update_post(scope, post, %{slug: "/b"})
      Repo.update_all(Site, set: [updated_at: ~U[2026-01-01 00:00:00.000000Z]])

      {:ok, _} = Content.publish(scope, post)

      assert DateTime.after?(site_updated_at(scope), ~U[2026-01-01 00:00:00.000000Z])
    end

    test "moves the site's updated_at when it only deletes a redirect", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/b"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a", target: "/b/"})
      {:ok, post} = Content.update_post(scope, post, %{slug: "/a"})
      page_fixture(scope, %{slug: "/b", draft: true})
      Repo.update_all(Site, set: [updated_at: ~U[2026-01-01 00:00:00.000000Z]])

      {:ok, _} = Content.publish(scope, post)

      assert Redirects.list_redirects(scope) == []
      assert DateTime.after?(site_updated_at(scope), ~U[2026-01-01 00:00:00.000000Z])
    end

    test "stores nothing when the URL stays", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/a"})
      {:ok, post} = Content.update_post(scope, post, %{title: "Renamed"})
      {:ok, _} = Content.publish(scope, post)

      assert Redirects.list_redirects(scope) == []
    end
  end

  describe "slugs and the old paths of redirects" do
    test "a slug cannot take a URL a redirect holds", %{scope: scope} do
      post_fixture(scope, %{title: "Linchpin: Are you indispensable?", slug: "/linchpin-book"})

      {:ok, redirect} =
        Redirects.create_redirect(scope, %{old_path: "/linchpin", target: "/linchpin-book/"})

      assert {:error, changeset} =
               Content.create_page(scope, %{title: "Linchpin", slug: "/linchpin"})

      assert "has already been taken by a redirect" in errors_on(changeset).slug

      {:ok, _} = Redirects.delete_redirect(scope, redirect)
      assert {:ok, _page} = Content.create_page(scope, %{title: "Linchpin", slug: "/linchpin"})
    end

    test "a slug cannot take a URL a redirect holds in its .html form", %{scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/about.html", target: "/"})

      assert {:error, changeset} = Content.create_page(scope, %{title: "About", slug: "/about"})
      assert "has already been taken by a redirect" in errors_on(changeset).slug

      {:ok, _} = Redirects.delete_redirect(scope, redirect)
      assert {:ok, _page} = Content.create_page(scope, %{title: "About", slug: "/about"})
    end

    test "a slug cannot take a URL a redirect holds in its /index.html form", %{scope: scope} do
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/foo/index.html", target: "/"})

      {:ok, _} =
        Redirects.create_redirect(scope, %{old_path: "/projects/cms/index.html", target: "/"})

      assert {:error, changeset} = Content.create_page(scope, %{title: "Foo", slug: "/foo"})
      assert "has already been taken by a redirect" in errors_on(changeset).slug

      assert {:error, changeset} =
               Content.create_project(scope, %{
                 title: "CMS",
                 slug: "/cms",
                 short_description: "S",
                 started_at: ~D[2024-03-01]
               })

      assert "has already been taken by a redirect" in errors_on(changeset).slug
    end

    test "a slug cannot take a URL a redirect holds in its Markdown alternate", %{scope: scope} do
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/foo/index.md", target: "/"})

      assert {:error, changeset} = Content.create_page(scope, %{title: "Foo", slug: "/foo"})
      assert "has already been taken by a redirect" in errors_on(changeset).slug
    end

    test "a slug may take the URL of a redirect to its own record", %{scope: scope} do
      post = post_fixture(scope, %{slug: "/b"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/a", target: "/b/"})

      assert {:error, changeset} = Content.create_post(scope, %{title: "x", slug: "/a"})
      assert "has already been taken by a redirect" in errors_on(changeset).slug

      assert {:ok, _post} = Content.update_post(scope, post, %{slug: "/a"})
    end

    test "a project's URL lies under /projects/", %{scope: scope} do
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/projects/old", target: "/"})
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/new", target: "/"})

      attrs = %{title: "P", short_description: "S", started_at: ~D[2024-03-01]}

      assert {:error, changeset} = Content.create_project(scope, Map.put(attrs, :slug, "/old"))
      assert "has already been taken by a redirect" in errors_on(changeset).slug
      assert {:ok, _project} = Content.create_project(scope, Map.put(attrs, :slug, "/new"))
    end

    test "a suggested slug leaves out URLs redirects hold", %{scope: scope} do
      {:ok, _} = Redirects.create_redirect(scope, %{old_path: "/linchpin", target: "/"})

      assert Content.suggest_slug(scope, "Linchpin") == "/linchpin1"
    end
  end

  defp site_updated_at(%{site: %Site{id: id}}), do: Repo.get!(Site, id).updated_at
end
