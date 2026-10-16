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

      for image <- [footer, projects], filename <- Media.Variants.filenames() do
        assert RecordingSink.get(sink, "images/#{image.public_id}/#{filename}") ==
                 {:copy, Media.variant_path(image, filename)}
      end
    end
  end
end
