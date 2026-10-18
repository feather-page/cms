defmodule Feather.Publishing.DeployDiagramsTest do
  use Feather.DataCase

  import ExUnit.CaptureLog

  alias Feather.Publishing.Deploy

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Feather.FakeD2.install()
    scope = site_scope_fixture()
    target = deployment_target_fixture(scope)
    synced = Path.join(tmp_dir, "synced")

    rclone = fn
      ["obscure", "-"], opts ->
        {:ok, "obscured-#{opts[:input]}"}

      ["sync", "--config", _config, source, _remote], _opts ->
        File.rm_rf!(synced)
        File.cp_r!(source, synced)
        {:ok, ""}
    end

    %{
      scope: scope,
      target: target,
      synced: synced,
      opts: [runner: rclone, brotli: false]
    }
  end

  defp diagram_files(synced), do: Path.wildcard(Path.join([synced, "diagrams", "*.svg"]))

  test "an unchanged diagram is not rendered again", %{
    scope: scope,
    target: target,
    synced: synced,
    opts: opts
  } do
    post_fixture(scope, %{
      slug: "/flow",
      content: [%{"type" => "diagram", "code" => "a -> b", "caption" => ""}]
    })

    assert {:ok, :deployed} = Deploy.run(target, opts)
    assert_received {:d2_rendered, "a -> b" <> _options}
    [file] = diagram_files(synced)

    post_fixture(scope, %{slug: "/other"})
    assert {:ok, :deployed} = Deploy.run(target, opts)
    refute_received {:d2_rendered, _source}
    assert diagram_files(synced) == [file]

    assert File.exists?(file <> ".gz")
    html = File.read!(Path.join(synced, "flow/index.html"))
    assert html =~ ~s(<img loading="lazy" src="/diagrams/#{Path.basename(file)}" alt="Diagram">)
  end

  test "a diagram that fails to render does not stop the deploy", %{
    scope: scope,
    target: target,
    synced: synced,
    opts: opts
  } do
    post_fixture(scope, %{
      slug: "/flow",
      content: [%{"type" => "diagram", "code" => "broken ->", "caption" => "Flow"}]
    })

    log = capture_log(fn -> assert {:ok, :deployed} = Deploy.run(target, opts) end)

    html = File.read!(Path.join(synced, "flow/index.html"))
    assert html =~ ~s(<pre data-language="d2"><code class="language-d2">broken -&gt;</code></pre>)
    assert log =~ "[warning] Diagram not rendered: err: failed to compile diagram.d2"
  end
end
