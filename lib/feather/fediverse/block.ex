defmodule Feather.Fediverse.Block do
  @moduledoc """
  An account or a whole server that a site's members blocked
  (`Feather.Fediverse.Blocks`): an account by the address of its actor,
  with its handle as it was then, or a server by its host, in lower case
  and without a trailing dot, which covers its subdomains too.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_blocks" do
    field :account_uri, :string
    field :handle, :string
    field :host, :string

    belongs_to :site, Feather.Sites.Site

    timestamps()
  end

  @doc "Returns true if the block is of a whole server."
  @spec server?(t()) :: boolean()
  def server?(%__MODULE__{account_uri: account_uri}), do: is_nil(account_uri)

  @doc "What is blocked: the account's handle, or its address without one, or the server's host."
  @spec name(t()) :: String.t()
  def name(%__MODULE__{account_uri: nil, host: host}), do: host
  def name(%__MODULE__{handle: nil, account_uri: account_uri}), do: account_uri
  def name(%__MODULE__{handle: handle}), do: handle
end
