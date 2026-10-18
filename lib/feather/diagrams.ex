defmodule Feather.Diagrams do
  @moduledoc """
  Renders the D2 source of diagram blocks into SVG files with the `d2`
  binary (ADR 0016).

  `--layout` would override an engine the source picks through
  `vars: {d2-config: {layout-engine: ...}}`, so it is only passed when the
  source names none. The `--elk-*` flags tighten ELK's spacing; TALA
  ignores them.

  d2 reads the source from a file in an empty temporary directory and
  writes the SVG next to it: a port cannot close a command's standard
  input. d2 reads local files despite `--bundle=false` (icons become data
  URIs, imports read `.d2` files) and text filters are easy to get around,
  so an SVG holding an `<image>` or an `<a>` is rejected, and sources with
  an import never reach d2.

  SVGs are cached as `<storage_root>/diagrams/<hash>.svg`, the hash a
  SHA-256 of the d2 version, the options and the source, so each diagram
  runs d2 once and TALA's layouts stay stable. d2's message for a broken
  diagram is cached as `<hash>.error`; timeouts and a missing d2 are not.
  Old files stay.

  Commands go through a runner (`Feather.Diagrams.Runner`, see
  `Feather.RenderTool`). Tests pass a fake one; the default is
  `config :feather, :d2_runner` or `Feather.Diagrams.SystemRunner`. The d2
  version is asked once per runner module.
  """

  alias Feather.Diagrams.SystemRunner
  alias Feather.{Media, RenderTool}

  require Logger

  @light_theme 0
  @dark_theme 200
  @layout "tala"
  @elk_spacing ~w(--elk-nodeNodeBetweenLayers=35 --elk-edgeNodeBetweenLayers=20 --elk-padding=[top=40,left=20,bottom=20,right=20])
  @options ~w(--bundle=false --pad=16 --scale=1 --target=) ++ @elk_spacing
  @transparent_background "\nstyle.fill: transparent\n"

  @input "diagram.d2"
  @output "diagram.svg"
  @timeout :timer.seconds(60)
  @version_timeout :timer.seconds(10)
  @file_name ~r/\A[0-9a-f]{64}\.svg\z/
  @engine ~r/^(?:[^#"\n]|"[^"\n]*")*layout-engine\s*:/m
  @import ~r/(?:^|[\s:{;\[]|\.\.\.)@/
  @embed ~r/<(?:[\w.-]+:)?(?:image|a)[\s\/>]/i
  @import_error "Diagrams cannot import files"
  @embed_error "Diagrams cannot use icons or links"

  @doc """
  Renders a diagram. Returns the name of its SVG file (see `path/1`) or
  d2's error message.

  Options: `:runner` (default: see the module doc).
  """
  @spec render(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def render(code, opts \\ []) when is_binary(code) do
    runner = RenderTool.runner(opts, :d2_runner, SystemRunner)
    args = args(code)

    with :ok <- reject_imports(code),
         {:ok, version} <- RenderTool.version(runner, @version_timeout) do
      name = file_name(version, args, code)

      cond do
        File.regular?(path(name)) -> {:ok, name}
        message = cached_error(name) -> {:error, message}
        true -> render_file(runner, args, code, name)
      end
    end
  end

  @doc "Renders a diagram like `render/2`, but returns the SVG itself."
  @spec render_svg(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def render_svg(code, opts \\ []) do
    with {:ok, name} <- render(code, opts), do: {:ok, File.read!(path(name))}
  end

  @doc """
  Renders several diagrams in parallel. Returns a map from each source to
  the name of its SVG file; blank sources and diagrams that fail are left
  out, the failures logged as warnings.
  """
  @spec render_all([String.t()], keyword()) :: %{String.t() => String.t()}
  def render_all(codes, opts \\ []) do
    codes
    |> Enum.uniq()
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Task.async_stream(&{&1, render(&1, opts)}, timeout: :infinity, ordered: false)
    |> Enum.reduce(%{}, fn
      {:ok, {code, {:ok, name}}}, diagrams ->
        Map.put(diagrams, code, name)

      {:ok, {_code, {:error, message}}}, diagrams ->
        Logger.warning("Diagram not rendered: #{message}")
        diagrams
    end)
  end

  @doc "The path of a rendered SVG file in the storage root."
  @spec path(String.t()) :: Path.t()
  def path(name), do: Path.join([Media.storage_root(), "diagrams", name])

  @doc "Returns true if `name` can be the name of a rendered SVG file."
  @spec file_name?(String.t()) :: boolean()
  def file_name?(name) when is_binary(name), do: name =~ @file_name

  defp reject_imports(code),
    do: if(code =~ @import, do: {:error, @import_error}, else: :ok)

  defp args(code) do
    layout = if code =~ @engine, do: [], else: ["--layout=#{@layout}"]
    layout ++ ["--theme=#{@light_theme}", "--dark-theme=#{@dark_theme}" | @options]
  end

  defp file_name(version, args, code),
    do: RenderTool.hash([version | args] ++ [@transparent_background, code]) <> ".svg"

  defp render_file(runner, args, code, name) do
    RenderTool.in_tmp_dir("feather-d2", fn dir ->
      File.write!(Path.join(dir, @input), code <> @transparent_background)

      case RenderTool.run(runner, args ++ [@input, @output], cd: dir, timeout: @timeout) do
        {:ok, _output} -> store(Path.join(dir, @output), name)
        {:error, message} -> cache_error(name, d2_error(message))
        {:aborted, message} -> {:error, message}
      end
    end)
  end

  # d2 names the files it failed to read in its messages.
  defp d2_error(message) do
    cond do
      message =~ "failed to bundle" -> @embed_error
      message =~ "failed to import" -> @import_error
      message =~ "out of memory" -> "d2 ran out of memory"
      true -> Regex.replace(~r{\S*/(?=diagram\.d2)}, message, "")
    end
  end

  defp store(file, name) do
    case File.read(file) do
      {:ok, svg} ->
        if svg =~ @embed,
          do: cache_error(name, @embed_error),
          else: write(path(name), svg, {:ok, name})

      {:error, _reason} ->
        {:error, "d2 wrote no SVG"}
    end
  end

  defp cached_error(name) do
    case File.read(error_path(name)) do
      {:ok, message} -> message
      {:error, _reason} -> nil
    end
  end

  defp cache_error(name, message), do: write(error_path(name), message, {:error, message})

  defp error_path(name), do: path(Path.rootname(name) <> ".error")

  defp write(target, content, result) do
    case RenderTool.write(target, content) do
      :ok -> result
      {:error, reason} -> {:error, "could not store the diagram: #{:file.format_error(reason)}"}
    end
  end
end
