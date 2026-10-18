defmodule Feather.Highlighting do
  @moduledoc """
  Highlights the code of code blocks with the `chroma` binary (ADR 0020):
  HTML spans whose CSS classes carry the prefix `hl-`, without chroma's own
  `pre`, for the site themes and the editor to colour.

  Only the languages of a fixed map are highlighted, and only the lexer
  names of that map reach chroma: it reads an unknown `--lexer` as the path
  of a lexer file. Other languages, blank code and failures stay plain.

  chroma reads the code from a file in an empty temporary directory: a
  port cannot close a command's standard input. Output holding markup
  other than the token spans is rejected.

  The HTML is cached as `<storage_root>/highlights/<hash>.html`, the hash a
  SHA-256 of the chroma version, the options, the lexer and the code, so
  each block runs chroma once. Failures (chroma missing, failing, timing
  out or raising) are logged as warnings and not cached. Old files stay.

  Commands go through a runner (`Feather.Highlighting.Runner`, see
  `Feather.RenderTool`). Tests pass a fake one; the default is
  `config :feather, :chroma_runner` or `Feather.Highlighting.SystemRunner`.
  The chroma version is asked once per runner module.
  """

  alias Feather.Highlighting.SystemRunner
  alias Feather.{Media, RenderTool}

  require Logger

  @lexers %{
    "bash" => "bash",
    "cpp" => "cpp",
    "csharp" => "csharp",
    "css" => "css",
    "elixir" => "elixir",
    "go" => "go",
    "html" => "html",
    "java" => "java",
    "javascript" => "javascript",
    "json" => "json",
    "kotlin" => "kotlin",
    "php" => "php",
    "python" => "python",
    "ruby" => "ruby",
    "rust" => "rust",
    "sql" => "sql",
    "swift" => "swift",
    "typescript" => "typescript",
    "xml" => "xml",
    "yaml" => "yaml"
  }

  @options ~w(--html --html-only --html-prevent-surrounding-pre --html-prefix=hl-)
  @input "code"
  @timeout :timer.seconds(10)
  @version_timeout :timer.seconds(10)
  @markup ~r/<(?!span class="hl-[a-z0-9]+">|\/span>)/

  @doc """
  Highlights code. Returns the HTML of its token spans, or `:plain` for code
  that stays plain.

  Options: `:runner` (default: see the module doc).
  """
  @spec highlight(String.t(), String.t(), keyword()) :: {:ok, String.t()} | :plain
  def highlight(code, language, opts \\ []) when is_binary(code) do
    case lexer(code, language) do
      nil -> :plain
      lexer -> plain_on_error(fn -> highlight_with(runner(opts), lexer, code) end)
    end
  end

  @doc """
  Highlights the code of several `{code, language}` blocks in parallel.
  Returns a map from each block to its HTML; blocks that stay plain are left
  out.
  """
  @spec highlight_all([{String.t(), String.t()}], keyword()) ::
          %{{String.t(), String.t()} => String.t()}
  def highlight_all(blocks, opts \\ []) do
    runner = runner(opts)

    blocks =
      for {code, language} = block <- Enum.uniq(blocks),
          lexer = lexer(code, language),
          do: {block, lexer}

    with [_ | _] <- blocks,
         {:ok, version} <- plain_on_error(fn -> version(runner) end) do
      highlight_blocks(blocks, runner, version)
    else
      _plain -> %{}
    end
  end

  defp highlight_blocks(blocks, runner, version) do
    blocks
    |> Task.async_stream(
      fn {{code, _language} = block, lexer} ->
        {block, plain_on_error(fn -> cached(runner, version, lexer, code) end)}
      end,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.reduce(%{}, fn
      {:ok, {block, {:ok, html}}}, highlights -> Map.put(highlights, block, html)
      {:ok, {_block, :plain}}, highlights -> highlights
    end)
  end

  defp highlight_with(runner, lexer, code) do
    with {:ok, version} <- version(runner), do: cached(runner, version, lexer, code)
  end

  defp lexer(code, language) when is_binary(code) and is_binary(language),
    do: if(String.trim(code) != "", do: Map.get(@lexers, String.trim(language)))

  defp lexer(_code, _language), do: nil

  defp cached(runner, version, lexer, code) do
    args = [@input, "--lexer", lexer | @options]

    path =
      Path.join([
        Media.storage_root(),
        "highlights",
        RenderTool.hash([version | args] ++ [code]) <> ".html"
      ])

    case File.read(path) do
      {:ok, html} -> {:ok, html}
      {:error, _reason} -> run_and_store(runner, args, code, path)
    end
  end

  defp run_and_store(runner, args, code, path) do
    RenderTool.in_tmp_dir("feather-chroma", fn dir ->
      File.write!(Path.join(dir, @input), code)

      with {:ok, html} <- run(runner, args, cd: dir, timeout: @timeout),
           :ok <- check_markup(html),
           :ok <- RenderTool.write(path, html) do
        {:ok, html}
      else
        {:error, reason} when is_atom(reason) ->
          {:error, "could not store the highlighted code: #{:file.format_error(reason)}"}

        error ->
          error
      end
    end)
  end

  defp run(runner, args, opts) do
    case RenderTool.run(runner, args, opts) do
      {:aborted, message} -> {:error, message}
      result -> result
    end
  end

  defp check_markup(html),
    do: if(html =~ @markup, do: {:error, "chroma returned unexpected markup"}, else: :ok)

  defp version(runner), do: RenderTool.version(runner, @version_timeout)

  defp runner(opts), do: RenderTool.runner(opts, :chroma_runner, SystemRunner)

  # Highlighting must never take the export's async_stream down.
  defp plain_on_error(fun) do
    case fun.() do
      {:error, message} -> warn(message)
      result -> result
    end
  rescue
    exception -> warn(Exception.message(exception))
  end

  defp warn(message) do
    Logger.warning("Code not highlighted: #{message}")
    :plain
  end
end
