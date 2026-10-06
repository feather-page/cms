# Feather-Page CMS

[![CI](https://github.com/feather-page/cms/actions/workflows/ci.yml/badge.svg)](https://github.com/feather-page/cms/actions/workflows/ci.yml)

Feather-Page CMS is a web interface for managing small static websites. It is a Phoenix
application (LiveView admin, SQLite) that renders sites to static HTML and deploys them to the
site owner's own hosting.

## Design Goals

*   A simple interface that can be used by non-technical users.
*   Website should look like a real web-developer hand-coded them.
*   Deployed websites should be static.
*   Deployed websites should NOT load any external resources.
*   Deployed websites should be as small as possible.
*   Deployed websites should be SEO friendly.
*   Deployed websites are on domains that belong to the user.

## Development

### Requirements

*   Erlang/OTP 28 and Elixir 1.19
*   `rclone` for deployments
*   `brotli` (optional) to precompress exported sites as `.br`; without it only `.gz` is written
*   No system libvips needed: `vix` downloads a precompiled libvips on first compile

### Setup

```bash
mix setup          # deps, database (SQLite file feather_dev.db), seeds, assets
mix phx.server     # http://localhost:4000
```

The seeds create the super admin `admin@example.com` and a demo site. There are no passwords:
enter the email on the login page and open the magic link from the dev mailbox at
<http://localhost:4000/dev/mailbox>.

Uploaded images are stored in `storage/` (git-ignored).

### Mix tasks

| Task | Purpose |
|------|---------|
| `mix feather.create_user EMAIL [--super-admin]` | Create (or update) a user who can log in by magic link |
| `mix feather.api_token EMAIL [NAME]` | Create an API token for a user; it is printed once |
| `mix feather.import DIR [--force]` | One-time import of a Rails dump, see `docs/cutover.md` |
| `mix test` | Run the test suite |
| `mix precommit` | Compile with warnings as errors, format, run the tests |
| `mix ecto.reset` | Drop, migrate and seed the development database |

In a release the same is available through `bin/feather eval`, see `Feather.Release`
(`migrate/0`, `create_user/2`, `create_api_token/2`, `import_dump/2`). `bin/server` migrates and starts the app.

### Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PHX_HOST` | Public host name of the CMS (prod) | `example.com` |
| `PORT` | HTTP port | `4000` |
| `SECRET_KEY_BASE` | Signs cookies and tokens (prod, required) | |
| `DATABASE_PATH` | SQLite database file (prod, required) | |
| `POOL_SIZE` | Database connections (prod) | `5` |
| `STORAGE_PATH` | Images and build output (prod, required) | dev: `storage/` |
| `CONFIG_ENCRYPTION_KEY` | 32 random bytes, base64; encrypts deployment credentials (prod, required) | fixed dev/test keys |
| `BASE_HOSTNAME_AND_PORT` | Base domain for staging hosts (`<site>.stage.<this>`) | `localhost:4000` |
| `STAGING_SITES_PATH` | Where staging sites are written | `<storage>/staging_sites` |
| `UNSPLASH_ACCESS_KEY` | Unsplash API key (optional) | |
| `IMAGE_CLEANUP` | `false` disables the daily deletion of orphaned images | enabled |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Outgoing mail (prod) | `localhost`, `587` |

Generate a `CONFIG_ENCRYPTION_KEY` with
`elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'`.

## Project structure

*   `lib/feather/`: contexts with the domain logic (`Accounts`, `Sites`, `Content`, `Books`,
    `Media`, `Publishing`)
*   `lib/feather_web/`: the LiveView admin, styled with [felt-css](https://felt-css.rocu.de)
*   `priv/static_site/`: assets of the generated static sites
*   `docs/api/openapi.yml`: the content API
*   `CONTEXT.md`, `docs/adr/`: domain language and architecture decisions

## License

TODO: Add license information.
