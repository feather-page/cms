defmodule Feather.FakeD2 do
  @moduledoc """
  A fake `d2` for tests that render content (`config :feather,
  :d2_runner`). It writes an SVG holding the source and sends
  `{:d2_rendered, source}` to the test process; a source containing
  "broken" fails like invalid D2. Each installation has a d2 version of its
  own, so diagrams cached by other tests never hit.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc "Makes the fake the d2 runner until the test exits."
  def install do
    test = self()
    version = "v0.0.0-fake-#{System.unique_integer([:positive])}"
    previous = Application.fetch_env(:feather, :d2_runner)

    Application.put_env(:feather, :d2_runner, &run(&1, &2, test, version))

    on_exit(fn ->
      case previous do
        {:ok, runner} -> Application.put_env(:feather, :d2_runner, runner)
        :error -> Application.delete_env(:feather, :d2_runner)
      end
    end)
  end

  defp run(["--version"], _opts, _test, version), do: {:ok, version <> "\n"}

  defp run(_args, opts, test, _version) do
    source = opts[:cd] |> Path.join("diagram.d2") |> File.read!()
    send(test, {:d2_rendered, source})

    if source =~ "broken" do
      {:error, "err: failed to compile diagram.d2: diagram.d2:1:1: broken"}
    else
      File.write!(Path.join(opts[:cd], "diagram.svg"), "<svg>#{source}</svg>")
      {:ok, ""}
    end
  end
end
