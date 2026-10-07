# Cutover from Rails to Phoenix

Runbook for moving app.feather.page from the Rails app (Postgres) to the Phoenix release
(SQLite). Plan an hour; editing is frozen from step 2 until step 8.

## 0. Before the day

- 1Password item `feather.page/Production`: add `CONFIG_ENCRYPTION_KEY`
  (`elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'`) and
  `UNSPLASH_ACCESS_KEY` (`.kamal/secrets` fetches both).
- `config/deploy.production.yml` (not in the repository) holds the host. Check that the host
  directory mounted at `/static` in `config/deploy.yml` is the one Caddy serves and that uid 1000
  can write to it.
- Check that `config/deploy.production.yml` defines **only `servers: web: hosts:`** for the
  Phoenix app, since Kamal merges it over `config/deploy.yml` and replaces arrays and roles
  rather than merging them:
  - no `job` role (or any other role): a second container on the same `feather_data` volume
    would be a second SQLite writer, and it would run the daily cleanup and deploys twice;
  - no `volumes:` list: it would replace the base list and drop `feather_data:/data` (the
    database and images) or `/static:/static`;
  - no `env:` block that replaces `clear`/`secret` (e.g. one left over from Rails): it would
    drop `DATABASE_PATH`, `STORAGE_PATH` or `CONFIG_ENCRYPTION_KEY`.

  Verify the merged result with `kamal config -d production`: one `web` role, both volumes, the
  env of `config/deploy.yml`.
- The Rails app runs a release with the `feather:dump` task (branch `rails-dump-task`).
- The Phoenix image builds (`kamal build push -d production`) and has a `/up` health check route.

## 1. Back up

On the host: `pg_dump` of the Rails database, and a copy of the Rails storage directory
(Active Storage files and `storage/static_site/`, the last static exports).

## 2. Freeze and dump

Tell the editors. Stop the Rails job role so nothing exports or cleans up in between:

    kamal app stop -r job -d production     # with the Rails config checked out
    kamal app exec -d production --reuse -r web 'bin/rails "feather:dump[/rails/storage/dump]"'

The task prints counts and warnings (missing image files, deployment configs). Copy the dump to
the host: `docker cp <rails web container>:/rails/storage/dump ./dump`.

## 3. Deploy Phoenix

    kamal deploy -d production              # with this repository checked out

This replaces the Rails web container; Postgres keeps running. The release migrates the empty
database on start. Do not let editors in yet (step 4 first). The image cleanup runs daily at
03:00 UTC; set `IMAGE_CLEANUP=false` in `env.clear` for this first deploy if the import (step 4)
may not be reviewed before then.

## 4. Import

    docker cp ./dump <phoenix container>:/data/dump
    kamal app exec -d production --reuse 'bin/feather eval "Feather.Release.import_dump(\"/data/dump\")"'

The import runs in one transaction and refuses a non-empty database (`force: true` wipes it).
It holds the SQLite write lock for its whole run, so every write in the app (logins included)
waits or fails with "Database busy" until it is done: run it before anyone uses the app.
Compare the printed rows with `dump/manifest.json` (`navigations` are merged into the site) and
read every finding: images without files, dangling references, records imported despite a
validation, normalized content, and images the daily cleanup will delete. Then delete the dump,
it holds deployment credentials: `kamal app exec --reuse 'rm -rf /data/dump'` and `rm -rf ./dump`.
`docker cp` creates files owned by root: if `rm` in the container fails with "Permission
denied", remove it as root (`docker exec -u root <phoenix container> rm -rf /data/dump`), and
use `sudo rm -rf ./dump` on the host if the copy there is root-owned too.

A deployment target whose config could not be read is imported with an empty config (the
report says "config could not be read"). The admin does not edit credentials; set them from
the console (keys: `fastmail` takes `email`, `password`, `path`; `hetzner_ftps` takes `host`,
`user`, `password`, `path`):

    kamal app exec -d production --reuse 'bin/feather eval "Feather.Release.set_target_config(\"<target public id>\", %{\"email\" => \"...\", \"password\" => \"...\", \"path\" => \"...\"})"'

It calls `Feather.Publishing.update_target_config/3`. The credentials end up in your shell
history; `kamal app exec -i --reuse 'bin/feather remote'` and the same call in the console
avoids that.

## 5. Smoke test

Log in by magic link (checks SMTP), open both sites, a post with images, the book shelf, the
deployment targets (their credentials must show up decrypted), and the preview.

## 6. Staging export and comparison

Deploy both sites to their staging targets from the CMS, then compare with the last Rails
export of the same target (target ids are kept, so the directories match up):

    diff -r <rails storage>/static_site/<target id>/public <feather_data volume>/storage/static_site/<target id>/public

Expect only intended differences (asset fingerprints, whitespace). Check the staging sites
in the browser.

## 7. Switch production

Deploy each site to its production target from the CMS and check the live sites.

## 8. After the switch

- Resend every open invitation from the members page: Rails invitation links no longer work.
- Unfreeze editing.
- After a few quiet days: remove the Rails job containers and Postgres, keeping the backup from
  step 1. Run both **with the Rails config checked out** (this repository's config has neither
  a `job` role nor a `postgres` accessory, so Kamal would not find them):
  `kamal app remove -r job -d production`, `kamal accessory remove postgres -d production`.

Rollback until then: `kamal rollback <rails version> -d production` with the Rails config; Postgres
still holds the frozen data.
