# Cutover from Rails to Phoenix

Runbook for moving app.feather.page from the Rails app (Postgres) to the Phoenix release
(SQLite). Both run on the home server (`root@192.168.8.100`) as the compose project in
`/web/config/featherpage`; Pangolin (newt) proxies app.feather.page to the `featherpage` service.

Rails today: services `featherpage` (Rails, port 80), `job` (Solid Queue), `postgres` and
`featherpage_caddy` (staging sites from `/web/data/featherpage/caddy/static`), secrets in
`stack.env`, Rails storage in `/web/data/featherpage/rails/storage` (its last exports in
`hugo/<target id>/public`; the running image predates the rename to `static_site`). Phoenix keeps
`featherpage_caddy` and the static directory, and replaces the other three with one container
(`ops/compose.yml`).

The dump holds deployment credentials in plain text: keep it out of `/web` (restic backs that up
at 03:01) and delete every copy after the import.

## 0. Before the day

- 1Password item `feather.page/Production`: add `CONFIG_ENCRYPTION_KEY`
  (`elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'`) and a new
  `SECRET_KEY_BASE` (`mix phx.gen.secret`). Without a valid key the app does not start;
  changing it later makes the stored deployment credentials unreadable.
- GitHub: the package `ghcr.io/feather-page/cms` must give the repository's Actions write
  access (package settings, "Manage Actions access"), or the `image` job of the CI fails.
- Pangolin: note the target of the app.feather.page resource. Phoenix listens on 4000, not 80.
- Run the rehearsal (A) against a fresh dump.

## A. Rehearsal (local, no freeze)

1. Dump on the server. The task (branch `rails-dump-task`) is copied into the running Rails
   container; it only reads.

       git archive origin/rails-dump-task lib/feather_dump.rb lib/feather_dump lib/tasks/dump.rake \
         | ssh root@192.168.8.100 'rm -rf /root/feather-dump-task && mkdir -p /root/feather-dump-task && tar -x -C /root/feather-dump-task'
       ssh root@192.168.8.100 'docker cp /root/feather-dump-task/lib/. featherpage-featherpage-1:/rails/lib/ \
         && docker exec featherpage-featherpage-1 bin/rails "feather:dump[/tmp/dump]" \
         && rm -rf /root/feather-dump && docker cp featherpage-featherpage-1:/tmp/dump /root/feather-dump \
         && docker exec featherpage-featherpage-1 rm -rf /tmp/dump'

   Read the printed counts and warnings (missing image files, deployment configs). Copy the
   dump and the last Rails exports to the Mac, then delete the dump on the server:

       mkdir -m 700 -p tmp/cutover
       scp -r root@192.168.8.100:/root/feather-dump tmp/cutover/dump
       rsync -a root@192.168.8.100:/web/data/featherpage/rails/storage/hugo/ tmp/cutover/rails_exports/
       ssh root@192.168.8.100 'rm -rf /root/feather-dump'

2. Import into a fresh development database: `mix ecto.reset` and
   `mix feather.import tmp/cutover/dump --force`. Compare the printed rows with
   `tmp/cutover/dump/manifest.json` (`navigations` are merged into the site) and read every
   finding.
