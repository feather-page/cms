# Serial Deployment: Race Condition Fix

## Problem

When a user clicks "Deploy" twice in quick succession on a large site, two `StaticSite::ExportJob` instances run concurrently on separate Solid Queue threads. The second job's `cleanup` (`FileUtils.rm_rf`) deletes files the first job is still writing, causing incomplete or broken deployments.

There is no locking, status tracking, or job deduplication in the current implementation.

## Solution

Add a `deploying` boolean flag with optimistic locking to `DeploymentTarget`. The `ExportJob` acquires the lock before starting; if already locked, it reschedules itself. The Rclone sync is inlined into the ExportJob so the lock covers the entire build-and-deploy pipeline.

## Changes

### 1. Migration

Add two columns to `deployment_targets`:

- `deploying` — `boolean`, default: `false`, null: `false`
- `lock_version` — `integer`, default: `0`, null: `false` (enables Rails optimistic locking)

### 2. DeploymentTarget model

Add two methods:

```ruby
def acquire_deploy_lock!
  reload
  return false if deploying?

  update!(deploying: true)
  true
rescue ActiveRecord::StaleObjectError
  false
end

def release_deploy_lock!
  self.class.where(id: id).update_all(deploying: false, lock_version: 0)
end
```

- `acquire_deploy_lock!` reloads to get fresh state, checks `deploying`, and atomically sets it to `true`. If another thread won the race (StaleObjectError from optimistic locking), returns `false`.
- `release_deploy_lock!` uses `update_all` via a class-level WHERE query to truly bypass optimistic locking. Note: `update_columns` still includes `lock_version` in the WHERE clause for models with optimistic locking, so it would fail on stale objects. `update_all` only uses the primary key. Resets `lock_version` to avoid unbounded growth.

### 3. StaticSite::ExportJob

Restructure `perform` to acquire the lock, do all work (including rclone sync and notification), and release in `ensure`:

```ruby
def perform(deployment_target)
  @deployment_target = deployment_target
  @lock_acquired = false

  unless deployment_target.acquire_deploy_lock!
    return retry_job(wait: 5.seconds) if executions < 60
    Rails.logger.warn("Deploy lock for target #{deployment_target.id} stuck — giving up after 60 retries")
    return
  end

  @lock_acquired = true
  @site = deployment_target.site

  cleanup
  export_content
  precompress
  deploy_and_notify
ensure
  deployment_target.release_deploy_lock! if @lock_acquired
end
```

The `deploy` method changes from `Rclone::DeployJob.perform_later` to inline execution. `perform` accepts optional DI keyword arguments (matching the existing pattern in `Rclone::DeployJob`) for testability:

```ruby
def perform(deployment_target, deployer: Rclone::Deployer, noticer: Noticer)
  # ...
end

def deploy_and_notify
  @deployer.deploy(deployment_target)
  @noticer.new(site).notice(
    "Site built. <a href='https://#{deployment_target.public_hostname}'>Preview</a>"
  )
end
```

### 4. Rclone::DeployJob

Becomes unused. Delete the file `app/jobs/rclone/deploy_job.rb` and its spec (if any).

## What does NOT change

- `DeploymentTargetsController#deploy` — unchanged
- UI / Turbo behavior — unchanged
- `Rclone::Deployer` — unchanged
- `PrecompressJob` — unchanged (already runs inline via `perform_now`)
- `config/queue.yml` — unchanged

## Behavior

| Scenario | Result |
|----------|--------|
| Single deploy click | Lock acquired, build + sync runs, lock released |
| Double click (second while first runs) | Second job retries every 5s until first finishes, then runs |
| Job crashes mid-build | `ensure` releases lock, next retry starts clean |
| Three rapid clicks | Jobs serialize — each waits for the previous one |
| Retry limit exceeded (stuck lock) | Job logs warning and gives up after 60 retries (~5 min) |
| Process killed (SIGKILL / crash) | Lock stays stuck — operator resets via `DeploymentTarget.find(id).release_deploy_lock!` in Rails console. Retry cap (60) prevents infinite loops for waiting jobs. |

## Testing

- Unit test `acquire_deploy_lock!` / `release_deploy_lock!` on DeploymentTarget
- Test ExportJob retries when lock is held (mock `acquire_deploy_lock!` to return `false`)
- Test ExportJob releases lock in ensure (mock to raise during export, verify lock released)
- Test that `deploy_and_notify` calls Deployer and Noticer
- Remove or update Rclone::DeployJob specs
