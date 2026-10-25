defmodule Feather.Publishing.DeployManifestTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Feather.Media
  alias Feather.Publishing.{DeployManifest, DeploymentTarget}

  @moduletag :tmp_dir

  @long_ago 1_000_000_000

  setup do
    %{target: %DeploymentTarget{id: Ecto.UUID.generate()}}
  end

  defp write(dir, path, content) do
    full_path = Path.join(dir, path)
    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, content)
    full_path
  end

  defp sha256(content), do: :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  describe "restore_times/2" do
    test "gives unchanged files their recorded time and returns the directory's manifest", c do
      unchanged = write(c.tmp_dir, "posts/unchanged.html", "same")
      changed = write(c.tmp_dir, "changed.html", "edited")
      new = write(c.tmp_dir, ".htaccess", "new")

      previous = %{
        "posts/unchanged.html" => %{sha256: sha256("same"), mtime: @long_ago},
        "changed.html" => %{sha256: sha256("original"), mtime: @long_ago},
        "removed.html" => %{sha256: sha256("gone"), mtime: @long_ago}
      }

      manifest = DeployManifest.restore_times(previous, c.tmp_dir)

      assert mtime(unchanged) == @long_ago
      assert mtime(changed) > @long_ago

      assert manifest == %{
               "posts/unchanged.html" => %{sha256: sha256("same"), mtime: @long_ago},
               "changed.html" => %{sha256: sha256("edited"), mtime: mtime(changed)},
               ".htaccess" => %{sha256: sha256("new"), mtime: mtime(new)}
             }
    end

    test "records every file of a directory without a previous manifest", c do
      file = write(c.tmp_dir, "index.html", "<h1>Hello</h1>")

      assert DeployManifest.restore_times(%{}, c.tmp_dir) == %{
               "index.html" => %{sha256: sha256("<h1>Hello</h1>"), mtime: mtime(file)}
             }
    end
  end

  describe "load/1 and save/2" do
    test "a saved manifest loads as it was saved", c do
      manifest = %{"index.html" => %{sha256: sha256("a"), mtime: @long_ago}}

      assert DeployManifest.save(c.target, manifest) == :ok
      assert DeployManifest.load(c.target) == manifest
    end

    test "the manifest lives in the storage root, outside the exports", c do
      assert DeployManifest.path(c.target) ==
               Path.join([Media.storage_root(), "deploy_manifests", "#{c.target.id}.json"])
    end

    test "a target without a manifest has an empty one", c do
      assert DeployManifest.load(c.target) == %{}
    end

    test "a corrupt manifest counts as empty and is logged", c do
      for content <- ["{not json", ~s({"index.html": {"sha256": 1}}), "[]"] do
        File.mkdir_p!(Path.dirname(DeployManifest.path(c.target)))
        File.write!(DeployManifest.path(c.target), content)

        log = capture_log(fn -> assert DeployManifest.load(c.target) == %{} end)
        assert log =~ "deploy manifest"
      end
    end

    test "saving replaces the manifest through a temporary file", c do
      :ok = DeployManifest.save(c.target, %{"a.html" => %{sha256: sha256("a"), mtime: 1}})
      :ok = DeployManifest.save(c.target, %{"b.html" => %{sha256: sha256("b"), mtime: 2}})

      assert DeployManifest.load(c.target) == %{"b.html" => %{sha256: sha256("b"), mtime: 2}}
      dir = Path.dirname(DeployManifest.path(c.target))
      assert Path.wildcard(Path.join(dir, "#{c.target.id}*")) == [DeployManifest.path(c.target)]
    end

    test "a manifest that cannot be saved is logged and leaves no temporary file", c do
      File.mkdir_p!(DeployManifest.path(c.target))

      log =
        capture_log(fn ->
          assert DeployManifest.save(c.target, %{"a.html" => %{sha256: sha256("a"), mtime: 1}}) ==
                   :ok
        end)

      assert log =~ "deploy manifest"
      dir = Path.dirname(DeployManifest.path(c.target))
      assert Path.wildcard(Path.join(dir, "#{c.target.id}*")) == [DeployManifest.path(c.target)]
    end

    test "a manifest that cannot be encoded is logged, not raised", c do
      log =
        capture_log(fn ->
          assert DeployManifest.save(c.target, %{<<0xFF>> => %{sha256: sha256("a"), mtime: 1}}) ==
                   :ok
        end)

      assert log =~ "deploy manifest"
      refute File.exists?(DeployManifest.path(c.target))
    end
  end

  test "delete/1 removes the manifest, also when there is none", c do
    :ok = DeployManifest.save(c.target, %{"a.html" => %{sha256: sha256("a"), mtime: 1}})

    assert DeployManifest.delete(c.target) == :ok
    refute File.exists?(DeployManifest.path(c.target))
    assert DeployManifest.delete(c.target) == :ok
  end
end
