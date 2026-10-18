defmodule Feather.FakeChroma do
  @moduledoc """
  A fake `chroma` for tests that render content (`config :feather,
  :chroma_runner`). It wraps the escaped code in one `hl-fake` span and
  sends `{:chroma_highlighted, lexer, code}` to the test process. Each
  installation has a chroma version of its own, so blocks cached by other
  tests never hit.

  `install(:missing)` behaves like a chroma that is not installed,
  `install(:timeout)` like one that runs longer than its timeout.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc "Makes the fake the chroma runner until the test exits."
  def install(mode \\ :ok) do
    test = self()
    version = "0.0.0-fake-#{System.unique_integer([:positive])}"
    previous = Application.fetch_env(:feather, :chroma_runner)

    Application.put_env(:feather, :chroma_runner, &run(&1, &2, mode, test, version))

    on_exit(fn ->
      case previous do
        {:ok, runner} -> Application.put_env(:feather, :chroma_runner, runner)
        :error -> Application.delete_env(:feather, :chroma_runner)
      end
    end)
  end

  @doc "The HTML the fake returns for `code`."
  def html(code), do: ~s(<span class="hl-fake">#{Plug.HTML.html_escape(code)}</span>)

  defp run(_args, _opts, :missing, _test, _version), do: {:aborted, "chroma is not installed"}
  defp run(["--version"], _opts, _mode, _test, version), do: {:ok, version <> "\n"}

  defp run(_args, _opts, :timeout, _test, _version),
    do: {:aborted, "chroma timed out after 10 seconds"}

  defp run(["code", "--lexer", lexer | _args], opts, :ok, test, _version) do
    code = opts[:cd] |> Path.join("code") |> File.read!()
    send(test, {:chroma_highlighted, lexer, code})
    {:ok, html(code)}
  end
end
