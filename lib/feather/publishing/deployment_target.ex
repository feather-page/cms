defmodule Feather.Publishing.DeploymentTarget do
  @moduledoc """
  An external host a site is deployed to, backed by an rclone provider
  (`hetzner_ftps`). A deploy exports the published versions. The provider
  `config` (credentials) is stored encrypted.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  @providers ~w(hetzner_ftps)

  schema "deployment_targets" do
    field :public_id, :string
    field :provider, :string
    field :public_hostname, :string
    # The default is not dumped at compile time: that would need the key,
    # which a release only reads at runtime.
    field :config, Feather.Encrypted.Map, default: %{}, skip_default_validation: true
    field :deploying, :boolean, default: false
    # When the export of the last successful deploy started.
    field :last_deployed_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site

    timestamps()
  end

  @doc "The valid providers."
  def providers, do: @providers

  @doc false
  def create_changeset(target, attrs) do
    target
    |> cast(attrs, [:provider, :public_hostname, :config])
    |> validate()
    |> Feather.PublicId.put()
  end

  @doc "Changeset for the field a user may edit: the hostname."
  def update_changeset(target, attrs) do
    target
    |> cast(attrs, [:public_hostname])
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
    |> validate_required([:provider, :public_hostname])
    |> validate_inclusion(:provider, @providers)
    |> unsafe_validate_unique(:public_hostname, Feather.Repo)
    |> unique_constraint(:public_hostname)
  end
end
