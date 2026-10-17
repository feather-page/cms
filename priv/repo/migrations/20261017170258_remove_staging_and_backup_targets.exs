defmodule Feather.Repo.Migrations.RemoveStagingAndBackupTargets do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM deployment_targets
    WHERE type IN ('staging', 'backup') OR provider IN ('internal', 'fastmail')
    """

    alter table(:deployment_targets) do
      remove :type
    end
  end

  def down do
    alter table(:deployment_targets) do
      add :type, :string, null: false, default: "production"
    end
  end
end
