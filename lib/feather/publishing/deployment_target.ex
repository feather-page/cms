defmodule Feather.Publishing.DeploymentTarget do
  @moduledoc """
  The account a site is deployed to, through an rclone provider (`ftps`).
  A site has at most one; its address is the site's `domain`. The provider
  `config` (credentials) is stored encrypted.
  """
  use Feather.Schema

  alias Feather.Publishing.Rclone

  @type t :: %__MODULE__{}

  schema "deployment_targets" do
    field :public_id, :string
    field :provider, :string
    # No default dump at compile time: that needs the key, which a release reads at runtime.
    field :config, Feather.Encrypted.Map, default: %{}, skip_default_validation: true
    field :deploying, :boolean, default: false
    # When the export of the last successful deploy started.
    field :last_deployed_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site

    timestamps()
  end

  @doc false
  def create_changeset(target, attrs) do
    target
    |> cast(attrs, [:provider, :config])
    |> validate_required([:provider])
    |> validate_inclusion(:provider, Rclone.provider_names())
    |> unique_constraint(:site_id, message: "already has a deployment target")
    |> Feather.PublicId.put()
  end

  @doc "Changeset replacing the provider config."
  def config_changeset(target, config) do
    cast(target, %{config: config}, [:config])
  end
end
