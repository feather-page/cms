defmodule Feather.StaticSite.ExportDiagramsTest do
  use Feather.DataCase

  alias Feather.Diagrams
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @moduletag :capture_log

  setup do
    Feather.FakeD2.install()
    scope = site_scope_fixture()

    post =
      post_fixture(scope, %{
        title: "Flows",
        slug: "/flows",
        content: [
          %{"type" => "diagram", "code" => "a -> b", "caption" => "A flow"},
          %{"type" => "diagram", "code" => "broken ->", "caption" => "Broken"}
        ]
      })

    %{scope: scope, post: post}
  end

  defp export(scope) do
    routes = Routes.new(scope.site, canonical_url: "https://example.com/")
    sink = RecordingSink.new(start_supervised!(RecordingSink, restart: :temporary))
    :ok = Export.run(scope.site, routes, sink)
    sink
  end

  test "writes the diagram's SVG file next to the pages", %{scope: scope} do
    sink = export(scope)

    [name] = for "diagrams/" <> name <- RecordingSink.paths(sink), do: name
    assert RecordingSink.get(sink, "diagrams/#{name}") == {:copy, Diagrams.path(name)}
    assert File.read!(Diagrams.path(name)) =~ "a -> b"

    html = RecordingSink.get(sink, "flows/index.html")

    assert html =~ ~s(<figure class="diagram">)
    assert html =~ ~s(<img loading="lazy" src="/diagrams/#{name}" alt="A flow">)

    assert html =~ ~s(<pre data-language="d2"><code class="language-d2">broken -&gt;</code></pre>)
  end

  test "the feed references the diagram by absolute URL", %{scope: scope} do
    sink = export(scope)

    [name] = for "diagrams/" <> name <- RecordingSink.paths(sink), do: name

    assert RecordingSink.get(sink, "feed.xml") =~
             "src=&quot;https://example.com/diagrams/#{name}&quot;"
  end
end
