defmodule Feather.Fediverse.RemoteAccount do
  @moduledoc """
  An account on another fediverse server, as its actor document said when
  it was last fetched (`Feather.Fediverse.RemoteAccounts`): its key, name,
  handle, picture, inboxes and the address of its followers collection,
  and the server it is on (`host/1` of its address).
  The handle is set only when WebFinger leads back to the actor.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_remote_accounts" do
    field :uri, :string
    field :host, :string
    field :key_id, :string
    field :public_key, :string
    field :name, :string
    field :handle, :string
    field :picture_url, :string
    field :inbox, :string
    field :shared_inbox, :string
    field :followers_url, :string
    field :fetched_at, :utc_datetime_usec

    timestamps()
  end

  @https_fields [:uri, :key_id, :picture_url, :inbox, :shared_inbox, :followers_url]

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :uri,
      :key_id,
      :public_key,
      :name,
      :handle,
      :picture_url,
      :inbox,
      :shared_inbox,
      :followers_url,
      :fetched_at
    ])
    |> validate_required([:uri, :key_id, :public_key, :inbox, :fetched_at])
    |> validate_https(@https_fields)
    |> put_host()
    |> unique_constraint(:uri)
  end

  defp put_host(changeset) do
    uri = get_change(changeset, :uri)
    if https_url?(uri), do: put_change(changeset, :host, host(uri)), else: changeset
  end

  @doc "Validates that the changes of the `fields` are https addresses (`https_url?/1`)."
  @spec validate_https(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  def validate_https(changeset, fields),
    do: Enum.reduce(fields, changeset, &validate_https_url/2)

  defp validate_https_url(field, changeset) do
    validate_change(changeset, field, fn ^field, url ->
      if https_url?(url), do: [], else: [{field, "must be an https address"}]
    end)
  end

  @doc "Returns true for an absolute https URL with a host."
  @spec https_url?(term()) :: boolean()
  def https_url?(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: "https", host: host}} when is_binary(host) and host != "" -> true
      _other -> false
    end
  end

  def https_url?(_url), do: false

  @doc """
  Returns true if both addresses (strings or `URI`s) have a host and the
  same origin: scheme, host in any case and port.
  """
  @spec same_origin?(String.t() | URI.t(), String.t() | URI.t()) :: boolean()
  def same_origin?(a, b) do
    origin = origin(a)
    not is_nil(origin) and origin == origin(b)
  end

  defp origin(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, port: port} when is_binary(host) and host != "" ->
        {scheme, String.downcase(host), port}

      _no_origin ->
        nil
    end
  end

  @doc "The server of an address (string or `URI`): its host in lower case, without a trailing dot."
  @spec host(String.t() | URI.t()) :: String.t()
  def host(uri),
    do: uri |> URI.parse() |> Map.fetch!(:host) |> String.downcase() |> String.trim_trailing(".")
end
