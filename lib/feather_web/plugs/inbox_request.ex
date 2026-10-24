defmodule FeatherWeb.Plugs.InboxRequest do
  @moduledoc """
  Admits a request to the inbox of a site's fediverse account
  (`FeatherWeb.FediverseInboxController`), cheapest checks first:

    * the path is exactly `/fediverse/inbox/<site public id>`, with
      nothing encoded and no dot segments (else 404);
    * the client sent at most 300 requests within 5 minutes
      (`Feather.Fediverse.check_inbox_client/1`, else 429); behind a
      proxy in a private network, the client is the last public address
      in `x-forwarded-for`, with or without a port (`1.2.3.4:5678`,
      `[2001:db8::1]:5678`);
    * the body is ActivityStreams JSON (`application/activity+json` or
      `application/ld+json`, else 415) of at most 1 MB (else 413), read
      here before anything parses it, and a JSON object (else 400).

  Assigns the raw body, for the digest, as `:raw_body` and the activity
  as `:activity`; neither goes into the params, so neither is logged.
  """

  @behaviour Plug

  import Plug.Conn

  alias Feather.Fediverse
  alias Feather.Fediverse.Client
  alias Feather.Media.UrlChecker

  @max_bytes 1_000_000
  @media_types ["application/activity+json", "application/ld+json"]
  @site_id ~r/\A[0-9A-Za-z_-]+\z/

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with :ok <- check_path(conn),
         :ok <- check_client(conn),
         :ok <- check_media_type(conn),
         :ok <- check_length(conn),
         {:ok, body, activity, conn} <- read_activity(conn) do
      conn |> assign(:raw_body, body) |> assign(:activity, activity)
    else
      {:error, status} -> reject(conn, status)
      {:error, status, conn} -> reject(conn, status)
    end
  end

  defp reject(conn, status), do: conn |> send_resp(status, "") |> halt()

  defp check_path(%Plug.Conn{request_path: "/fediverse/inbox/" <> site_id}) do
    if Regex.match?(@site_id, site_id), do: :ok, else: {:error, 404}
  end

  defp check_path(_conn), do: {:error, 404}

  defp check_client(conn) do
    case Fediverse.check_inbox_client(client_ip(conn)) do
      :ok -> :ok
      {:error, :rate_limited} -> {:error, 429}
    end
  end

  defp client_ip(%Plug.Conn{remote_ip: peer} = conn) do
    if UrlChecker.public_address?(peer) do
      peer
    else
      conn |> forwarded_for() |> Enum.reverse() |> Enum.find(peer, &UrlChecker.public_address?/1)
    end
  end

  defp forwarded_for(conn) do
    for header <- get_req_header(conn, "x-forwarded-for"),
        entry <- String.split(header, ","),
        address = entry |> String.trim() |> without_port(),
        {:ok, ip} <- [address |> String.to_charlist() |> :inet.parse_address()],
        do: ip
  end

  defp without_port("[" <> bracketed), do: bracketed |> String.split("]", parts: 2) |> hd()

  defp without_port(address) do
    case String.split(address, ":") do
      [ipv4, _port] -> ipv4
      _ipv4_or_ipv6 -> address
    end
  end

  defp check_media_type(conn) do
    if Client.media_type(get_req_header(conn, "content-type")) in @media_types,
      do: :ok,
      else: {:error, 415}
  end

  defp read_activity(conn) do
    case read_body(conn, length: @max_bytes) do
      {:ok, body, conn} -> decode(body, conn)
      {:more, _partial, conn} -> {:error, 413, conn}
      {:error, _reason} -> {:error, 400, conn}
    end
  end

  defp decode(body, conn) do
    case Jason.decode(body) do
      {:ok, %{} = activity} -> {:ok, body, activity, conn}
      _not_an_object -> {:error, 400, conn}
    end
  end

  defp check_length(conn) do
    with [length | _] <- get_req_header(conn, "content-length"),
         {length, ""} <- Integer.parse(length),
         true <- length > @max_bytes do
      {:error, 413}
    else
      _within_limit_or_unknown -> :ok
    end
  end
end
