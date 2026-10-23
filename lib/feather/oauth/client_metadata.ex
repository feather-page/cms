defmodule Feather.OAuth.ClientMetadata do
  @moduledoc """
  The Client ID Metadata Document of an MCP client: the client's id is an
  HTTPS URL with a path, and the JSON document at that URL names the client
  (in at most 100 characters) and lists the redirect URIs it may use
  (ADR 0032).

  `fetch/1` downloads the document with `Feather.Media.Fetcher`: public
  addresses only, no redirects, at most 5 KB, within 10 seconds. Tests
  stub the request with `Req.Test` (`config :feather,
  :client_metadata_req_options, plug: {Req.Test, Feather.OAuth.ClientMetadata}`).

  A redirect URI must be listed exactly and use HTTPS, except on loopback
  (`localhost`, `127.0.0.1`): there it uses HTTP and matches on any port,
  for clients such as Claude Code that listen on a random port.
  """

  alias Feather.Media.Fetcher

  defstruct [:client_id, :client_name, :redirect_uris]

  @type t :: %__MODULE__{
          client_id: String.t(),
          client_name: String.t(),
          redirect_uris: [String.t()]
        }

  @type error ::
          :invalid_client_id
          | :unreachable
          | :invalid_metadata
          | :client_id_mismatch
          | :unsupported_auth_method

  @max_bytes 5_000
  @max_client_name_length 100
  @timeout 10_000
  @loopback_hosts ["localhost", "127.0.0.1"]
  @dns_name ~r/\A[a-z0-9-]+(\.[a-z0-9-]+)*\z/i

  @doc """
  Fetches and checks the metadata document of the client `client_id`.
  """
  @spec fetch(term()) :: {:ok, t()} | {:error, error()}
  def fetch(client_id) do
    with :ok <- check_client_id(client_id),
         {:ok, body} <- download(client_id),
         {:ok, document} <- decode(body) do
      build(document, client_id)
    end
  end

  @doc """
  Checks that the client may send members back to `redirect_uri`.
  """
  @spec check_redirect_uri(t(), term()) :: :ok | {:error, :invalid_redirect_uri}
  def check_redirect_uri(%__MODULE__{redirect_uris: listed}, redirect_uri) do
    if allowed_redirect_uri?(redirect_uri) and Enum.any?(listed, &same?(&1, redirect_uri)),
      do: :ok,
      else: {:error, :invalid_redirect_uri}
  end

  @doc """
  Whether `redirect_uri` leads back to a program on the member's own computer.
  """
  @spec loopback?(String.t()) :: boolean()
  def loopback?(redirect_uri) do
    match?(%URI{scheme: "http", host: host} when host in @loopback_hosts, URI.parse(redirect_uri))
  end

  defp check_client_id(client_id) when is_binary(client_id) do
    case URI.new(client_id) do
      {:ok,
       %URI{scheme: "https", host: host, userinfo: nil, fragment: nil, path: "/" <> _ = path}}
      when host not in [nil, ""] ->
        if dot_segments?(path), do: {:error, :invalid_client_id}, else: :ok

      _ ->
        {:error, :invalid_client_id}
    end
  end

  defp check_client_id(_client_id), do: {:error, :invalid_client_id}

  defp dot_segments?(path), do: path |> String.split("/") |> Enum.any?(&(&1 in [".", ".."]))

  defp download(client_id) do
    options = [
      redirects: 0,
      timeout: @timeout,
      req_options: Application.get_env(:feather, :client_metadata_req_options, [])
    ]

    case Fetcher.fetch(client_id, @max_bytes, options) do
      {:ok, body} -> {:ok, body}
      {:error, _reason} -> {:error, :unreachable}
    end
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, %{} = document} -> {:ok, document}
      _ -> {:error, :invalid_metadata}
    end
  end

  defp build(%{"client_id" => client_id} = document, client_id) do
    with {:ok, client_name} <- client_name(document),
         {:ok, redirect_uris} <- redirect_uris(document),
         :ok <- check_auth_method(document) do
      {:ok,
       %__MODULE__{client_id: client_id, client_name: client_name, redirect_uris: redirect_uris}}
    end
  end

  defp build(%{"client_id" => _other}, _client_id), do: {:error, :client_id_mismatch}
  defp build(_document, _client_id), do: {:error, :invalid_metadata}

  defp client_name(%{"client_name" => name}) when is_binary(name) do
    name = String.trim(name)

    if name != "" and String.length(name) <= @max_client_name_length,
      do: {:ok, name},
      else: {:error, :invalid_metadata}
  end

  defp client_name(_document), do: {:error, :invalid_metadata}

  defp redirect_uris(%{"redirect_uris" => [_ | _] = uris}) do
    if Enum.all?(uris, &is_binary/1), do: {:ok, uris}, else: {:error, :invalid_metadata}
  end

  defp redirect_uris(_document), do: {:error, :invalid_metadata}

  defp check_auth_method(document) do
    if Map.get(document, "token_endpoint_auth_method", "none") == "none",
      do: :ok,
      else: {:error, :unsupported_auth_method}
  end

  defp allowed_redirect_uri?(redirect_uri) when is_binary(redirect_uri) do
    case URI.new(redirect_uri) do
      {:ok, %URI{scheme: "https", host: host, fragment: nil}} when is_binary(host) ->
        Regex.match?(@dns_name, host)

      {:ok, %URI{scheme: "http", host: host, fragment: nil}} ->
        host in @loopback_hosts

      _ ->
        false
    end
  end

  defp allowed_redirect_uri?(_redirect_uri), do: false

  defp same?(listed, redirect_uri) do
    listed == redirect_uri or
      (loopback?(redirect_uri) and without_port(listed) == without_port(redirect_uri))
  end

  defp without_port(uri), do: uri |> URI.parse() |> Map.put(:port, nil) |> URI.to_string()
end
