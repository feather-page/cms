defmodule Feather.StaticSite.RoutesTest do
  use Feather.DataCase

  alias Feather.Content.{Page, Post, Project}
  alias Feather.Media.Image
  alias Feather.Publishing.DeploymentTarget
  alias Feather.StaticSite.Routes

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
      assert Routes.project_path(r, %Project{slug: "my-project"}) == "projects/my-project/index.html"
    end

    test "images by variant name or file name, unknown variants raise", %{routes: r} do
      image = %Image{public_id: "img123456789"}
      assert Routes.image_url(r, image, :mobile_x1_webp) == "/images/img123456789/mobile_x1.webp"
      assert Routes.image_path(r, image, "desktop_x1.jpg") == "images/img123456789/desktop_x1.jpg"

      assert Routes.image_srcset(r, image) =~
               "/images/img123456789/mobile_x1.webp 430w, /images/img123456789/mobile_x2.webp 860w"

      assert_raise ArgumentError, fn -> Routes.image_url(r, image, :desktop_x1_png) end
    end

    test "artifacts, unknown ones raise", %{routes: r} do
      assert Routes.artifact_url(r, "feed.xml") == "/feed.xml"
      assert Routes.artifact_path(r, "sitemap.xml") == "sitemap.xml"
      assert_raise ArgumentError, fn -> Routes.artifact_url(r, "humans.txt") end
    end

    test "canonical routes", %{routes: r, scope: scope} do
      canonical = Routes.canonical(r)
      assert Routes.post_url(canonical, %Post{slug: "/hello"}) == "https://example.com/hello/"
      assert Routes.artifact_url(canonical, "feed.xml") == "https://example.com/feed.xml"

      plain = Routes.new(scope.site)
      assert Routes.canonical(plain) == plain
    end

    test "for/2 deployed and preview", %{scope: scope} do
      target = %DeploymentTarget{
        site: scope.site,
        public_id: "dt0123456789",
        public_hostname: "example.com"
      }

      deployed = Routes.for(target, :deployed)
      assert {deployed.site_root, deployed.canonical_url} == {"/", "https://example.com/"}

      preview = Routes.for(target, :preview)
      assert preview.site_root == "/preview/dt0123456789/"
      assert preview.canonical_url == "https://example.com/"
      assert Routes.home_url(preview, 2) == "/preview/dt0123456789/page/2/"
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
    end

    test "image variants of the site only", %{routes: r, scope: scope} do
      image = image_fixture(scope)

      assert {:image, found, %{name: :mobile_x2_webp}} =
               Routes.resolve(r, "images/#{image.public_id}/mobile_x2.webp")

      assert found.id == image.id
      assert Routes.resolve(r, "images/#{image.public_id}/mobile_x2.png") == nil

      other = image_fixture(site_scope_fixture())
      assert Routes.resolve(r, "images/#{other.public_id}/mobile_x1.webp") == nil
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

    test "content of other sites is not found", %{routes: r} do
      post_fixture(site_scope_fixture(), slug: "/foreign")
      assert Routes.resolve(r, "foreign") == nil
    end
  end
end
