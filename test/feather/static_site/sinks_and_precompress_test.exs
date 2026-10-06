defmodule Feather.StaticSite.SinksAndPrecompressTest do
  use ExUnit.Case, async: true

  alias Feather.StaticSite.{FileSink, Precompress, RecordingSink, Sink}

  @moduletag :tmp_dir

  describe "FileSink" do
    test "writes nested paths into a fresh directory and copies files byte for byte", %{
      tmp_dir: tmp
    } do
      sink = FileSink.new(tmp)
      assert Path.dirname(FileSink.dir(sink)) == tmp
      assert Path.basename(FileSink.dir(sink)) =~ ~r/\Aexport-/

      :ok = Sink.write(sink, "a/b/index.html", ["<p>", "Grüße", "</p>"])
      source = Path.join(tmp, "source.bin")
      File.write!(source, <<0, 255, 1>>)
      :ok = Sink.copy(sink, "images/x/mobile_x1.webp", from: source)

      assert File.read!(Path.join(FileSink.dir(sink), "a/b/index.html")) == "<p>Grüße</p>"
      assert File.read!(Path.join(FileSink.dir(sink), "images/x/mobile_x1.webp")) == <<0, 255, 1>>

      :ok = FileSink.discard(sink)
      refute File.exists?(FileSink.dir(sink))
    end

    test "refuses paths outside its directory", %{tmp_dir: tmp} do
      sink = FileSink.new(tmp)
      assert_raise ArgumentError, fn -> Sink.write(sink, "../escape.html", "x") end
    end
  end

  describe "RecordingSink" do
    test "records content and copy sources" do
      sink = RecordingSink.new(start_supervised!(RecordingSink))
      Sink.write(sink, "b.html", ["a", "b"])
      Sink.copy(sink, "a.webp", from: "/tmp/source.webp")

      assert RecordingSink.paths(sink) == ["a.webp", "b.html"]
      assert RecordingSink.get(sink, "b.html") == "ab"
      assert RecordingSink.get(sink, "a.webp") == {:copy, "/tmp/source.webp"}
      assert RecordingSink.exists?(sink, "a.webp")
      refute RecordingSink.exists?(sink, "c.html")
    end
  end

  describe "Precompress" do
    setup %{tmp_dir: tmp} do
      for {path, content} <- [
            {"index.html", "<p>home</p>"},
            {"a/index.html", String.duplicate("<p>post</p>", 50)},
            {"feed.xml", "<rss/>"},
            {"robots.txt", "User-agent: *"},
            {"style.css", "b{}"},
            {"app.js", "x()"},
            {"images/x/mobile_x1.webp", "binary"}
          ] do
        full = Path.join(tmp, path)
        File.mkdir_p!(Path.dirname(full))
        File.write!(full, content)
      end

      :ok
    end

    test "writes .gz for text files and skips brotli when it is missing", %{tmp_dir: tmp} do
      files = Precompress.run(tmp, brotli: false)

      assert length(files) == 6

      for path <- ~w(index.html a/index.html feed.xml robots.txt style.css app.js) do
        full = Path.join(tmp, path)
        assert :zlib.gunzip(File.read!(full <> ".gz")) == File.read!(full)
        refute File.exists?(full <> ".br")
      end

      refute File.exists?(Path.join(tmp, "images/x/mobile_x1.webp.gz"))
    end

    test "writes .br with the brotli executable", %{tmp_dir: tmp} do
      # A stand-in for brotli that records its arguments in the output file.
      fake = Path.join(tmp, "fake-brotli")

      File.write!(fake, """
      #!/bin/sh
      for arg in "$@"; do
        case "$arg" in --output=*) out="${arg#--output=}" ;; esac
      done
      echo "$@" > "$out"
      """)

      File.chmod!(fake, 0o755)
      Precompress.run(tmp, brotli: fake)

      br = File.read!(Path.join(tmp, "index.html.br"))
      assert br =~ "--best"
      assert br =~ Path.join(tmp, "index.html")
    end

    test "raises when brotli fails", %{tmp_dir: tmp} do
      fake = Path.join(tmp, "failing-brotli")
      File.write!(fake, "#!/bin/sh\necho broken\nexit 3\n")
      File.chmod!(fake, 0o755)

      assert_raise RuntimeError, ~r/brotli failed.*exit 3/, fn ->
        Precompress.run(tmp, brotli: fake)
      end
    end
  end
end
