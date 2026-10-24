defmodule Feather.Fediverse.Client do
  @moduledoc """
  Requests to fediverse servers: WebFinger, actors, keys, objects,
  pictures and deliveries. They follow the checked fetch of image
  downloads (`Feather.Media.Fetcher`), stricter:

    * https on port 443 only; every address the host resolves to must be
      public, and the connection goes to the checked address;
    * GETs follow at most 3 redirects, each checked again; POSTs follow
      none;
    * JSON at most 1 MB, pictures at most 2 MB, 10 seconds per request;
    * at most 10 requests at once and 3 per remote host, each redirect
      counted with its own host (`Feather.Fediverse.Limiter`); the
      inbox's fetches to check a signature (`pool: :inbox`) have a pool of
      their own;
    * every request is signed with the site's key, GETs too, for servers
      that require it (`Feather.Fediverse.SigningKey`).

  With `config :feather, :fediverse_proxy, {:http, "proxy", 3128}` (env
  `FEDIVERSE_PROXY=http://proxy:3128`) every request tunnels through that
  proxy to the checked address, so remote servers do not learn where the CMS runs. The
  proxy must reach only public addresses itself, or it becomes a way
  around the check into the network it sits in.

  Tests stub the requests with `Req.Test`
  (`config :feather, :fediverse_req_options, plug: ...`) and may send them
  through a limiter of their own
  (`config :feather, :fediverse_limiter, server: ..., timeout: ...`, for
  the inbox's pool `:fediverse_inbox_limiter`).
  """

  alias Feather.Fediverse.{Limiter, RemoteAccount, SigningKey}
  alias Feather.Media.Fetcher

  @json_max_bytes 1_000_000
  @picture_max_bytes 2_000_000
  @deadline 10_000

  @activity_streams ~s(application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams")
  @activity_streams_types ["application/activity+json", "application/ld+json"]
  @jrd_types ["application/jrd+json", "application/json"]

  @type error ::
          Fetcher.error() | :busy | :invalid_json | {:content_type, String.t() | nil}

  @doc """
  Fetches an ActivityStreams object (an actor, a key, a post) and returns
  it with the URL it came from after redirects. `:pool` names the
  limiter's pool (`:general` by default).
  """
  @spec get_object(String.t(), SigningKey.t(), keyword()) ::
          {:ok, map(), URI.t()} | {:error, error()}
  def get_object(url, %SigningKey{} = key, opts \\ []) do
    headers = [{"accept", @activity_streams}]

    with {:ok, response, final_url} <-
           request(url, key, :get, nil, @json_max_bytes, headers, opts),
         {:ok, document} <- decode_json(response, @activity_streams_types) do
      {:ok, document, final_url}
    end
  end

  @doc "Fetches a WebFinger answer (JRD); `:pool` as `get_object/3`."
  @spec get_webfinger(String.t(), SigningKey.t(), keyword()) :: {:ok, map()} | {:error, error()}
  def get_webfinger(url, %SigningKey{} = key, opts \\ []) do
    headers = [{"accept", Enum.join(@jrd_types, ", ")}]

    with {:ok, response, _final_url} <-
           request(url, key, :get, nil, @json_max_bytes, headers, opts) do
      decode_json(response, @jrd_types)
    end
  end

  @doc "Fetches a picture, at most 2 MB, as it came; checking what it is is the caller's job."
  @spec get_picture(String.t(), SigningKey.t()) :: {:ok, binary()} | {:error, error()}
  def get_picture(url, %SigningKey{} = key) do
    with {:ok, response, _final_url} <-
           request(url, key, :get, nil, @picture_max_bytes, [{"accept", "image/*"}]) do
      {:ok, response.body}
    end
  end

  @doc "Posts an activity (JSON) to an inbox."
  @spec post(String.t(), binary(), SigningKey.t()) :: :ok | {:error, error()}
  def post(url, body, %SigningKey{} = key) when is_binary(body) do
    headers = [{"accept", @activity_streams}, {"content-type", "application/activity+json"}]

    with {:ok, _response, _final_url} <- request(url, key, :post, body, @json_max_bytes, headers) do
      :ok
    end
  end

  defp request(url, key, method, body, max_bytes, headers, opts \\ []) do
    pool = Keyword.get(opts, :pool, :general)
    limiter_opts = [pool: pool] ++ Application.get_env(:feather, limiter_env(pool), [])

    Fetcher.request(url,
      max_bytes: max_bytes,
      method: method,
      body: body,
      headers: fn uri -> headers ++ SigningKey.sign(key, method, uri, body) end,
      limiter: fn uri, request ->
        Limiter.run(RemoteAccount.host(uri), request, limiter_opts)
      end,
      https_only: true,
      redirects: if(method == :get, do: 3, else: 0),
      timeout: @deadline,
      proxy: Application.get_env(:feather, :fediverse_proxy),
      req_options: Application.get_env(:feather, :fediverse_req_options, [])
    )
  end

  defp limiter_env(:general), do: :fediverse_limiter
  defp limiter_env(:inbox), do: :fediverse_inbox_limiter

  defp decode_json(response, content_types) do
    with :ok <- check_content_type(response, content_types),
         {:ok, %{} = document} <- Jason.decode(response.body) do
      {:ok, document}
    else
      {:error, {:content_type, _content_type}} = error -> error
      _invalid -> {:error, :invalid_json}
    end
  end

  defp check_content_type(response, content_types) do
    media_type = media_type(Req.Response.get_header(response, "content-type"))
    if media_type in content_types, do: :ok, else: {:error, {:content_type, media_type}}
  end

  @doc """
  The media type of the first of the values of a `content-type` header, in
  lower case and without parameters; nil without one.
  """
  @spec media_type([String.t()]) :: String.t() | nil
  def media_type([content_type | _]),
    do: content_type |> String.split(";") |> hd() |> String.trim() |> String.downcase()

  def media_type([]), do: nil
end
