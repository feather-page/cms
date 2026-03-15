class AddDeployingToDeploymentTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :deployment_targets, :deploying, :boolean, default: false, null: false
    add_column :deployment_targets, :lock_version, :integer, default: 0, null: false
  end
end
