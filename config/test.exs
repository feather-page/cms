import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :feather, Feather.Repo,
  database: Path.expand("../feather_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
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
  staging_sites_path: Path.expand("../tmp/test_storage/staging_sites", __DIR__),
  # 32 random bytes, base64. Only for tests.
  config_encryption_key: "TNNvQkxC2kCFMB1wciLl7rHKXNTwz4kCIREO7dEvVKA="

# In test we don't send emails
config :feather, Feather.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Image downloads go through Req.Test stubs named Feather.Media.
config :feather, :image_fetch_req_options, plug: {Req.Test, Feather.Media}
