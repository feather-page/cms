defmodule Feather.HighlightingTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Feather.Highlighting
  alias Feather.Highlighting.SystemRunner

  @options ~w(--html --html-only --html-prevent-surrounding-pre --html-prefix=hl-)

  # Every test highlights with a chroma version of its own, so cached files of other tests never hit.
  setup do
    %{version: "0.0.#{System.unique_integer([:positive])}"}
  end

  # CI installs the chroma version of the Dockerfile; this test checks it for real.
  @chroma System.find_executable("chroma")

  defp fake_chroma(version, result \\ :ok) do
    test = self()

    fn
      ["--version"], _opts ->
        {:ok, version <> "\n"}

      args, opts ->
        dir = opts[:cd]
        code = File.read!(Path.join(dir, "code"))
        send(test, {:chroma, args, opts, File.ls!(dir), code})

        case result do
          :ok -> {:ok, ~s(<span class="hl-k">#{code}</span>)}
          {:output, output} -> {:ok, output}
          failure -> failure
        end
    end
  end

  describe "highlight/3" do
    test "runs chroma with the mapped lexer on the code in an empty directory",
         %{version: version} do
      assert Highlighting.highlight("puts 1", "ruby", runner: fake_chroma(version)) ==
               {:ok, ~s(<span class="hl-k">puts 1</span>)}

      assert_received {:chroma, args, opts, ["code"], "puts 1"}
      assert args == ["code", "--lexer", "ruby" | @options]
      assert opts[:timeout] == :timer.seconds(10)
      refute File.exists?(opts[:cd])
    end

    test "passes chroma the lexer of each listed language", %{version: version} do
      runner = fake_chroma(version)

      for language <-
            ~w(bash csharp cpp css go html java javascript json kotlin php python) ++
              ~w(ruby rust sql swift typescript xml yaml elixir) do
        assert {:ok, _html} = Highlighting.highlight("x", language, runner: runner)
        assert_received {:chroma, ["code", "--lexer", ^language | _args], _opts, _files, "x"}
      end

      assert {:ok, _html} = Highlighting.highlight("y", " elixir ", runner: runner)
      assert_received {:chroma, ["code", "--lexer", "elixir" | _args], _opts, _files, "y"}
    end

    test "never passes a language outside the map to chroma", %{version: version} do
      runner = fake_chroma(version)

      for language <- [
            "brainfuck",
            "plaintext",
            "d2",
            "Ruby",
            "/etc/passwd",
            "../lexer.xml",
            "",
            nil
          ] do
        assert Highlighting.highlight("x", language, runner: runner) == :plain
      end

      refute_received {:chroma, _args, _opts, _files, _code}
    end

    test "leaves blank code plain", %{version: version} do
      assert Highlighting.highlight(" \n", "ruby", runner: fake_chroma(version)) == :plain
      refute_received {:chroma, _args, _opts, _files, _code}
    end

    test "runs chroma once per code, lexer and chroma version", %{version: version} do
      runner = fake_chroma(version)

      assert {:ok, html} = Highlighting.highlight("puts 1", "ruby", runner: runner)
      assert_received {:chroma, _args, _opts, _files, "puts 1"}

      assert Highlighting.highlight("puts 1", "ruby", runner: runner) == {:ok, html}
      refute_received {:chroma, _args, _opts, _files, _code}

      assert {:ok, _html} = Highlighting.highlight("puts 2", "ruby", runner: runner)
      assert_received {:chroma, _args, _opts, _files, "puts 2"}

      assert {:ok, _html} = Highlighting.highlight("puts 1", "python", runner: runner)
      assert_received {:chroma, ["code", "--lexer", "python" | _args], _opts, _files, "puts 1"}

      assert {:ok, _html} =
               Highlighting.highlight("puts 1", "ruby", runner: fake_chroma(version <> ".1"))

      assert_received {:chroma, _args, _opts, _files, "puts 1"}
    end

    test "leaves the code plain and logs a warning when chroma fails", %{version: version} do
      runner = fake_chroma(version, {:aborted, "chroma timed out after 10 seconds"})

      log =
        capture_log(fn ->
          assert Highlighting.highlight("puts 1", "ruby", runner: runner) == :plain
        end)

      assert log =~ "Code not highlighted: chroma timed out after 10 seconds"

      # Failures are not cached.
      capture_log(fn -> Highlighting.highlight("puts 1", "ruby", runner: runner) end)
      assert_received {:chroma, _args, _opts, _files, "puts 1"}
      assert_received {:chroma, _args, _opts, _files, "puts 1"}
    end

    test "leaves the code plain when chroma is missing" do
      runner = fn _args, _opts -> {:aborted, "chroma is not installed"} end

      log =
        capture_log(fn ->
          assert Highlighting.highlight("puts 1", "ruby", runner: runner) == :plain
        end)

      assert log =~ "chroma is not installed"
    end

    test "rejects output with markup other than token spans", %{version: version} do
      for output <- [
            ~s(<span class="hl-k">x</span><script>alert(1\)</script>),
            ~s(<span class="hl-k" onclick="x">x</span>),
            ~s(<pre class="chroma"><code>x</code></pre>),
            ~s(<img src=x>)
          ] do
        runner =
          fake_chroma("#{version}-#{System.unique_integer([:positive])}", {:output, output})

        log =
          capture_log(fn ->
            assert Highlighting.highlight("x", "ruby", runner: runner) == :plain
          end)

        assert log =~ "unexpected markup", output
      end
    end
  end

  test "leaves the code plain and logs a warning when the runner raises", %{version: version} do
    raising = fn
      ["--version"], _opts -> {:ok, version}
      _args, _opts -> raise ErlangError, original: :eacces
    end

    log =
      capture_log(fn ->
        assert Highlighting.highlight("puts 1", "ruby", runner: raising) == :plain
        assert Highlighting.highlight_all([{"puts 2", "ruby"}], runner: raising) == %{}

        assert Highlighting.highlight_all([{"x", "go"}], runner: fn _, _ -> raise "boom" end) ==
                 %{}
      end)

    assert log =~ "Code not highlighted: Erlang error: :eacces"
    assert log =~ "Code not highlighted: boom"
  end

  describe "highlight_all/2" do
    test "maps each highlighted code and language to its HTML", %{version: version} do
      blocks = [
        {"puts 1", "ruby"},
        {"puts 1", "ruby"},
        {"x", "brainfuck"},
        {"", "ruby"},
        {"y", "go"}
      ]

      assert Highlighting.highlight_all(blocks, runner: fake_chroma(version)) == %{
               {"puts 1", "ruby"} => ~s(<span class="hl-k">puts 1</span>),
               {"y", "go"} => ~s(<span class="hl-k">y</span>)
             }

      assert_received {:chroma, _args, _opts, _files, "puts 1"}
      refute_received {:chroma, _args, _opts, _files, "puts 1"}
    end

    test "leaves out code chroma fails on", %{version: version} do
      runner = fake_chroma(version, {:error, "boom"})

      log =
        capture_log(fn ->
          assert Highlighting.highlight_all([{"a", "ruby"}, {"b", "go"}], runner: runner) == %{}
        end)

      assert log =~ "Code not highlighted: boom"
    end

    test "warns once when chroma is missing" do
      runner = fn _args, _opts -> {:aborted, "chroma is not installed"} end

      log =
        capture_log(fn ->
          assert Highlighting.highlight_all([{"a", "ruby"}, {"b", "go"}], runner: runner) == %{}
        end)

      assert length(String.split(log, "chroma is not installed")) == 2
    end
  end

  @tag skip: is_nil(@chroma) && "chroma is not installed"
  test "highlights a Ruby snippet through the real chroma" do
    code = ~S"""
    # Greets
    def greet(name) = puts "Hi #{name} <3"
    """

    assert {:ok, html} = Highlighting.highlight(code, "ruby", runner: SystemRunner)

    assert html =~ ~s(<span class="hl-c1"># Greets</span>)
    assert html =~ ~s(<span class="hl-k">def</span>)
    assert html =~ "&lt;3"
    refute html =~ "<pre"
    assert text(html) == code
  end

  defp text(html) do
    html
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(["&lt;", "&gt;", "&#34;", "&#39;", "&amp;"], fn
      "&lt;" -> "<"
      "&gt;" -> ">"
      "&#34;" -> "\""
      "&#39;" -> "'"
      "&amp;" -> "&"
    end)
  end
end
