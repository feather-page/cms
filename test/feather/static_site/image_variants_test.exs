defmodule Feather.StaticSite.ImageVariantsTest do
  use Feather.DataCase

  alias Feather.{Content, Media, Sites}
  alias Feather.Media.Variants
  alias Feather.StaticSite.ImageVariants

  setup do
    %{scope: site_scope_fixture()}
  end

  defp image(scope), do: image_fixture(scope, width: 3000, height: 2000)

  defp roles(site, image), do: site |> ImageVariants.image_roles() |> Map.get(image.id, [])

  describe "image_roles/1" do
    test "follows from what references the image, drafts and published versions included",
         %{scope: scope} do
      [content, header, thumbnail, draft_header, home, project_header, cover, unused] =
        for _ <- 1..8, do: image(scope)

      post_fixture(scope, %{
        content: [image_block(content)],
        header_image_id: header.id,
        thumbnail_image_id: thumbnail.id
      })

      page_fixture(scope, %{header_image_id: draft_header.id, draft: true})
      homepage = scope |> Content.list_pages() |> Enum.find(&Content.Page.homepage?/1)
      {:ok, homepage} = Content.update_page(scope, homepage, %{header_image_id: home.id})
      {:ok, _homepage} = Content.publish(scope, homepage)
      project_fixture(scope, %{header_image_id: project_header.id})
      book_fixture(scope, %{cover_image_id: cover.id})
      site = scope.site

      assert roles(site, content) == [:content]
      assert roles(site, header) == [:header, :sharing]
      assert roles(site, thumbnail) == [:thumbnail]
      assert roles(site, draft_header) == [:header, :sharing]
      assert roles(site, home) == [:homepage_header, :sharing]
      assert roles(site, project_header) == [:project_header, :sharing]
      assert roles(site, cover) == [:book_cover]
      assert roles(site, unused) == []
    end

    test "a published version keeps the roles its images had when it was published",
         %{scope: scope} do
      [old, new] = for _ <- 1..2, do: image(scope)
      post = post_fixture(scope, %{header_image_id: old.id})
      {:ok, _post} = Content.update_post(scope, post, %{header_image_id: new.id})

      assert roles(scope.site, old) == [:header, :sharing]
      assert roles(scope.site, new) == [:header, :sharing]
    end

    test "the sharing image is the header, else the thumbnail, else the first content image",
         %{scope: scope} do
      [thumbnail, first, second] = for _ <- 1..3, do: image(scope)

      post_fixture(scope, %{thumbnail_image_id: thumbnail.id, content: [image_block(first)]})
      page_fixture(scope, %{content: [image_block(first), image_block(second)]})

      assert roles(scope.site, thumbnail) == [:sharing, :thumbnail]
      assert roles(scope.site, first) == [:content, :sharing]
      assert roles(scope.site, second) == [:content]
    end

    test "the first content image that still exists is shared, as the renderer picks it",
         %{scope: scope} do
      [deleted, shown] = for _ <- 1..2, do: image(scope)
      post_fixture(scope, %{content: [image_block(deleted), image_block(shown)]})
      {:ok, _} = Media.delete_image(deleted)

      assert roles(scope.site, shown) == [:content, :sharing]
    end

    test "includes the site's portrait and mascots", %{scope: scope} do
      path = test_image_path(600, 600)
      {:ok, _site} = Sites.put_portrait(scope, path, "me.png")
      {:ok, site} = Sites.put_mascot(scope, :footer, path, "mice.png")
      File.rm(path)

      roles = ImageVariants.image_roles(site)

      assert roles[site.portrait_image_id] == [:portrait]
      assert roles[site.footer_mascot_image_id] == [:footer_mascot]
    end

    test "the portrait of a site with a fediverse name is also the account's picture",
         %{scope: scope} do
      path = test_image_path(600, 600)
      {:ok, site} = Sites.put_portrait(scope, path, "me.png")
      File.rm(path)

      {:ok, site} =
        Feather.Fediverse.update_name(%{scope | site: site}, %{"fediverse_name" => "timon"})

      assert ImageVariants.image_roles(site)[site.portrait_image_id] == [
               :account_picture,
               :portrait
             ]
    end
  end

  describe "variants/3" do
    test "the union of the variants the theme gives the image's roles", %{scope: scope} do
      image = image(scope)
      feather = scope.site
      sidebar = %{feather | theme: "simple_sidebar"}

      assert ImageVariants.variants(feather, image, [:book_cover]) ==
               Enum.map([180, 360, 540], &Variants.webp/1)

      assert ImageVariants.variants(sidebar, image, [:book_cover]) ==
               Enum.map([64, 128], &Variants.webp/1)

      assert ImageVariants.variants(sidebar, image, [:portrait, :sharing]) ==
               [Variants.webp(120), Variants.webp(240), Variants.webp(360), Variants.sharing()]

      assert ImageVariants.variants(feather, image, [:portrait]) == []

      assert ImageVariants.variants(feather, image, [:account_picture, :portrait]) ==
               [Variants.jpg(400)]
    end

    test "sizes an image is too small for collapse per role", %{scope: scope} do
      small = image_fixture(scope, width: 700, height: 500)

      assert ImageVariants.variants(scope.site, small, [:content, :thumbnail]) ==
               Enum.map([640, 960, 240, 480], &Variants.webp/1)
    end
  end

  describe "sync_site/1" do
    test "gives every image of the site exactly the variants of its roles, also when the theme changes",
         %{scope: scope} do
      [cover, unused] = for _ <- 1..2, do: image(scope)
      book_fixture(scope, %{cover_image_id: cover.id})
      File.write!(Path.join(Media.image_dir(unused), "mobile_x1.webp"), "legacy")

      assert ImageVariants.sync_site(scope.site) == :ok

      assert Media.variant_filenames(cover) == ~w(180.webp 360.webp 480.webp 540.webp)
      assert Media.variant_filenames(unused) == ["480.webp"]

      {:ok, _site} = Sites.update_site(scope, scope.site, %{theme: "simple_sidebar"})

      assert Media.variant_filenames(cover) == ~w(128.webp 480.webp 64.webp)
    end
  end

  describe "backfill/0" do
    test "syncs the images of every site and leaves needed files untouched", %{scope: scope} do
      other = site_scope_fixture()
      cover = image(scope)
      portrait_path = test_image_path(600, 600)
      {:ok, site} = Sites.put_portrait(other, portrait_path, "me.png")
      File.rm(portrait_path)
      {:ok, _site} = Sites.update_site(other, site, %{theme: "simple_sidebar"})
      portrait = Repo.get!(Media.Image, site.portrait_image_id)
      book_fixture(scope, %{cover_image_id: cover.id})
      File.write!(Media.variant_path(cover, "480.webp"), "untouched")
      File.write!(Path.join(Media.image_dir(cover), "mobile_x1.webp"), "legacy")
      File.write!(Path.join(Media.image_dir(portrait), "desktop_x2.webp"), "legacy")

      assert ImageVariants.backfill() == :ok

      assert Media.variant_filenames(cover) == ~w(180.webp 360.webp 480.webp 540.webp)
      assert File.read!(Media.variant_path(cover, "480.webp")) == "untouched"
      assert Media.variant_filenames(portrait) == ~w(120.webp 240.webp 360.webp 480.webp)
    end
  end

  describe "uploads" do
    test "a role's upload gets exactly the variants of that role", %{scope: scope} do
      path = test_image_path(1200, 1800)
      {:ok, site} = Sites.put_portrait(scope, path, "me.png")
      File.rm(path)

      portrait = Repo.get!(Media.Image, site.portrait_image_id)
      assert Media.variant_filenames(portrait) == ["480.webp"]

      book = book_fixture(scope)
      path = test_image_path(400, 600)
      {:ok, book} = Feather.Books.attach_cover_from_upload(scope, book, path, "cover.png")
      File.rm(path)

      cover = Repo.get!(Media.Image, book.cover_image_id)
      assert Media.variant_filenames(cover) == ~w(180.webp 360.webp 480.webp 540.webp)
    end
  end
end
