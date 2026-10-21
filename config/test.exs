import Config

config :feather, Feather.Repo,
  database: Path.expand("../feather_test.db", __DIR__),
  # One connection only. SQLite has a single writer and the sandbox opens its
  # transaction with a deferred BEGIN, so with several pooled connections the
  # next test's connection could try to write while the previous test's
  # connection still held the write lock ("Database busy", flaky). Database
  # tests run synchronously anyway, so one connection costs nothing.
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

config :feather, FeatherWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BIyWjPIGyz+Zx0KrGspKBw6PeIkuikNYcscTtLrKgQ1fo1Zr5wBf6e0KtwqUhgLZ",
  server: false

config :feather,
  # Deploys are not started in tests; Feather.Publishing sends the caller
  # {:deploy_requested, target} instead (tests of deploys pass mode:).
  deploy_mode: :manual,
  base_url: "http://localhost:4002",
  storage_root: Path.expand("../tmp/test_storage", __DIR__),
  backfill_image_variants: false,
  image_variant_sync: :inline,
  alt_text_suggestions: :inline,
  # Deploys tell IndexNow and archive.org nothing unless a test asks for it.
  deploy_notifications: false,
  config_encryption_key: "TNNvQkxC2kCFMB1wciLl7rHKXNTwz4kCIREO7dEvVKA="

config :feather, Feather.Mailer, adapter: Swoosh.Adapters.Test

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true

config :feather, :image_fetch_req_options, plug: {Req.Test, Feather.Media}
config :feather, :image_fetch_resolver, {Feather.FakeResolver, :resolve}

config :feather, Feather.Media.CleanupScheduler, enabled: false
config :feather, Feather.Publishing.ScheduledDeploys, enabled: false

config :feather, :unsplash_req_options, plug: {Req.Test, Feather.Unsplash}
config :feather, :hardcover_req_options, plug: {Req.Test, Feather.Hardcover}
config :feather, :open_library_req_options, plug: {Req.Test, Feather.OpenLibrary}
config :feather, :ollama_req_options, plug: {Req.Test, Feather.Ollama}
config :feather, :indexnow_req_options, plug: {Req.Test, Feather.IndexNow}
config :feather, :archive_org_req_options, plug: {Req.Test, Feather.ArchiveOrg}
