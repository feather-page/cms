defmodule Feather.DiagramsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Feather.Diagrams
  alias Feather.Diagrams.SystemRunner

  @options ~w(--theme=0 --dark-theme=200 --bundle=false --pad=16 --scale=1 --target=) ++
             ~w(--elk-nodeNodeBetweenLayers=35 --elk-edgeNodeBetweenLayers=20) ++
             ~w(--elk-padding=[top=40,left=20,bottom=20,right=20])

  # Every test renders with a d2 version of its own, so cached files of other tests never hit.
  setup do
    %{version: "v0.0.#{System.unique_integer([:positive])}"}
  end

  # CI installs the d2 version of the Dockerfile; these tests check it for real.
  @d2 System.find_executable("d2")

  defp fake_d2(version, result \\ :ok) do
    test = self()

    fn
      ["--version"], _opts ->
        {:ok, version <> "\n"}

      args, opts ->
        dir = opts[:cd]
        send(test, {:d2, args, opts, File.ls!(dir), File.read!(Path.join(dir, "diagram.d2"))})

        case result do
          :ok ->
            File.write!(Path.join(dir, "diagram.svg"), "<svg>#{version}</svg>")
            {:ok, "success: successfully compiled"}

          {:svg, svg} ->
            File.write!(Path.join(dir, "diagram.svg"), svg)
            {:ok, "success: successfully compiled"}

          {:error, message} ->
            {:error, String.replace(message, "DIR", dir)}
        end
    end
  end

  describe "render/2" do
    test "runs d2 on the source in an empty directory and stores the SVG", %{version: version} do
      assert {:ok, name} = Diagrams.render("a -> b", runner: fake_d2(version))

      assert_received {:d2, args, opts, ["diagram.d2"], "a -> b\nstyle.fill: transparent\n"}
      assert args == ["--layout=tala" | @options] ++ ["diagram.d2", "diagram.svg"]
      assert opts[:timeout] == :timer.seconds(60)
      refute File.exists?(opts[:cd])

      assert name =~ ~r/\A[0-9a-f]{64}\.svg\z/
      assert Diagrams.file_name?(name)
      assert File.read!(Diagrams.path(name)) == "<svg>#{version}</svg>"
      assert Bitwise.band(File.stat!(Diagrams.path(name)).mode, 0o777) == 0o644
    end

    test "leaves the layout to a source that picks its own engine", %{version: version} do
      code = "vars: {d2-config: {layout-engine: elk}}\na -> b"
      assert {:ok, _name} = Diagrams.render(code, runner: fake_d2(version))

      assert_received {:d2, args, _opts, _files, _input}
      assert args == @options ++ ["diagram.d2", "diagram.svg"]
    end

    test "ignores an engine named in a comment", %{version: version} do
      for code <- [
            "# vars: {d2-config: {layout-engine: elk}}\na -> b",
            "a -> b # layout-engine: elk",
            "a -> b #layout-engine: elk"
          ] do
        assert {:ok, _name} = Diagrams.render(code, runner: fake_d2(version))
        assert_received {:d2, ["--layout=tala" | _args], _opts, _files, _input}
      end

      code = ~s(x.style.fill: "#fff"; vars: {d2-config: {layout-engine: elk}})
      assert {:ok, _name} = Diagrams.render(code, runner: fake_d2(version))
      assert_received {:d2, ["--theme=0" | _args], _opts, _files, _input}
    end

    test "does not run d2 for a diagram it rendered before", %{version: version} do
      assert {:ok, name} = Diagrams.render("a -> b", runner: fake_d2(version))
      assert_received {:d2, _args, _opts, _files, _input}

      assert Diagrams.render("a -> b", runner: fake_d2(version)) == {:ok, name}
      refute_received {:d2, _args, _opts, _files, _input}
    end

    test "names the file by d2 version and source", %{version: version} do
      {:ok, name} = Diagrams.render("a -> b", runner: fake_d2(version))

      assert {:ok, other_source} = Diagrams.render("a -> c", runner: fake_d2(version))
      assert {:ok, other_version} = Diagrams.render("a -> b", runner: fake_d2(version <> "-1"))
      assert length(Enum.uniq([name, other_source, other_version])) == 3
    end

    test "returns d2's error without the temporary directory and runs d2 once for it", %{
      version: version
    } do
      error = "err: failed to compile DIR/diagram.d2: DIR/diagram.d2:1:1: connection missing"
      result = {:error, "err: failed to compile diagram.d2: diagram.d2:1:1: connection missing"}

      assert Diagrams.render("a ->", runner: fake_d2(version, {:error, error})) == result
      assert_received {:d2, _args, _opts, _files, _input}

      assert Diagrams.render("a ->", runner: fake_d2(version)) == result
      refute_received {:d2, _args, _opts, _files, _input}
    end

    test "runs d2 again after it timed out", %{version: version} do
      test = self()

      runner = fn
        ["--version"], _opts ->
          {:ok, version}

        _args, _opts ->
          send(test, :d2_ran)
          {:aborted, "d2 timed out after 60 seconds"}
      end

      for _attempt <- 1..2 do
        assert Diagrams.render("a -> b", runner: runner) ==
                 {:error, "d2 timed out after 60 seconds"}

        assert_received :d2_ran
      end
    end

    test "fails without leaving files behind when the SVG cannot be stored", %{
      version: version
    } do
      {:ok, name} = Diagrams.render("a -> b", runner: fake_d2(version))
      target = Diagrams.path(name)
      File.rm!(target)
      File.mkdir_p!(Path.join(target, "blocker"))
      on_exit(fn -> File.rm_rf(target) end)

      assert {:error, "could not store the diagram: " <> _reason} =
               Diagrams.render("a -> b", runner: fake_d2(version))

      assert Path.wildcard(target <> ".*.partial") == []
    end

    test "fails when d2 is missing or writes no SVG", %{version: version} do
      missing = fn _args, _opts -> {:aborted, "d2 is not installed"} end
      assert Diagrams.render("a -> b", runner: missing) == {:error, "d2 is not installed"}

      silent = fn
        ["--version"], _opts -> {:ok, version}
        _args, _opts -> {:ok, ""}
      end

      assert Diagrams.render("a -> b", runner: silent) == {:error, "d2 wrote no SVG"}
    end
  end

  describe "render/2 confinement" do
    test "rejects imports before running d2", %{version: version} do
      for code <- [
            "x: @lib",
            "x:@lib",
            "x:\t@lib",
            "@lib",
            "a\n@lib",
            "...@lib",
            "x: {...@lib}",
            ~s(x: @"/abs/lib"),
            "vars: {...@lib}",
            "x: [@a; @b]"
          ] do
        assert Diagrams.render(code, runner: fake_d2(version)) ==
                 {:error, "Diagrams cannot import files"},
               code
      end

      refute_received {:d2, _args, _opts, _files, _input}
    end

    test "renders sources with an @ that is no import", %{version: version} do
      for code <- ["a: mail@example.com", ~s(a: "write to mail@example.com")] do
        assert {:ok, _name} = Diagrams.render(code, runner: fake_d2(version)), code
      end
    end

    test "rejects SVGs that embed images or links and stores only the error", %{
      version: version
    } do
      for svg <- [
            ~s(<svg><image href="data:text/plain;base64,c2VjcmV0"/></svg>),
            ~s[<svg><a href="javascript:alert(1)"><text>x</text></a></svg>],
            ~s(<svg><A\nhref="x">x</A></svg>),
            ~s(<svg><svg:image href="x"/></svg>)
          ] do
        version = version <> "-" <> Integer.to_string(:erlang.phash2(svg))

        assert {:error, "Diagrams cannot use icons or links"} =
                 Diagrams.render("a -> b", runner: fake_d2(version, {:svg, svg}))

        assert {:error, "Diagrams cannot use icons or links"} =
                 Diagrams.render("a -> b", runner: fake_d2(version))
      end
    end

    test "keeps SVGs with embedded fonts", %{version: version} do
      svg =
        ~s[<svg><style>@font-face{src:url("data:application/font-woff;base64,d09GRg==")}</style>] <>
          ~s(<g class="shape"><text>an icon and a link</text></g></svg>)

      assert Diagrams.render_svg("a -> b", runner: fake_d2(version, {:svg, svg})) == {:ok, svg}
    end

    test "names no file d2 failed to read", %{version: version} do
      bundle =
        "err: failed to bundle /etc/passwd.png: open /etc/passwd.png: no such file or directory"

      import =
        ~s(err: failed to compile DIR/diagram.d2: DIR/diagram.d2:1:4: failed to import "/x.d2": ) <>
          "open /x.d2: no such file or directory"

      assert Diagrams.render("a", runner: fake_d2(version, {:error, bundle})) ==
               {:error, "Diagrams cannot use icons or links"}

      assert Diagrams.render("b", runner: fake_d2(version, {:error, import})) ==
               {:error, "Diagrams cannot import files"}
    end
  end

  describe "render_svg/2" do
    test "returns the SVG itself, or d2's error", %{version: version} do
      assert Diagrams.render_svg("a -> b", runner: fake_d2(version)) ==
               {:ok, "<svg>#{version}</svg>"}

      assert Diagrams.render_svg("a ->", runner: fake_d2(version <> "-1", {:error, "bad"})) ==
               {:error, "bad"}
    end
  end

  describe "render_all/2" do
    test "maps each source to its SVG file and logs the ones that fail", %{version: version} do
      runner = fn
        ["--version"], _opts -> {:ok, version}
        args, opts -> if(source(opts) =~ "broken", do: {:error, "bad"}, else: fake(args, opts))
      end

      log =
        capture_log(fn ->
          diagrams = Diagrams.render_all(["a -> b", "broken", "a -> b", "  \n"], runner: runner)

          assert [{"a -> b", name}] = Map.to_list(diagrams)
          assert Diagrams.file_name?(name)
        end)

      assert log =~ "Diagram not rendered: bad"
    end

    defp source(opts), do: File.read!(Path.join(opts[:cd], "diagram.d2"))

    defp fake(_args, opts) do
      File.write!(Path.join(opts[:cd], "diagram.svg"), "<svg/>")
      {:ok, ""}
    end
  end

  test "file_name?/1 accepts only the names of rendered files" do
    refute Diagrams.file_name?("../secret.svg")
    refute Diagrams.file_name?(String.duplicate("A", 64) <> ".svg")
    refute Diagrams.file_name?(String.duplicate("a", 64) <> ".svg.partial")
  end

  @tag skip: is_nil(@d2) && "d2 is not installed"
  test "renders through the real d2 with a transparent background and both themes" do
    assert {:ok, name} = Diagrams.render("a -> b: hello", runner: SystemRunner)

    svg = File.read!(Diagrams.path(name))
    assert svg =~ ~r/\A<\?xml/
    assert svg =~ ~s(fill="transparent")
    assert svg =~ "prefers-color-scheme:dark"
    assert svg =~ ~r/<svg [^>]*width="\d+" height="\d+"/

    assert {:error, message} = Diagrams.render("a -> b {", runner: SystemRunner)
    assert message =~ "diagram.d2:1:"
    refute message =~ System.tmp_dir!()

    assert {:ok, _name} =
             Diagrams.render("vars: {d2-config: {layout-engine: elk}}\nx -> y",
               runner: SystemRunner
             )
  end

  describe "the real d2" do
    @describetag skip: is_nil(@d2) && "d2 is not installed"
    @describetag :tmp_dir

    setup %{tmp_dir: dir} do
      secret = "feather-secret-#{System.unique_integer([:positive])}"
      file = Path.join(dir, "secret.txt")
      File.write!(file, secret)
      File.write!(Path.join(dir, "lib.d2"), ~s(leaked: "#{secret}"\n))
      %{secret_file: file, dir: dir, secret: secret}
    end

    test "embeds no local file as an icon or link", %{secret_file: file, secret: secret} do
      relative = String.duplicate("../", 40) <> String.trim_leading(file, "/")

      for code <- [
            "x.icon: #{file}",
            "x.icon: #{relative}",
            "x: {shape: image; icon: #{file}}",
            "a; b; *.icon: #{file}",
            "classes: {c: {icon: #{file}}}\nx.class: c",
            "vars: {p: #{file}}\nx.icon: ${p}",
            "x.ic\\on: #{file}",
            "x.icon: #{file}.missing",
            ~s(x.link: "javascript:alert(1\)")
          ] do
        assert Diagrams.render(code, runner: SystemRunner) ==
                 {:error, "Diagrams cannot use icons or links"},
               code
      end

      refute_stored(secret)
    end

    test "imports no file", %{dir: dir, secret: secret} do
      for code <- ["...@#{dir}/lib", "x: @#{dir}/lib", "x: @../../../../../../../../#{dir}/lib"] do
        assert Diagrams.render(code, runner: SystemRunner) ==
                 {:error, "Diagrams cannot import files"},
               code
      end

      refute_stored(secret)
    end

    @tag skip: (:os.type() != {:unix, :linux} or is_nil(@d2)) && "needs d2 on Linux"
    test "stops reading an endless icon" do
      assert {:error, message} = Diagrams.render("x.icon: /dev/zero", runner: SystemRunner)
      assert message in ["d2 ran out of memory", "Diagrams cannot use icons or links"]
    end

    test "renders labels that mention icons, links and email addresses" do
      code = "x: an icon and a link\ny: mail@example.com\nx -> y: link\nz.label: icon"
      assert {:ok, svg} = Diagrams.render_svg(code, runner: SystemRunner)
      assert svg =~ "mail@example.com"
    end
  end

  defp refute_stored(secret) do
    encoded = secret |> Base.encode64() |> String.trim_trailing("=")

    for file <- Path.wildcard(Diagrams.path("*")) do
      content = File.read!(file)
      refute content =~ secret, file
      refute content =~ encoded, file
    end
  end
end
