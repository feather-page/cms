defmodule Feather.Repo.Migrations.OneDeploymentTargetPerSite do
  use Ecto.Migration

  def up do
    drop index(:deployment_targets, [:site_id])
    create unique_index(:deployment_targets, [:site_id])

    drop unique_index(:deployment_targets, [:public_hostname])

    alter table(:deployment_targets) do
      remove :public_hostname
    end

    execute "UPDATE deployment_targets SET provider = 'ftps' WHERE provider = 'hetzner_ftps'"
  end

  def down do
    execute "UPDATE deployment_targets SET provider = 'hetzner_ftps' WHERE provider = 'ftps'"

    alter table(:deployment_targets) do
      add :public_hostname, :string
    end

    execute """
    UPDATE deployment_targets
    SET public_hostname = (SELECT domain FROM sites WHERE sites.id = deployment_targets.site_id)
    """

    create unique_index(:deployment_targets, [:public_hostname])

    drop unique_index(:deployment_targets, [:site_id])
    create index(:deployment_targets, [:site_id])
  end
end
