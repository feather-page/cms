defmodule Feather.IndexNow do
  @moduledoc """
  Tells the search engines that take IndexNow (Bing, Yandex and others)
  which URLs of a site changed (ADR 0027), at `api.indexnow.org`.

  The engines check the key against the key file the export writes at the
  site root (`Feather.StaticSite.Routes.indexnow_key_path/1`). Tests stub
  the requests with `Req.Test` (`config :feather, :indexnow_req_options,
  plug: {Req.Test, Feather.IndexNow}`).
  """

  @endpoint "https://api.indexnow.org/indexnow"
  @max_urls 10_000

  @doc """
  Submits the URLs of the site at `host` with its key, in batches of at
  most 10,000. Stops at the first batch that fails.
  """
  @spec submit(String.t(), String.t(), [String.t()]) :: :ok | {:error, term()}
  def submit(host, key, urls) when is_binary(host) and is_binary(key) do
    urls
    |> Enum.chunk_every(@max_urls)
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      case submit_batch(host, key, batch) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp submit_batch(host, key, urls) do
    body = %{
      host: host,
      key: key,
      keyLocation: "https://#{host}/#{key}.txt",
      urlList: urls
    }

    case Req.post(req(), json: body) do
      {:ok, %Req.Response{status: status}} when status in [200, 202] -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, {:status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp req do
    [url: @endpoint, retry: false]
    |> Req.new()
    |> Req.merge(Application.get_env(:feather, :indexnow_req_options, []))
  end
end
