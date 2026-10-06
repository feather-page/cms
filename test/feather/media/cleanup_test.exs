defmodule Feather.Media.CleanupTest do
  use Feather.DataCase

  alias Feather.{Content, Media}
  alias Feather.Media.{CleanupScheduler, Image}

  setup do
    %{scope: site_scope_fixture()}
  end

  # Three days on, every image created in the test is past the grace period.
  defp later, do: DateTime.add(DateTime.utc_now(), 3, :day)

  defp public_ids(images), do: images |> Enum.map(& &1.public_id) |> Enum.sort()

  defp exists?(image), do: Repo.get(Image, image.id) != nil

  describe "cleanup_orphaned_images/1" do
    test "deletes old images nothing references, rows and files", %{scope: scope} do
      orphan = image_fixture(scope)
      dir = Media.image_dir(orphan)
      assert File.dir?(dir)

      assert {:ok, %{unreferenced: [deleted], unused: []}} =
               Media.cleanup_orphaned_images(later())

      assert deleted.id == orphan.id
      refute exists?(orphan)
      refute File.exists?(dir)
    end

    test "keeps images younger than two days", %{scope: scope} do
      orphan = image_fixture(scope)

      assert {:ok, %{unreferenced: [], unused: []}} =
               Media.cleanup_orphaned_images(DateTime.add(DateTime.utc_now(), 47, :hour))

      assert exists?(orphan)
    end

    test "keeps header, thumbnail and cover images", %{scope: scope} do
      header = image_fixture(scope)
      thumbnail = image_fixture(scope)
      page_header = image_fixture(scope)
      project_thumbnail = image_fixture(scope)
      cover = image_fixture(scope)

      post_fixture(scope, header_image_id: header.id, thumbnail_image_id: thumbnail.id)
      page_fixture(scope, header_image_id: page_header.id)
      project_fixture(scope, thumbnail_image_id: project_thumbnail.id)
      book_fixture(scope, cover_image_id: cover.id)

      assert {:ok, %{unreferenced: [], unused: []}} = Media.cleanup_orphaned_images(later())

      for image <- [header, thumbnail, page_header, project_thumbnail, cover],
          do: assert(exists?(image))
    end

    test "keeps images their owner embeds, deletes those it no longer embeds", %{scope: scope} do
      kept = image_fixture(scope)
      dropped = image_fixture(scope)

      post = post_fixture(scope, content: [image_block(kept), image_block(dropped)])
      assert Repo.get!(Image, dropped.id).post_id == post.id

      {:ok, _post} = Content.update_post(scope, post, %{content: [image_block(kept)]})

      page_image = image_fixture(scope)
      page = page_fixture(scope, content: [image_block(page_image)])
      {:ok, _page} = Content.update_page(scope, page, %{content: [paragraph("No image")]})

      assert {:ok, %{unreferenced: [], unused: unused}} = Media.cleanup_orphaned_images(later())
      assert public_ids(unused) == public_ids([dropped, page_image])

      assert exists?(kept)
      refute exists?(dropped)
      refute File.exists?(Media.image_dir(dropped))
    end

    test "keeps an owned image that is a header image elsewhere", %{scope: scope} do
      image = image_fixture(scope)
      post = post_fixture(scope, content: [image_block(image)])
      {:ok, _post} = Content.update_post(scope, post, %{content: []})
      post_fixture(scope, header_image_id: image.id)

      assert {:ok, %{unreferenced: [], unused: []}} = Media.cleanup_orphaned_images(later())
      assert exists?(image)
    end

    test "keeps unowned images an image block of the site embeds", %{scope: scope} do
      image = image_fixture(scope)
      post = post_fixture(scope, content: [image_block(image)])
      Repo.update_all(from(i in Image, where: i.id == ^image.id), set: [post_id: nil])

      other_scope = site_scope_fixture()
      _same_public_id_elsewhere = post_fixture(other_scope, content: [image_block(image)])

      assert {:ok, %{unreferenced: [], unused: []}} = Media.cleanup_orphaned_images(later())
      assert exists?(image)
      assert post.id
    end

    test "orphaned_images/1 lists without deleting", %{scope: scope} do
      orphan = image_fixture(scope)
      assert %{unreferenced: [listed], unused: []} = Media.orphaned_images(later())
      assert listed.id == orphan.id
      assert exists?(orphan)
    end
  end

  describe "CleanupScheduler" do
    test "runs the cleanup after the initial delay and then every interval" do
      test_pid = self()

      cleanup = fn ->
        send(test_pid, :cleaned)
        {:ok, %{unreferenced: [], unused: []}}
      end

      start_supervised!(
        {CleanupScheduler,
         enabled: true, name: :test_cleanup, initial_delay: 0, interval: 10, cleanup: cleanup}
      )

      assert_receive :cleaned
      assert_receive :cleaned
    end

    @tag :capture_log
    test "survives a failing cleanup" do
      test_pid = self()

      cleanup = fn ->
        send(test_pid, :attempted)
        raise "boom"
      end

      pid =
        start_supervised!(
          {CleanupScheduler,
           enabled: true, name: :failing_cleanup, initial_delay: 0, interval: 10, cleanup: cleanup}
        )

      assert_receive :attempted
      assert_receive :attempted
      assert :sys.get_state(pid).interval == 10
    end

    test "does not start when disabled" do
      assert CleanupScheduler.start_link(enabled: false) == :ignore
      # Disabled in config/test.exs.
      assert CleanupScheduler.start_link([]) == :ignore
    end
  end
end
