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
    Req.new(
      url: url,
      method: Keyword.get(opts, :method, :get),
      body: opts[:body],
      adapter: PinnedAdapter,
      retry: false,
      compressed: false,
      raw: true
    )
    |> Req.Request.put_private(:feather_pinned, %{
      ip: Keyword.get(opts, :ip, {127, 0, 0, 1}),
      deadline: System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, 5_000),
      max_bytes: Keyword.get(opts, :max_bytes, 1_000_000),
      proxy: opts[:proxy]
    })
    |> Req.request()
  end

  test "sends the request's body", %{port: port} do
    assert {:ok, %Req.Response{status: 200, body: "POST hello"}} =
             get("http://pinned.example:#{port}/echo", method: :post, body: "hello")
  end

  test "tunnels https through a proxy to the pinned address" do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, packet: :line, ip: {127, 0, 0, 1}])

    {:ok, proxy_port} = :inet.port(listener)
    test_pid = self()

    proxy =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 5_000)
        {:ok, request_line} = :gen_tcp.recv(socket, 0, 5_000)
        send(test_pid, {:proxy_request, request_line})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 403 Forbidden\r\ncontent-length: 0\r\n\r\n")
        _ = :gen_tcp.recv(socket, 0, 1_000)
        :gen_tcp.close(socket)
      end)

    assert {:error, _exception} =
             get("https://pinned.example/inbox",
               ip: {93, 184, 215, 14},
               proxy: {:http, "127.0.0.1", proxy_port}
             )

    assert_receive {:proxy_request, "CONNECT 93.184.215.14:443 HTTP/1.1\r\n"}
    Task.await(proxy)
  end

  test "sends plain http through no proxy", %{port: port} do
    assert {:error, %ArgumentError{}} =
             get("http://pinned.example:#{port}/a.png", proxy: {:http, "127.0.0.1", port})
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
