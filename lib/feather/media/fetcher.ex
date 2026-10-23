defmodule Feather.Media.Fetcher do
  @moduledoc """
  Downloads a file from a URL someone else gave us: an image for
  `Feather.Media.create_image_from_url/4`, a client's metadata document for
  `Feather.OAuth.ClientMetadata`.

    * The URL must pass `Feather.Media.UrlChecker.check/1`, its host must
      resolve to public addresses only (`Feather.Media.UrlChecker.resolve/2`)
      and the connection goes to the checked address
      (`Feather.Media.PinnedAdapter`).
    * At most 3 redirects are followed (`:redirects`), each target checked
      the same way.
    * The body may have at most `max_bytes` bytes; the download stops as
      soon as it exceeds them.
    * Everything (resolving, connecting, all redirects) shares one deadline,
      30 seconds unless `:timeout` says otherwise.

  Requests go through `Req`, so tests stub them with `Req.Test`: the
  `:req_options` (by default `config :feather, :image_fetch_req_options`)
  take a `plug:`, which replaces the pinned adapter; the checks before it
  stay.
  """

  alias Feather.Media.{PinnedAdapter, UrlChecker}

  @timeout 30_000
  @max_redirects 3
  @redirect_statuses [301, 302, 303, 307, 308]

  @type error ::
          {:invalid_url, String.t()}
          | :forbidden_address
          | :unresolvable
          | :too_large
          | :too_many_redirects
          | {:forbidden_redirect, String.t()}
          | {:status, pos_integer()}
          | Exception.t()

  @type option ::
          {:redirects, non_neg_integer()}
          | {:timeout, pos_integer()}
          | {:req_options, keyword()}

  @doc """
  Fetches `url`. Returns `{:ok, body}` or `{:error, reason}`; only
  `{:invalid_url, message}` is about the URL as given, every other reason
  comes from resolving or fetching it.
  """
  @spec fetch(String.t(), pos_integer(), [option()]) :: {:ok, binary()} | {:error, error()}
  def fetch(url, max_bytes, opts \\ []) do
    case UrlChecker.check(url) do
      {:ok, uri} ->
        limits = %{
          deadline: System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, @timeout),
          max_bytes: max_bytes,
          req_options:
            Keyword.get_lazy(opts, :req_options, fn ->
              Application.get_env(:feather, :image_fetch_req_options, [])
            end)
        }

        get(uri, limits, Keyword.get(opts, :redirects, @max_redirects))

      {:error, message} ->
        {:error, {:invalid_url, message}}
    end
  end

  defp get(uri, limits, redirects_left) do
    timeout = max(limits.deadline - System.monotonic_time(:millisecond), 0)

    with {:ok, ip} <- UrlChecker.resolve(uri.host, timeout),
         {:ok, response} <- request(uri, ip, limits) do
      handle_response(response, uri, limits, redirects_left)
    end
  end

  defp handle_response(response, uri, limits, redirects_left) do
    case response.status do
      status when status in 200..299 ->
        if byte_size(response.body) > limits.max_bytes,
          do: {:error, :too_large},
          else: {:ok, response.body}

      status when status in @redirect_statuses ->
        redirect(uri, response, limits, redirects_left)

      status ->
        {:error, {:status, status}}
    end
  end

  defp redirect(_uri, _response, _limits, 0), do: {:error, :too_many_redirects}

  defp redirect(uri, response, limits, redirects_left) do
    with [location | _] <- Req.Response.get_header(response, "location"),
         {:ok, location} <- URI.new(location),
         {:ok, next} <- uri |> URI.merge(location) |> URI.to_string() |> UrlChecker.check() do
      get(next, limits, redirects_left - 1)
    else
      {:error, message} when is_binary(message) -> {:error, {:forbidden_redirect, message}}
      _ -> {:error, {:status, response.status}}
    end
  end

  defp request(uri, ip, limits) do
    [
      url: uri,
      adapter: PinnedAdapter,
      redirect: false,
      retry: false,
      compressed: false,
      raw: true,
      decode_body: false
    ]
    |> Keyword.merge(limits.req_options)
    |> Req.new()
    |> Req.Request.put_private(:feather_pinned, %{
      ip: ip,
      deadline: limits.deadline,
      max_bytes: limits.max_bytes
    })
    |> Req.request()
  end
end
