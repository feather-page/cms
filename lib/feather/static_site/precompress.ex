defmodule Feather.StaticSite.Precompress do
  @moduledoc """
  Writes precompressed copies of the text files of an exported site, so
  the web server can serve them as they are (Caddy's
  `precompressed br gzip`): `<file>.gz` with `:zlib` and `<file>.br` with
  the `brotli` command line tool. Without `brotli` on the `PATH` the `.br`
  files are skipped (logged once per run).
  """

  require Logger

  @extensions ~w(.html .css .js .txt .xml)

  @doc """
  Precompresses every `.html`, `.css`, `.js`, `.txt` and `.xml` file below
  `dir`. Returns the list of compressed source files; raises if a file
  could not be compressed.

  ## Options

    * `:brotli` - path of the brotli executable, or `false` to skip brotli
      (default: looked up on the `PATH`)
    * `:max_concurrency` - parallel files (default: number of schedulers)
  """
  @spec run(Path.t(), keyword()) :: [Path.t()]
  def run(dir, opts \\ []) do
    brotli = Keyword.get_lazy(opts, :brotli, fn -> System.find_executable("brotli") end)

    unless brotli do
      Logger.info("brotli not found, skipping .br precompression of #{dir}")
    end

    files = text_files(dir)

    # Errors are returned from the tasks and raised here: a crashing task
    # would take the (linked) caller down without a chance to clean up.
    files
    |> Task.async_stream(&compress(&1, brotli),
      max_concurrency: Keyword.get(opts, :max_concurrency, System.schedulers_online()),
      timeout: :infinity,
      ordered: false
    )
    |> Enum.find_value(fn
      {:ok, :ok} -> nil
      {:ok, {:error, message}} -> message
    end)
    |> case do
      nil -> files
      message -> raise RuntimeError, message
    end
  end

  @doc "The files below `dir` that get precompressed."
  @spec text_files(Path.t()) :: [Path.t()]
  def text_files(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&(Path.extname(&1) in @extensions and File.regular?(&1)))
  end

  defp compress(file, brotli) do
    File.write!(file <> ".gz", :zlib.gzip(File.read!(file)))
    if brotli, do: brotli(brotli, file), else: :ok
  rescue
    exception -> {:error, "precompressing #{file} failed: #{Exception.message(exception)}"}
  end

  defp brotli(brotli, file) do
    case System.cmd(brotli, ["--force", "--best", "--output=#{file}.br", "--", file],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, status} -> {:error, "brotli failed for #{file} (exit #{status}): #{output}"}
    end
  end
end
