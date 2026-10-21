import Config

config :feather, :scopes,
  user: [
    default: true,
    module: Feather.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: Feather.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :feather,
  ecto_repos: [Feather.Repo],
  generators: [timestamp_type: :utc_datetime_usec, binary_id: true],
  mail_from: {"Feather", "no-reply@feather.page"},
  unsplash_access_key: nil,
  hardcover_token: nil

# SQLite: take the write lock when a transaction starts instead of
# upgrading later (avoids SQLITE_BUSY on upgrade), WAL for concurrent
# readers, and wait a while for the lock instead of failing at once.
config :feather, Feather.Repo,
  default_transaction_mode: :immediate,
  journal_mode: :wal,
  busy_timeout: 5_000

config :feather, FeatherWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FeatherWeb.ErrorHTML, json: FeatherWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Feather.PubSub,
  live_view: [signing_salt: "3Bym1Y4h"]

config :phoenix_live_view,
  root_tag_attribute: "phx-r"

config :setzkasten,
  icons: FeatherWeb.Icons,
  plush: FeatherWeb.Plush,
  translate_error: {FeatherWeb.CoreComponents, :translate_error}

config :feather, Feather.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.25.4",
  feather: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.3.3",
  feather: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Magic link, email confirmation and invitation tokens are path parameters:
# filter them from logged parameters. FeatherWeb.Endpoint.log_level/1 keeps
# them out of the request lines.
config :phoenix, :filter_parameters, ["password", "token", "secret"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
