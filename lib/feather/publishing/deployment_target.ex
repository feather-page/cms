defmodule Feather.Publishing.DeploymentTarget do
  @moduledoc """
  A destination a site is published to, typed `staging`, `production` or
  `backup`, backed by an rclone provider (`internal`, `fastmail`,
  `hetzner_ftps`). The provider `config` (credentials) is stored encrypted.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  @types ~w(staging production backup)
  @providers ~w(internal fastmail hetzner_ftps)

  schema "deployment_targets" do
    field :public_id, :string
    field :type, :string
    field :provider, :string
    field :public_hostname, :string
    field :config, Feather.Encrypted.Map, default: %{}
    field :deploying, :boolean, default: false

    belongs_to :site, Feather.Sites.Site

    timestamps()
  end

  @doc "The valid types."
  def types, do: @types

  @doc "The valid providers."
  def providers, do: @providers

  @doc false
  def create_changeset(target, attrs) do
    target
    |> cast(attrs, [:type, :provider, :public_hostname, :config])
    |> validate()
    |> Feather.PublicId.put_new()
  end

  @doc "Changeset for the fields a user may edit: hostname and type."
  def update_changeset(target, attrs) do
    target
    |> cast(attrs, [:type, :public_hostname])
    |> validate()
  end

  @doc "Changeset replacing the provider config."
  def config_changeset(target, config) do
    target
    |> cast(%{config: config}, [:config])
  end

  defp validate(changeset) do
    changeset
    |> update_change(:public_hostname, fn
      hostname when is_binary(hostname) -> hostname |> String.trim() |> String.downcase()
      nil -> nil
    end)
    |> validate_required([:type, :provider, :public_hostname])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:provider, @providers)
    |> unsafe_validate_unique(:public_hostname, Feather.Repo)
    |> unique_constraint(:public_hostname)
  end
end
