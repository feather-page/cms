class DropGoodJobTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :good_jobs, if_exists: true
    drop_table :good_job_executions, if_exists: true
    drop_table :good_job_processes, if_exists: true
    drop_table :good_job_settings, if_exists: true
    drop_table :good_job_batches, if_exists: true
  end
end
