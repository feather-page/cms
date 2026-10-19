defmodule Feather.StaticSite.SiteDataTest do
  use Feather.DataCase

  alias Feather.Media
  alias Feather.Media.Image
  alias Feather.Sites
  alias Feather.StaticSite.{Export, RecordingSink, Routes, SiteData}

  setup do
    scope = site_scope_fixture()
    path = test_image_path()
    {:ok, _} = Sites.put_mascot(scope, :footer, path, "mice.png")
    {:ok, site} = Sites.put_mascot(scope, :projects, path, "draw.png")
    File.rm(path)

    %{scope: scope, site: Repo.get!(Sites.Site, site.id)}
  end

  describe "mascots" do
    test "load/2 preloads the mascot images, nil for an empty slot", %{site: site} do
      for content <- [:published, :current] do
        data = SiteData.load(site, content: content)

        assert %Image{filename: "mice.png"} = data.site.footer_mascot_image
        assert data.site.post_end_mascot_image == nil
        assert %Image{filename: "draw.png"} = data.site.projects_mascot_image
      end
    end

    test "images_in_use/1 includes the mascot images", %{site: site} do
      for content <- [:published, :current] do
        data = SiteData.load(site, content: content)

        assert data |> SiteData.images_in_use() |> Enum.map(& &1.id) |> Enum.sort() ==
                 Enum.sort([site.footer_mascot_image_id, site.projects_mascot_image_id])
      end
    end

    test "the export copies the mascot variants", %{site: site} do
      sink = RecordingSink.new(start_supervised!(RecordingSink))
      :ok = Export.run(site, Routes.new(site), sink)

      %{footer_mascot_image: footer, projects_mascot_image: projects} = SiteData.load(site).site

      for {image, filename} <- [{footer, "280.webp"}, {projects, "160.webp"}] do
        assert RecordingSink.get(sink, "images/#{image.public_id}/#{filename}") ==
                 {:copy, Media.variant_path(image, filename)}
      end
    end

    test "a simple_sidebar site, which shows no mascots, leaves them out", %{site: site} do
      site = site |> Ecto.Changeset.change(theme: "simple_sidebar") |> Repo.update!()

      assert SiteData.images_in_use(SiteData.load(site)) == []
      refute site |> export() |> RecordingSink.paths() |> Enum.any?(&(&1 =~ ~r{^images/}))
    end
  end

  describe "portrait" do
    setup %{scope: scope} do
      path = test_image_path(60, 80, "jpg")
      {:ok, site} = Sites.put_portrait(scope, path, "me.jpg")
      File.rm(path)

      %{site: Repo.get!(Sites.Site, site.id)}
    end

    test "load/2 preloads the portrait", %{site: site} do
      assert %Image{filename: "me.jpg"} = SiteData.load(site).site.portrait_image
    end

    test "images_in_use/1 includes the portrait and the export copies its variants", %{
      site: site
    } do
      site = site |> Ecto.Changeset.change(theme: "simple_sidebar") |> Repo.update!()

      assert site.portrait_image_id in Enum.map(
               SiteData.images_in_use(SiteData.load(site)),
               & &1.id
             )

      sink = RecordingSink.new(start_supervised!(RecordingSink))
      :ok = Export.run(site, Routes.new(site), sink)
      portrait = SiteData.load(site).site.portrait_image

      assert RecordingSink.get(sink, "images/#{portrait.public_id}/120.webp") ==
               {:copy, Media.variant_path(portrait, "120.webp")}
    end

    test "a feather site, which shows no portrait, leaves it out", %{site: site} do
      refute site.portrait_image_id in Enum.map(
               SiteData.images_in_use(SiteData.load(site)),
               & &1.id
             )

      portrait = SiteData.load(site).site.portrait_image

      refute site
             |> export()
             |> RecordingSink.paths()
             |> Enum.any?(&String.starts_with?(&1, "images/#{portrait.public_id}/"))
    end
  end

  defp export(site) do
    sink = RecordingSink.new(start_supervised!(RecordingSink))
    :ok = Export.run(site, Routes.new(site), sink)
    sink
  end
end