3. `mix phx.server`, log in as an imported user (magic link from
   <http://localhost:4000/dev/mailbox>), open both sites, a post with images, the book shelf, the
   deployment targets and the preview. **Deploy only staging targets**: the production targets
   hold the real credentials and would publish the rehearsal to the live sites.
4. Deploy both sites to their staging targets and compare with the Rails export (target ids are
   kept, so the directories match up):

       diff -r tmp/cutover/rails_exports/<target id>/public storage/static_site/<target id>/public

   Expect only intended differences (asset fingerprints, whitespace).
5. `rm -rf tmp/cutover` and `mix ecto.reset`.

## B. Cutover

Plan an hour; editing is frozen from step 1 until step 9. All commands run on the server in
`/web/config/featherpage` unless they say otherwise.

### 1. Freeze and dump

Tell the editors. Stop the job container so nothing exports or cleans up in between, then dump
as in A.1 (the dump lands in `/root/feather-dump`):

    docker compose stop job

### 2. Stop Rails and back up

    docker compose stop featherpage
    docker compose exec postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > /root/featherpage-rails-final.sql
    tar -C /web/data/featherpage -czf /root/featherpage-rails-storage.tgz rails/storage
    docker image tag ghcr.io/feather-page/cms:latest featherpage:rails-final
    cp compose.yml compose.rails.yml && cp stack.env stack.rails.env

In `compose.rails.yml` set `image: featherpage:rails-final` for `featherpage` and `job` and add
the label `com.centurylinklabs.watchtower.enable: "false"` to both, so a rollback does not pull
the Phoenix image. Watchtower ignores stopped containers, so the stopped Rails containers are
safe from now on.

### 3. Publish the Phoenix image

Merge PR #379 into `main` and wait for the CI's `image` job: it pushes
`ghcr.io/feather-page/cms:latest` and `:sha-<commit>`.

### 4. Start Phoenix

    mkdir -p /web/data/featherpage/phoenix && chown 1000:1000 /web/data/featherpage/phoenix

Replace `compose.yml` with `ops/compose.yml` and `stack.env` with the keys of
`ops/stack.env.example`, values from 1Password. Add `IMAGE_CLEANUP=false` to `stack.env` until
the import is reviewed (the cleanup runs daily at 03:00 UTC). Then:

    docker compose pull featherpage
    docker compose up -d featherpage featherpage_caddy

`job` and `postgres` are orphans of the project now; leave them until step 10. The container
migrates the empty database on start and turns healthy once `/up` answers. In Pangolin, point
the app.feather.page target at `featherpage:4000`. Do not let editors in yet.

### 5. Import

    docker cp /root/feather-dump featherpage-featherpage-1:/tmp/dump
    docker compose exec -u root featherpage chown -R feather:feather /tmp/dump
    docker compose exec featherpage bin/feather eval 'Feather.Release.import_dump("/tmp/dump")'
    docker compose exec featherpage rm -rf /tmp/dump && rm -rf /root/feather-dump /root/feather-dump-task

The import runs in one transaction and refuses a non-empty database (`force: true` wipes it).
It holds the SQLite write lock for its whole run, so every write in the app waits or fails with
"Database busy" until it is done. Compare the printed rows with the counts of step 1 and read
every finding: images without files, dangling references, records imported despite a
validation, normalized content, and images the daily cleanup will delete.

A deployment target whose config could not be read is imported with an empty config (the
report says "config could not be read"). The admin does not edit credentials; set them in a
remote console, so they stay out of the shell history (keys: `fastmail` takes `email`,
`password`, `path`; `hetzner_ftps` takes `host`, `user`, `password`, `path`):

    docker compose exec featherpage bin/feather remote
    Feather.Release.set_target_config("<target public id>", %{"email" => "...", "password" => "...", "path" => "..."})

### 6. Smoke test

Through https://app.feather.page: log in by magic link (checks SMTP and that `X-Forwarded-Proto`
arrives, no redirect loop), check that LiveView connects, open both sites, a post with images, the
book shelf, the deployment targets (their credentials must show up decrypted) and the preview.

### 7. Staging export and comparison

Deploy both sites to their staging targets from the CMS and compare with the last Rails export:

    diff -r /web/data/featherpage/rails/storage/hugo/<target id>/public /web/data/featherpage/phoenix/storage/static_site/<target id>/public

Check the staging sites in the browser.

### 8. Switch production

Deploy each site to its production target from the CMS and check the live sites.

### 9. After the switch

- Resend every open invitation from the members page: Rails invitation links no longer work.
- Unfreeze editing. Remove `IMAGE_CLEANUP=false` from `stack.env`, `docker compose up -d featherpage`.
- `/usr/local/bin/file-backup`: replace the `pg_dump` of `featherpage-postgres-1` with a
  consistent copy of the SQLite database before restic runs, e.g.
  `docker exec featherpage-featherpage-1 sqlite3 /data/feather.db ".backup /data/feather-backup.db"`.

### 10. After a few quiet days

    docker compose up -d --remove-orphans
    rm compose.rails.yml stack.rails.env && docker image rm featherpage:rails-final

Then delete `/web/data/featherpage/postgres` and `/web/data/featherpage/rails`, keeping
`/root/featherpage-rails-final.sql` and `/root/featherpage-rails-storage.tgz`.

## Rollback (until step 10)

    docker compose stop featherpage
    cp compose.rails.yml compose.yml && cp stack.rails.env stack.env
    docker compose up -d

Point the Pangolin target back at `featherpage:80`. Postgres still holds the frozen data; edits
made in Phoenix since the switch are lost.
