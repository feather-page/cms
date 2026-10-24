defmodule Feather.Fediverse.SigningKey do
  @moduledoc """
  The key a site's account signs its requests to fediverse servers with:
  HTTP signatures (draft-cavage-http-signatures-12, as Mastodon verifies
  them) over `(request-target)`, `host`, `date` and, for a request with a
  body, `digest` (SHA-256 of the body), as `rsa-sha256`.

  Inspecting a key shows only its id.
  """

  alias Feather.Fediverse
  alias Feather.Sites.Site

  @enforce_keys [:key_id, :private_key]
  @derive {Inspect, only: [:key_id]}
  defstruct [:key_id, :private_key]

  @type t :: %__MODULE__{key_id: String.t(), private_key: tuple()}

  @doc """
  The signing key of a site with a fediverse name, under its account's key
  id: its current key, not one pending until a deploy publishes it
  (`Feather.Fediverse.rotate_key/1`).
  """
  @spec for_site(Site.t()) :: t()
  def for_site(%Site{} = site) do
    [entry] = site |> Fediverse.private_key() |> :public_key.pem_decode()

    %__MODULE__{
      key_id: Fediverse.account_url(site) <> "#main-key",
      private_key: :public_key.pem_entry_decode(entry)
    }
  end

  @doc """
  The headers that sign a request: `host`, `date`, `digest` with a body,
  and `signature`.
  """
  @spec sign(t(), :get | :post, URI.t(), binary() | nil, DateTime.t()) :: [
          {String.t(), String.t()}
        ]
  def sign(%__MODULE__{} = key, method, %URI{} = uri, body, now \\ DateTime.utc_now()) do
    headers = [{"host", uri.host}, {"date", http_date(now)}] ++ digest(body)
    signed = [{"(request-target)", request_target(method, uri)} | headers]

    signature =
      signed
      |> signing_string()
      |> :public_key.sign(:sha256, key.private_key)
      |> Base.encode64()

    names = Enum.map_join(signed, " ", &elem(&1, 0))

    [
      {"signature",
       ~s(keyId="#{key.key_id}",algorithm="rsa-sha256",headers="#{names}",signature="#{signature}")}
      | headers
    ]
  end

  @doc "The string a signature signs: one `name: value` line per signed header."
  @spec signing_string([{String.t(), String.t()}]) :: String.t()
  def signing_string(headers),
    do: Enum.map_join(headers, "\n", fn {name, value} -> name <> ": " <> value end)

  defp request_target(method, %URI{path: path, query: query}) do
    path = if path in [nil, ""], do: "/", else: path
    target = if query, do: path <> "?" <> query, else: path
    to_string(method) <> " " <> target
  end

  defp http_date(now), do: Calendar.strftime(now, "%a, %d %b %Y %H:%M:%S GMT")

  defp digest(nil), do: []
  defp digest(body), do: [{"digest", "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, body))}]
end
