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
database on start. Set `IMAGE_CLEANUP=false` in `env.clear` for this first deploy if you want
to review the cleanup preview (step 4) at leisure; the cleanup otherwise first runs five minutes
after boot.

## 4. Import

    docker cp ./dump <phoenix container>:/data/dump
    kamal app exec -d production --reuse 'bin/feather eval "Feather.Release.import_dump(\"/data/dump\")"'

The import runs in one transaction and refuses a non-empty database (`force: true` wipes it).
Compare the printed rows with `dump/manifest.json` (`navigations` are merged into the site) and
read every finding: images without files, dangling references, records imported despite a
validation, normalized content, and images the daily cleanup will delete. Then delete the dump,
it holds deployment credentials: `kamal app exec --reuse 'rm -rf /data/dump'` and `rm -rf ./dump`.

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
- After a few quiet days: remove the Rails job containers and Postgres
  (`kamal app remove -r job`, `kamal accessory remove postgres`), keeping the backup from step 1.

Rollback until then: `kamal rollback <rails version> -d production` with the Rails config; Postgres
still holds the frozen data.
