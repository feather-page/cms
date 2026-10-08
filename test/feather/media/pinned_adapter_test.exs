defmodule Feather.Media.PinnedAdapterTest do
  # Talks to a real HTTP server on 127.0.0.1 (no Req.Test stub).
  use ExUnit.Case, async: true

  alias Feather.Media.PinnedAdapter

  setup do
    server =
      start_supervised!(
        {Bandit,
         plug: Feather.PinnedAdapterTestServer, ip: :loopback, port: 0, startup_log: false}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    %{port: port}
  end

  defp get(url, opts) do
    Req.new(url: url, adapter: PinnedAdapter, retry: false, compressed: false, raw: true)
    |> Req.Request.put_private(:feather_pinned, %{
      ip: Keyword.get(opts, :ip, {127, 0, 0, 1}),
      deadline: System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, 5_000),
      max_bytes: Keyword.get(opts, :max_bytes, 1_000_000)
    })
    |> Req.request()
  end

  test "connects to the pinned address and keeps the host name of the URL", %{port: port} do
    # The name does not resolve; only the pinned address is used.
    assert {:ok, %Req.Response{status: 200, body: body}} =
             get("http://images.does-not-exist.invalid:#{port}/a.png?x=1", [])

    assert body == "host=images.does-not-exist.invalid:#{port} path=/a.png?x=1"
  end

  test "stops reading a body over max_bytes", %{port: port} do
    assert {:error, %RuntimeError{message: "response body exceeds 10000 bytes"}} =
             get("http://pinned.example:#{port}/big", max_bytes: 10_000)

    assert {:ok, %Req.Response{body: body}} = get("http://pinned.example:#{port}/big", [])
    assert byte_size(body) == 100_000
  end

  test "gives up at the deadline", %{port: port} do
    assert {:error, %{__exception__: true}} =
             get("http://pinned.example:#{port}/slow", timeout: 200)
  end
end
