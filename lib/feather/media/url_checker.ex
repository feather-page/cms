defmodule Feather.Media.UrlChecker do
  @moduledoc """
  Decides whether a URL may be fetched from the server (protection against
  server-side request forgery; Rails' `ExternalUrlChecker`, extended).

  `check/1` looks at the URL alone: only http and https, only the ports 80
  and 443, no `localhost`, and IP literals only in canonical form and only
  public ones. IPv4 forms that resolvers and browsers accept but that hide
  the address (`2130706433`, `127.1`, `0177.0.0.1`, `0x7f.0.0.1`) are
  rejected: a host whose last label is a number must be a canonical
  dotted quad.

  `resolve/2` resolves the host name (IPv4 and IPv6) and accepts it only if
  every address is public (`public_address?/1`), so a name such as
  `127.0.0.1.nip.io` is caught. The caller connects to the returned address
  (see `Feather.Media.PinnedAdapter`), so a second DNS answer cannot point
  the connection elsewhere (DNS rebinding).

  The resolver is configurable for tests:
  `config :feather, :image_fetch_resolver, {Module, :function}`, called
  with the host and a timeout in milliseconds and returning
  `{:ok, [ip_address]}` or `{:error, reason}`.
  """

  import Bitwise

  # IPv4 networks that are not publicly routable or not unicast.
  @ipv4_blocked [
    # "this network", 0.0.0.0
    {{0, 0, 0, 0}, 8},
    {{10, 0, 0, 0}, 8},
    # carrier-grade NAT
    {{100, 64, 0, 0}, 10},
    {{127, 0, 0, 0}, 8},
    {{169, 254, 0, 0}, 16},
    {{172, 16, 0, 0}, 12},
    # IETF protocol assignments, TEST-NET-1, 6to4 relay anycast
    {{192, 0, 0, 0}, 24},
    {{192, 0, 2, 0}, 24},
    {{192, 88, 99, 0}, 24},
    {{192, 168, 0, 0}, 16},
    # benchmarking, TEST-NET-2, TEST-NET-3
    {{198, 18, 0, 0}, 15},
    {{198, 51, 100, 0}, 24},
    {{203, 0, 113, 0}, 24},
    # multicast
    {{224, 0, 0, 0}, 4},
    # reserved, including the broadcast address 255.255.255.255
    {{240, 0, 0, 0}, 4}
  ]

  # Special networks inside the global unicast range 2000::/3.
  @ipv6_blocked [
    # IETF protocol assignments (Teredo, benchmarking, ORCHID, ...)
    {{0x2001, 0, 0, 0, 0, 0, 0, 0}, 23},
    # documentation
    {{0x2001, 0xDB8, 0, 0, 0, 0, 0, 0}, 32},
    {{0x3FFF, 0, 0, 0, 0, 0, 0, 0}, 20}
  ]

  @canonical_ipv4 ~r/\A(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\z/

  @doc """
  Returns `{:ok, uri}` for an acceptable URL, `{:error, reason}` otherwise.
  Does not resolve the host, see `resolve/2`.
  """
  @spec check(String.t()) :: {:ok, URI.t()} | {:error, String.t()}
  def check(url) when is_binary(url) do
    with {:ok, uri} <- parse(url),
         :ok <- check_scheme(uri),
         :ok <- require_host(uri),
         :ok <- check_host(uri),
         :ok <- check_port(uri) do
      {:ok, uri}
    else
      {:error, message} -> {:error, "#{message}: #{url}"}
    end
  end

  def check(_url), do: {:error, "Invalid URL"}

  @doc """
  Resolves a host checked by `check/1` to the address to connect to.

  Returns `{:error, :forbidden_address}` when any address of the host is
  not public and `{:error, :unresolvable}` when it has none. IPv4 is
  preferred when the host has both.
  """
  @spec resolve(String.t(), non_neg_integer()) ::
          {:ok, :inet.ip_address()} | {:error, :forbidden_address | :unresolvable}
  def resolve(host, timeout) when is_binary(host) do
    addresses =
      case ip_literal(host) do
        {:ok, ip} ->
          {:ok, [ip]}

        :error ->
          {module, function} =
            Application.get_env(:feather, :image_fetch_resolver, {__MODULE__, :system_resolve})

          apply(module, function, [host, timeout])
      end

    case addresses do
      {:ok, [_ | _] = ips} ->
        if Enum.all?(ips, &public_address?/1),
          do: {:ok, Enum.find(ips, hd(ips), &(tuple_size(&1) == 4))},
          else: {:error, :forbidden_address}

      _ ->
        {:error, :unresolvable}
    end
  end

  @doc """
  Resolves a host name with the system resolver, IPv4 and IPv6.
  """
  @spec system_resolve(String.t(), non_neg_integer()) ::
          {:ok, [:inet.ip_address()]} | {:error, :nxdomain}
  def system_resolve(host, timeout) do
    host = String.to_charlist(host)

    addresses =
      for family <- [:inet, :inet6],
          {:ok, ips} <- [:inet.getaddrs(host, family, timeout)],
          ip <- ips,
          do: ip

    if addresses == [], do: {:error, :nxdomain}, else: {:ok, Enum.uniq(addresses)}
  end

  @doc """
  Returns true for a public unicast address. IPv4 addresses embedded in
  IPv6 (IPv4-mapped, IPv4-compatible, NAT64 `64:ff9b::/96` and 6to4) are
  judged by the IPv4 address; other IPv6 addresses must be global unicast
  (`2000::/3`) outside the special purpose networks.
  """
  @spec public_address?(:inet.ip_address()) :: boolean()
  def public_address?({_, _, _, _} = ip), do: not Enum.any?(@ipv4_blocked, &in_network?(ip, &1))

  def public_address?({0, 0, 0, 0, 0, 0xFFFF, hi, lo}), do: public_address?(ipv4(hi, lo))
  def public_address?({0, 0, 0, 0, 0, 0, hi, lo}), do: public_address?(ipv4(hi, lo))
  def public_address?({0x64, 0xFF9B, 0, 0, 0, 0, hi, lo}), do: public_address?(ipv4(hi, lo))
  def public_address?({0x2002, hi, lo, _, _, _, _, _}), do: public_address?(ipv4(hi, lo))

  def public_address?({a, _, _, _, _, _, _, _} = ip) when a in 0x2000..0x3FFF,
    do: not Enum.any?(@ipv6_blocked, &in_network?(ip, &1))

  def public_address?(_ip), do: false

  defp ipv4(hi, lo), do: {hi >>> 8, hi &&& 0xFF, lo >>> 8, lo &&& 0xFF}

  defp in_network?(ip, {network, prefix}) when tuple_size(ip) == tuple_size(network) do
    bits = if tuple_size(ip) == 4, do: 32, else: 128
    shift = bits - prefix
    to_integer(ip) >>> shift == to_integer(network) >>> shift
  end

  defp in_network?(_ip, _network), do: false

  defp to_integer({_, _, _, _} = ip),
    do: ip |> Tuple.to_list() |> Enum.reduce(0, &(&2 <<< 8 ||| &1))

  defp to_integer(ip), do: ip |> Tuple.to_list() |> Enum.reduce(0, &(&2 <<< 16 ||| &1))

  defp parse(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme} = uri} when is_binary(scheme) -> {:ok, uri}
      _ -> {:error, "Invalid URL"}
    end
  end

  defp require_host(%URI{host: host}) when is_binary(host) and host != "", do: :ok
  defp require_host(_uri), do: {:error, "Invalid URL"}

  defp check_scheme(%URI{scheme: scheme}) when scheme in ["http", "https"], do: :ok
  defp check_scheme(_uri), do: {:error, "Forbidden Schema"}

  defp check_host(%URI{host: host}) do
    name = host |> String.downcase() |> String.trim_trailing(".")

    cond do
      name == "localhost" or String.ends_with?(name, ".localhost") ->
        {:error, "Forbidden hostname"}

      ipv4_like?(name) and not Regex.match?(@canonical_ipv4, name) ->
        {:error, "Forbidden IP"}

      true ->
        case ip_literal(host) do
          {:ok, ip} -> if public_address?(ip), do: :ok, else: {:error, "Forbidden IP"}
          :error -> :ok
        end
    end
  end

  # Like the WHATWG URL parser: a host whose last label is a decimal or
  # hexadecimal number is an IPv4 address.
  defp ipv4_like?(name) do
    last = name |> String.split(".") |> List.last()
    Regex.match?(~r/\A([0-9]+|0x[0-9a-f]*)\z/, last)
  end

  defp ip_literal(host) do
    host = host |> String.trim_leading("[") |> String.trim_trailing("]")

    case :inet.parse_strict_address(String.to_charlist(host)) do
      {:ok, ip} -> {:ok, ip}
      {:error, _} -> :error
    end
  end

  defp check_port(%URI{port: port}) when port in [80, 443], do: :ok
  defp check_port(_uri), do: {:error, "Forbidden Port"}
end
