defmodule Feather.StaticSite.ExportHighlightingTest do
  use Feather.DataCase

  alias Feather.FakeChroma
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @moduletag :capture_log

  setup do
    scope = site_scope_fixture()

    post_fixture(scope, %{
      title: "Code",
      slug: "/code",
      content: [
        %{"type" => "code", "code" => "puts 1 < 2", "language" => "ruby"},
        %{"type" => "code", "code" => "+[-->+<]", "language" => "brainfuck"}
      ]
    })

    %{scope: scope}
  end

  defp export(scope) do
    routes = Routes.new(scope.site, canonical_url: "https://example.com/")
    sink = RecordingSink.new(start_supervised!(RecordingSink, restart: :temporary))
    :ok = Export.run(scope.site, routes, sink)
    sink
  end

  test "highlights code blocks in a listed language", %{scope: scope} do
    FakeChroma.install()
    html = RecordingSink.get(export(scope), "code/index.html")

    assert html =~
             ~s(<pre data-language="ruby"><code class="language-ruby">) <>
               FakeChroma.html("puts 1 < 2") <> "</code></pre>"

    assert_received {:chroma_highlighted, "ruby", "puts 1 < 2"}
  end

  test "a language outside the list stays plain and keeps its label", %{scope: scope} do
    FakeChroma.install()
    html = RecordingSink.get(export(scope), "code/index.html")

    assert html =~
             ~s(<pre data-language="brainfuck"><code class="language-brainfuck">+[--&gt;+&lt;]</code></pre>)

    refute_received {:chroma_highlighted, "brainfuck", _code}
  end

  for mode <- [:missing, :timeout] do
    test "the export succeeds with plain code when chroma is #{mode}", %{scope: scope} do
      FakeChroma.install(unquote(mode))
      html = RecordingSink.get(export(scope), "code/index.html")

      assert html =~
               ~s(<pre data-language="ruby"><code class="language-ruby">puts 1 &lt; 2</code></pre>)
    end
  end

  test "the feed carries the same highlighted markup as the page", %{scope: scope} do
    FakeChroma.install()
    sink = export(scope)

    code = ~s(<code class="language-ruby">) <> FakeChroma.html("puts 1 < 2") <> "</code>"
    assert RecordingSink.get(sink, "code/index.html") =~ code
    assert RecordingSink.get(sink, "feed.xml") =~ Plug.HTML.html_escape(code)
  end
end
