defmodule Feather.Repo.Migrations.AddLastDeployedAtToDeploymentTargets do
  use Ecto.Migration

  def up do
    alter table(:deployment_targets) do
      add :last_deployed_at, :utc_datetime_usec
    end

    # No deploy was recorded before. Every deploy attempt bumps `updated_at`
    # when it releases the lock, so it is the best estimate there is.
    execute "UPDATE deployment_targets SET last_deployed_at = updated_at"
  end

  def down do
    alter table(:deployment_targets) do
      remove :last_deployed_at
    end
  end
end
