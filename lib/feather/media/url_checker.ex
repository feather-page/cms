defmodule Feather.Media.UrlChecker do
  @moduledoc """
  Checks that a URL is safe to fetch from the server (port of Rails'
  `ExternalUrlChecker`): only http and https, no `localhost`, no private,
  loopback or link-local IP addresses and only the ports 80 and 443.

  Host names are not resolved, so a public name pointing at a private
  address is not caught here.
  """

  @doc """
  Returns `{:ok, uri}` for an acceptable URL, `{:error, reason}` otherwise.
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
    host = host |> String.downcase() |> String.trim_trailing(".")

    cond do
      host == "localhost" or String.ends_with?(host, ".localhost") ->
        {:error, "Forbidden hostname"}

      forbidden_ip?(host) ->
        {:error, "Forbidden IP"}

      true ->
        :ok
    end
  end

  defp check_port(%URI{port: port}) when port in [80, 443], do: :ok
  defp check_port(_uri), do: {:error, "Forbidden Port"}

  defp forbidden_ip?(host) do
    host = host |> String.trim_leading("[") |> String.trim_trailing("]")

    case :inet.parse_strict_address(String.to_charlist(host)) do
      {:ok, ip} -> forbidden_address?(ip)
      {:error, _} -> false
    end
  end

  defp forbidden_address?({0, _, _, _}), do: true
  defp forbidden_address?({10, _, _, _}), do: true
  defp forbidden_address?({127, _, _, _}), do: true
  defp forbidden_address?({169, 254, _, _}), do: true
  defp forbidden_address?({172, b, _, _}) when b in 16..31, do: true
  defp forbidden_address?({192, 168, _, _}), do: true
  defp forbidden_address?({100, b, _, _}) when b in 64..127, do: true
  defp forbidden_address?({_, _, _, _}), do: false
  defp forbidden_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp forbidden_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  # IPv4-mapped IPv6 (::ffff:a.b.c.d)
  defp forbidden_address?({0, 0, 0, 0, 0, 0xFFFF, ab, cd}) do
    forbidden_address?({div(ab, 256), rem(ab, 256), div(cd, 256), rem(cd, 256)})
  end

  # Unique local fc00::/7 and link-local fe80::/10
  defp forbidden_address?({a, _, _, _, _, _, _, _}) when a in 0xFC00..0xFDFF, do: true
  defp forbidden_address?({a, _, _, _, _, _, _, _}) when a in 0xFE80..0xFEBF, do: true
  defp forbidden_address?(_ip), do: false
end
