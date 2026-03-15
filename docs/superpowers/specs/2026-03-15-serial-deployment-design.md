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
  update_column(:deploying, false)
  update_column(:lock_version, 0)
end
```

- `acquire_deploy_lock!` reloads to get fresh state, checks `deploying`, and atomically sets it to `true`. If another thread won the race (StaleObjectError from optimistic locking), returns `false`.
- `release_deploy_lock!` uses `update_column` to bypass optimistic locking and callbacks — it must always succeed, even from an `ensure` block with stale state. Resets `lock_version` to avoid unbounded growth.

### 3. StaticSite::ExportJob

Restructure `perform` to acquire the lock, do all work (including rclone sync and notification), and release in `ensure`:

```ruby
def perform(deployment_target)
  @deployment_target = deployment_target

  unless deployment_target.acquire_deploy_lock!
    return retry_job(wait: 5.seconds)
  end

  @site = deployment_target.site

  cleanup
  export_content
  precompress
  deploy_and_notify
ensure
  deployment_target.release_deploy_lock! if deployment_target.deploying?
end
```

The `deploy` method changes from `Rclone::DeployJob.perform_later` to inline execution:

```ruby
def deploy_and_notify
  Rclone::Deployer.deploy(deployment_target)
  Noticer.new(site).notice(
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

## Testing

- Unit test `acquire_deploy_lock!` / `release_deploy_lock!` on DeploymentTarget
- Test ExportJob retries when lock is held (mock `acquire_deploy_lock!` to return `false`)
- Test ExportJob releases lock in ensure (mock to raise during export, verify lock released)
- Test that `deploy_and_notify` calls Deployer and Noticer
- Remove or update Rclone::DeployJob specs
