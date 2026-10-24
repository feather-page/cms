defmodule Feather.Media.PinnedAdapter do
  @moduledoc """
  A `Req` adapter for fetching images from URLs users give us: it connects
  to an IP address that was resolved and checked beforehand
  (`Feather.Media.UrlChecker.resolve/2`) instead of resolving the host
  again, so DNS cannot answer differently between the check and the
  connection (DNS rebinding).

  The request URL keeps the host name. Mint gets the pinned address to
  connect to and the host name as its `:hostname` option, which Mint uses
  for the `Host` header, for TLS SNI and for certificate verification. An
  https URL therefore still verifies the certificate against the name in
  the URL, while the TCP connection goes to the checked address.

  With a proxy, an https request tunnels through it with `CONNECT` to the
  pinned address, so the proxy cannot resolve the name differently either;
  plain http never goes through a proxy, which would resolve the name
  itself.

  It opens one HTTP/1.1 connection per request (no pool, so no state per
  host is left behind) and closes it afterwards. The body is streamed and
  the request fails as soon as it exceeds `max_bytes`; all reads share one
  deadline.

  The request carries its parameters in `request.private.feather_pinned`:
  `%{ip: ip, deadline: monotonic_ms, max_bytes: n}`, optionally with
  `proxy: {scheme, host, port}`.
  """

  @connect_timeout 10_000

  @doc false
  def run(%Req.Request{} = request) do
    %{ip: ip, deadline: deadline, max_bytes: max_bytes} = params = request.private.feather_pinned
    {request, fetch(request, ip, Map.get(params, :proxy), deadline, max_bytes)}
  end

  defp fetch(request, ip, proxy, deadline, max_bytes) do
    uri = request.url
    scheme = if uri.scheme == "https", do: :https, else: :http

    with {:ok, timeout} <- remaining(deadline),
         {:ok, opts} <- connect_opts(scheme, uri, ip, proxy, min(timeout, @connect_timeout)),
         {:ok, conn} <- Mint.HTTP.connect(scheme, ip, uri.port, opts) do
      {conn, result} = request(conn, request, uri, deadline, max_bytes)
      Mint.HTTP.close(conn)
      result
    else
      {:error, exception} -> exception
    end
  end

  defp connect_opts(_scheme, uri, ip, nil, timeout) do
    family = if tuple_size(ip) == 8, do: [:inet6], else: []
    {:ok, mint_opts(uri, transport_opts: [timeout: timeout] ++ family)}
  end

  defp connect_opts(:https, uri, _ip, {proxy_scheme, proxy_host, proxy_port}, timeout) do
    proxy_opts = [transport_opts: [timeout: timeout], tunnel_timeout: timeout]

    {:ok,
     mint_opts(uri,
       transport_opts: [timeout: timeout],
       proxy: {proxy_scheme, proxy_host, proxy_port, proxy_opts}
     )}
  end

  defp connect_opts(:http, _uri, _ip, _proxy, _timeout),
    do: {:error, %ArgumentError{message: "only https requests go through a proxy"}}

  defp mint_opts(uri, opts),
    do: [hostname: uri.host, protocols: [:http1], mode: :passive] ++ opts

  defp request(conn, request, uri, deadline, max_bytes) do
    method = request.method |> to_string() |> String.upcase()
    headers = for {name, values} <- request.headers, value <- values, do: {name, value}

    case Mint.HTTP.request(conn, method, target(uri), headers, request.body) do
      {:ok, conn, ref} ->
        receive_response(
          conn,
          ref,
          %{status: nil, headers: [], body: [], size: 0},
          deadline,
          max_bytes
        )

      {:error, conn, exception} ->
        {conn, exception}
    end
  end

  defp receive_response(conn, ref, acc, deadline, max_bytes) do
    with {:ok, timeout} <- remaining(deadline),
         {:ok, conn, responses} <- Mint.HTTP.recv(conn, 0, timeout) do
      case handle_responses(responses, ref, acc, max_bytes) do
        {:cont, acc} ->
          receive_response(conn, ref, acc, deadline, max_bytes)

        {:done, acc} ->
          body = acc.body |> Enum.reverse() |> IO.iodata_to_binary()
          {conn, Req.Response.new(status: acc.status, headers: acc.headers, body: body)}

        {:error, exception} ->
          {conn, exception}
      end
    else
      {:error, exception} -> {conn, exception}
      {:error, conn, exception, _responses} -> {conn, exception}
    end
  end

  defp handle_responses([], _ref, acc, _max_bytes), do: {:cont, acc}

  defp handle_responses([{:status, ref, status} | rest], ref, acc, max_bytes),
    do: handle_responses(rest, ref, %{acc | status: status}, max_bytes)

  defp handle_responses([{:headers, ref, headers} | rest], ref, acc, max_bytes),
    do: handle_responses(rest, ref, %{acc | headers: acc.headers ++ headers}, max_bytes)

  defp handle_responses([{:data, ref, data} | rest], ref, acc, max_bytes) do
    size = acc.size + byte_size(data)

    if size > max_bytes do
      {:error, %RuntimeError{message: "response body exceeds #{max_bytes} bytes"}}
    else
      handle_responses(rest, ref, %{acc | body: [data | acc.body], size: size}, max_bytes)
    end
  end

  defp handle_responses([{:done, ref} | _rest], ref, acc, _max_bytes), do: {:done, acc}

  defp handle_responses([{:error, ref, exception} | _rest], ref, _acc, _max),
    do: {:error, exception}

  defp handle_responses([_other | rest], ref, acc, max_bytes),
    do: handle_responses(rest, ref, acc, max_bytes)

  defp remaining(deadline) do
    case deadline - System.monotonic_time(:millisecond) do
      timeout when timeout > 0 -> {:ok, timeout}
      _ -> {:error, %Req.TransportError{reason: :timeout}}
    end
  end

  defp target(%URI{path: path, query: query}) do
    path = if path in [nil, ""], do: "/", else: path
    if query, do: path <> "?" <> query, else: path
  end
end
