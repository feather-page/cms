defmodule Feather.FakeResolver do
  @moduledoc """
  The DNS resolver of image downloads in tests
  (`config :feather, :image_fetch_resolver`), so tests need no network:

    * `<ip>.nip.io` resolves to `<ip>` (like the real nip.io),
    * `private-and-public.example` resolves to a public and a private address,
    * `unresolvable.example` does not resolve,
    * every other name resolves to the public address 93.184.215.14.
  """

  def resolve("unresolvable.example", _timeout), do: {:error, :nxdomain}

  def resolve("private-and-public.example", _timeout),
    do: {:ok, [{93, 184, 215, 14}, {10, 0, 0, 7}]}

  def resolve(host, _timeout) do
    with true <- String.ends_with?(host, ".nip.io"),
         {:ok, ip} <-
           host
           |> String.trim_trailing(".nip.io")
           |> String.to_charlist()
           |> :inet.parse_address() do
      {:ok, [ip]}
    else
      _ -> {:ok, [{93, 184, 215, 14}]}
    end
  end
end
