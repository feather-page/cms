defmodule Feather.Media.Fetcher do
  @moduledoc """
  Requests a URL that someone else chose (a user's image URL, a client's
  metadata document for `Feather.OAuth.ClientMetadata`, a fediverse
  server's address) from the server, the checked way:

    * The URL must pass `Feather.Media.UrlChecker.check/1`, its host must
      resolve to public addresses only (`Feather.Media.UrlChecker.resolve/2`)
      and the connection goes to the checked address
      (`Feather.Media.PinnedAdapter`).
    * At most 3 redirects are followed, each target checked the same way.
    * The body may have at most `max_bytes` bytes; the download stops as
      soon as it exceeds them.
    * Everything (resolving, connecting, all redirects) shares one deadline,
      30 seconds unless told otherwise.

  A response that is neither 2xx nor a redirect followed is
  `{:status, status, excerpt}`, the excerpt at most 300 bytes of its
  body, whitespace collapsed.

  `fetch/3` returns the body; `request/2` returns the response and can
  also require https on port 443, send a body, headers per requested URL
  and the request through a proxy, and run each request through a limiter.

  Requests go through `Req`, so tests stub them with `Req.Test`: the
  `:req_options` (by default `config :feather, :image_fetch_req_options`)
  take a `plug:`, which replaces the pinned adapter; the checks before it
  stay.
  """

  alias Feather.Media.{PinnedAdapter, UrlChecker}

  @timeout 30_000
  @max_redirects 3
  @redirect_statuses [301, 302, 303, 307, 308]
  @excerpt_bytes 300

  @type error ::
          {:invalid_url, String.t()}
          | :forbidden_address
          | :unresolvable
          | :too_large
          | :too_many_redirects
          | {:forbidden_redirect, String.t()}
          | {:status, pos_integer(), String.t()}
          | Exception.t()

  @type option ::
          {:redirects, non_neg_integer()}
          | {:timeout, pos_integer()}
          | {:req_options, keyword()}

  @doc """
  Fetches `url`. Returns `{:ok, body}` or `{:error, reason}`; only
  `{:invalid_url, message}` is about the URL as given, every other reason
  comes from resolving or fetching it. Takes the options `:redirects`,
  `:timeout` and `:req_options` of `request/2`.
  """
  @spec fetch(String.t(), pos_integer(), [option()]) :: {:ok, binary()} | {:error, error()}
  def fetch(url, max_bytes, opts \\ []) do
    with {:ok, response, _url} <- request(url, [max_bytes: max_bytes] ++ opts),
         do: {:ok, response.body}
  end

  @doc """
  Requests `url` and returns the successful (2xx) response with the URL it
  came from after redirects, or `{:error, reason}` as `fetch/3` does.

  Options:

    * `:max_bytes` (required) - the most bytes the body may have
    * `:method` - `:get` (default) or `:post`
    * `:body` - the request's body
    * `:headers` - a function that returns the headers of a request to
      each URI (the first one and every redirect target), say to sign it
    * `:https_only` - only https on port 443 (default `false`)
    * `:redirects` - the most redirects to follow, default 3; with 0 a
      redirect is an error
    * `:timeout` - milliseconds for everything from the first request on,
      default 30 seconds
    * `:limiter` - a function that runs each request (to the first URI
      and to every redirect target) and returns its result, given the URI
      and a function that makes the request, say to cap the requests per
      host
    * `:proxy` - `{scheme, host, port}` of a proxy that https requests
      tunnel through to the checked address
    * `:req_options` - merged into the `Req` options, default
      `config :feather, :image_fetch_req_options`
  """
  @spec request(String.t(), keyword()) :: {:ok, Req.Response.t(), URI.t()} | {:error, error()}
  def request(url, opts) do
    opts =
      Keyword.merge(
        [
          method: :get,
          headers: fn _uri -> [] end,
          limiter: fn _uri, request -> request.() end,
          https_only: false,
          redirects: @max_redirects,
          timeout: @timeout,
          req_options: Application.get_env(:feather, :image_fetch_req_options, [])
        ],
        opts
      )

    case check(url, opts) do
      {:ok, uri} ->
        get(uri, nil, opts, opts[:redirects])

      {:error, message} ->
        {:error, {:invalid_url, message}}
    end
  end

  defp check(url, opts) do
    with {:ok, uri} <- UrlChecker.check(url) do
      cond do
        not opts[:https_only] -> {:ok, uri}
        uri.scheme != "https" -> {:error, "Forbidden Schema: #{url}"}
        uri.port != 443 -> {:error, "Forbidden Port: #{url}"}
        true -> {:ok, uri}
      end
    end
  end

  defp get(uri, deadline, opts, redirects_left) do
    result =
      opts[:limiter].(uri, fn ->
        deadline = deadline || System.monotonic_time(:millisecond) + opts[:timeout]
        timeout = max(deadline - System.monotonic_time(:millisecond), 0)

        with {:ok, ip} <- UrlChecker.resolve(uri.host, timeout),
             {:ok, response} <- send_request(uri, ip, deadline, opts),
             do: {:ok, response, deadline}
      end)

    with {:ok, response, deadline} <- result do
      handle_response(response, uri, deadline, opts, redirects_left)
    end
  end

  defp handle_response(response, uri, deadline, opts, redirects_left) do
    case response.status do
      status when status in 200..299 ->
        if byte_size(response.body) > opts[:max_bytes],
          do: {:error, :too_large},
          else: {:ok, response, uri}

      status when status in @redirect_statuses ->
        redirect(uri, response, deadline, opts, redirects_left)

      status ->
        {:error, {:status, status, excerpt(response.body)}}
    end
  end

  defp excerpt(body) when is_binary(body) do
    body
    |> binary_part(0, min(byte_size(body), @excerpt_bytes * 2))
    |> String.replace_invalid()
    |> String.split()
    |> Enum.join(" ")
    |> truncate()
  end

  defp excerpt(_body), do: ""

  defp truncate(text) when byte_size(text) <= @excerpt_bytes, do: text
  defp truncate(text), do: text |> binary_part(0, @excerpt_bytes) |> String.replace_invalid("")

  defp redirect(_uri, _response, _deadline, _opts, 0), do: {:error, :too_many_redirects}

  defp redirect(uri, response, deadline, opts, redirects_left) do
    with [location | _] <- Req.Response.get_header(response, "location"),
         {:ok, location} <- URI.new(location),
         {:ok, next} <- uri |> URI.merge(location) |> URI.to_string() |> check(opts) do
      get(next, deadline, opts, redirects_left - 1)
    else
      {:error, message} when is_binary(message) -> {:error, {:forbidden_redirect, message}}
      _ -> {:error, {:status, response.status, excerpt(response.body)}}
    end
  end

  defp send_request(uri, ip, deadline, opts) do
    [
      url: uri,
      method: opts[:method],
      body: opts[:body],
      headers: opts[:headers].(uri),
      adapter: PinnedAdapter,
      redirect: false,
      retry: false,
      compressed: false,
      raw: true,
      decode_body: false
    ]
    |> Keyword.merge(opts[:req_options])
    |> Req.new()
    |> Req.Request.put_private(:feather_pinned, %{
      ip: ip,
      deadline: deadline,
      max_bytes: opts[:max_bytes],
      proxy: opts[:proxy]
    })
    |> Req.request()
  end
end
