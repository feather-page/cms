defmodule Feather.Publishing.DeployDiagramsTest do
  use Feather.DataCase

  import ExUnit.CaptureLog

  alias Feather.Publishing
  alias Feather.Publishing.Deploy

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    Feather.FakeD2.install()
    scope = site_scope_fixture()
    target = Publishing.get_staging_target(scope)
    on_exit(fn -> File.rm_rf!(Deploy.build_path(target)) end)

    rclone = fn
      ["obscure", "-"], opts -> {:ok, "obscured-#{opts[:input]}"}
      ["sync" | _args], _opts -> {:ok, ""}
    end

    %{
      scope: scope,
      target: target,
      opts: [runner: rclone, brotli: false, staging_sites_path: tmp]
    }
  end

  defp diagram_files(target),
    do: Path.wildcard(Path.join([Deploy.live_dir(target), "diagrams", "*.svg"]))

  test "an unchanged diagram is not rendered again", %{scope: scope, target: target, opts: opts} do
    post_fixture(scope, %{
      slug: "/flow",
      content: [%{"type" => "diagram", "code" => "a -> b", "caption" => ""}]
    })

    assert {:ok, :deployed} = Deploy.run(target, opts)
    assert_received {:d2_rendered, "a -> b" <> _options}
    [file] = diagram_files(target)

    post_fixture(scope, %{slug: "/other"})
    assert {:ok, :deployed} = Deploy.run(target, opts)
    refute_received {:d2_rendered, _source}
    assert diagram_files(target) == [file]

    assert File.exists?(file <> ".gz")
    html = File.read!(Path.join(Deploy.live_dir(target), "flow/index.html"))
    assert html =~ ~s(<img loading="lazy" src="/diagrams/#{Path.basename(file)}" alt="Diagram">)
  end

  test "a diagram that fails to render does not stop the deploy", %{
    scope: scope,
    target: target,
    opts: opts
  } do
    post_fixture(scope, %{
      slug: "/flow",
      content: [%{"type" => "diagram", "code" => "broken ->", "caption" => "Flow"}]
    })

    log = capture_log(fn -> assert {:ok, :deployed} = Deploy.run(target, opts) end)

    html = File.read!(Path.join(Deploy.live_dir(target), "flow/index.html"))
    assert html =~ ~s(<pre data-language="d2"><code class="language-d2">broken -&gt;</code></pre>)
    assert log =~ "[warning] Diagram not rendered: err: failed to compile diagram.d2"
  end
end
