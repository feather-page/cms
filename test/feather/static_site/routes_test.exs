defmodule Feather.StaticSite.RoutesTest do
  use Feather.DataCase

  alias Feather.Content.{Page, Post, Project}
  alias Feather.Media.{Image, Variants}
  alias Feather.StaticSite.Routes
  alias Feather.StaticSite.Themes.FeatherPage

  setup do
    scope = site_scope_fixture()
    %{scope: scope, routes: Routes.new(scope.site, canonical_url: "https://example.com/")}
  end

  describe "URLs and output paths" do
    test "home and pagination", %{routes: r} do
      assert Routes.home_url(r) == "/"
      assert Routes.home_path(r) == "index.html"
      assert Routes.home_url(r, 3) == "/page/3/"
      assert Routes.home_path(r, 3) == "page/3/index.html"
    end

    test "posts by slug or lowercased public id", %{routes: r} do
      assert Routes.post_url(r, %Post{slug: "/hello-world"}) == "/hello-world/"
      assert Routes.post_path(r, %Post{slug: "/hello-world"}) == "hello-world/index.html"

      post = %Post{slug: nil, public_id: "ABC123xyz789"}
      assert Routes.post_url(r, post) == "/posts/abc123xyz789/"
      assert Routes.post_path(r, post) == "posts/abc123xyz789/index.html"
    end

    test "pages, the homepage is the site root", %{routes: r} do
      assert Routes.page_url(r, %Page{slug: "/about"}) == "/about/"
      assert Routes.page_path(r, %Page{slug: "/a/b"}) == "a/b/index.html"
      assert Routes.page_url(r, %Page{slug: "/"}) == "/"
      assert Routes.page_path(r, %Page{slug: "/"}) == "index.html"
    end

    test "projects under projects/, with or without leading slash", %{routes: r} do
      assert Routes.project_url(r, %Project{slug: "/my-project"}) == "/projects/my-project/"

      assert Routes.project_path(r, %Project{slug: "my-project"}) ==
               "projects/my-project/index.html"
    end

    test "images by variant or file name, unknown variants raise", %{routes: r} do
      image = %Image{public_id: "img123456789"}
      assert Routes.image_url(r, image, Variants.webp(640)) == "/images/img123456789/640.webp"
      assert Routes.image_path(r, image, "1200.jpg") == "images/img123456789/1200.jpg"

      assert Routes.image_srcset(r, image, [960, 640]) ==
               "/images/img123456789/640.webp 640w, /images/img123456789/960.webp 960w"

      assert Routes.image_srcset(r, %{image | width: 800, height: 450}, [640, 960, 1280]) ==
               "/images/img123456789/640.webp 640w, /images/img123456789/960.webp 800w"

      assert_raise ArgumentError, fn -> Routes.image_url(r, image, "640.png") end
    end

    test "font URLs carry a hash of the font's content, output paths do not", %{routes: r} do
      font = "nunito-latin-700.woff2"
      content = File.read!(FeatherPage.font_path(font))
      hash = :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower) |> binary_part(0, 12)

      assert Routes.font_url(r, font) == "/fonts/#{font}?v=#{hash}"
      assert Routes.font_path(r, font) == "fonts/#{font}"
    end

    test "artifacts, unknown ones raise", %{routes: r} do
      assert Routes.artifact_url(r, "feed.xml") == "/feed.xml"
      assert Routes.artifact_path(r, "sitemap.xml") == "sitemap.xml"
      assert Routes.artifact_url(r, "style.css") == "/style.css"
      assert Routes.artifact_path(r, "llms.txt") == "llms.txt"
      assert_raise ArgumentError, fn -> Routes.artifact_url(r, "humans.txt") end
    end

    test "diagrams by file name, other names raise", %{routes: r} do
      name = String.duplicate("ab", 32) <> ".svg"
      assert Routes.diagram_url(r, name) == "/diagrams/#{name}"

      assert Routes.diagram_url(Routes.canonical(r), name) ==
               "https://example.com/diagrams/#{name}"

      assert Routes.diagram_path(r, name) == "diagrams/#{name}"
      assert_raise ArgumentError, fn -> Routes.diagram_path(r, "../feather.db") end
    end

    test "generated images by file name, other names raise", %{routes: r} do
      name = String.duplicate("ab", 32) <> ".png"
      assert Routes.generated_image_url(r, name) == "/images/#{name}"

      assert Routes.generated_image_url(Routes.canonical(r), name) ==
               "https://example.com/images/#{name}"

      assert Routes.generated_image_path(r, name) == "images/#{name}"
      assert_raise ArgumentError, fn -> Routes.generated_image_path(r, "../feather.db") end
    end

    test "Markdown alternates next to the home page and the pages of posts, pages and projects",
         %{routes: r} do
      post = %Post{slug: "/hello"}
      without_slug = %Post{slug: nil, public_id: "ABC123xyz789"}

      assert Routes.markdown_url(r, :home) == "/index.md"
      assert Routes.markdown_path(r, :home) == "index.md"
      assert Routes.markdown_url(r, %Page{slug: "/"}) == "/index.md"

      assert Routes.markdown_url(r, post) == "/hello/index.md"
      assert Routes.markdown_path(r, post) == "hello/index.md"
      assert Routes.markdown_url(r, without_slug) == "/posts/abc123xyz789/index.md"
      assert Routes.markdown_path(r, %Page{slug: "/a/b"}) == "a/b/index.md"
      assert Routes.markdown_url(r, %Project{slug: "/cms"}) == "/projects/cms/index.md"

      assert Routes.markdown_url(Routes.canonical(r), post) ==
               "https://example.com/hello/index.md"
    end

    test "canonical routes", %{routes: r, scope: scope} do
      canonical = Routes.canonical(r)
      assert Routes.post_url(canonical, %Post{slug: "/hello"}) == "https://example.com/hello/"
      assert Routes.artifact_url(canonical, "feed.xml") == "https://example.com/feed.xml"

      plain = Routes.new(scope.site)
      assert Routes.canonical(plain) == plain
    end

    test "preview/1 the preview of a site", %{scope: scope} do
      preview = Routes.preview(scope.site)
      assert preview.site_root == "/preview/#{scope.site.public_id}/"
      assert preview.canonical_url == "https://#{scope.site.domain}/"
      assert Routes.home_url(preview, 2) == "/preview/#{scope.site.public_id}/page/2/"
    end
  end

  describe "resolve/2" do
    test "home and its pages", %{routes: r} do
      for path <- ["", "/", "index.html", "index", "/index.html"] do
        assert Routes.resolve(r, path) == {:home, 1}
      end

      assert Routes.resolve(r, "page/4") == {:home, 4}
      assert Routes.resolve(r, "page/4/index.html") == {:home, 4}
      assert Routes.resolve(r, ["page", "4"]) == {:home, 4}
      assert Routes.resolve(r, "page/0") == nil
    end

    test "artifacts", %{routes: r} do
      assert Routes.resolve(r, "feed.xml") == {:artifact, "feed.xml"}
      assert Routes.resolve(r, "robots.txt") == {:artifact, "robots.txt"}
      assert Routes.resolve(r, "style.css") == {:artifact, "style.css"}
      assert Routes.resolve(r, "llms.txt") == {:artifact, "llms.txt"}
    end

    test "diagrams by file name", %{routes: r} do
      name = String.duplicate("ab", 32) <> ".svg"
      assert Routes.resolve(r, "diagrams/#{name}") == {:diagram, name}
      assert Routes.resolve(r, "diagrams/#{String.upcase(name)}") == nil
      assert Routes.resolve(r, "diagrams/x.svg") == nil
    end

    test "generated images by file name", %{routes: r} do
      name = String.duplicate("ab", 32) <> ".png"
      assert Routes.resolve(r, "images/#{name}") == {:generated_image, name}
      assert Routes.resolve(r, "images/x.png") == nil
    end

    test "image variants of the site only", %{routes: r, scope: scope} do
      image = image_fixture(scope)

      assert {:image, found, %{filename: "960.webp", size: 960}} =
               Routes.resolve(r, "images/#{image.public_id}/960.webp")

      assert found.id == image.id
      assert Routes.resolve(r, "images/#{image.public_id}/960.png") == nil
      assert Routes.resolve(r, "images/#{image.public_id}/mobile_x1.webp") == nil

      other = image_fixture(site_scope_fixture())
      assert Routes.resolve(r, "images/#{other.public_id}/480.webp") == nil
    end

    test "projects by slug", %{routes: r, scope: scope} do
      project = project_fixture(scope, slug: "/alpha")
      assert {:project, %{id: id}} = Routes.resolve(r, "projects/alpha/")
      assert id == project.id
      assert Routes.resolve(r, "projects/missing") == nil
    end

    test "posts by public id (case-insensitive) and by slug, drafts included",
         %{routes: r, scope: scope} do
      post = post_fixture(scope, slug: nil, draft: true)
      assert {:post, %{id: id}} = Routes.resolve(r, "posts/#{String.downcase(post.public_id)}")
      assert id == post.id

      slugged = post_fixture(scope, slug: "/hello")
      assert {:post, %{id: id}} = Routes.resolve(r, "hello")
      assert id == slugged.id
      assert {:post, %{id: ^id}} = Routes.resolve(r, "hello.html")
    end

    test "pages by slug, preferred over posts with the same slug", %{routes: r, scope: scope} do
      page = page_fixture(scope, slug: "/clash")
      post_fixture(scope, slug: "/other")
      Repo.update_all(from(p in Post, where: p.slug == "/other"), set: [slug: "/clash"])

      assert {:page, %{id: id}} = Routes.resolve(r, "clash")
      assert id == page.id
      assert {:page, %{id: ^id}} = Routes.resolve(r, "/clash/index.html")
    end

    test "nested page slugs", %{routes: r, scope: scope} do
      page = page_fixture(scope, slug: "/about/team")
      assert {:page, %{id: id}} = Routes.resolve(r, "about/team/")
      assert id == page.id
    end

    test "reserved prefixes do not fall through to content", %{routes: r} do
      assert Routes.resolve(r, "posts/unknown") == nil
      assert Routes.resolve(r, "images/x/y.webp") == nil
      assert Routes.resolve(r, "projects/") == nil
    end

    test "the Markdown alternates of the home page, posts, pages and projects",
         %{routes: r, scope: scope} do
      post = post_fixture(scope, slug: "/hello", draft: true)
      without_slug = post_fixture(scope, slug: nil)
      page = page_fixture(scope, slug: "/about/team")
      project = project_fixture(scope, slug: "/alpha")

      for {path, record} <- [
            {"hello/index.md", post},
            {"/posts/#{String.downcase(without_slug.public_id)}/index.md", without_slug},
            {"about/team/index.md", page},
            {"projects/alpha/index.md", project}
          ] do
        assert {:markdown, %{id: id}} = Routes.resolve(r, path), path
        assert id == record.id, path
      end

      assert Routes.resolve(r, "index.md") == {:markdown, :home}
      assert Routes.resolve(r, "/index.md") == {:markdown, :home}

      for path <- [
            "page/2/index.md",
            "index.html/index.md",
            "missing/index.md",
            "hello.md",
            "hello.html/index.md",
            "posts/#{String.upcase(without_slug.public_id)}/index.md",
            "hello/index.markdown"
          ] do
        assert Routes.resolve(r, path) == nil, path
      end
    end

    test "content of other sites is not found", %{routes: r} do
      post_fixture(site_scope_fixture(), slug: "/foreign")
      assert Routes.resolve(r, "foreign") == nil
    end
  end
end
