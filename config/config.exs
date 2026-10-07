# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
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
  # Sender of all application emails.
  mail_from: {"Feather", "no-reply@feather.page"},
  # Staging deployment targets get "<site public_id>.stage.<staging_host>".
  staging_host: "localhost:4000",
  # Unsplash is optional; without a key the image search is disabled.
  unsplash_access_key: nil

# SQLite: take the write lock when a transaction starts instead of
# upgrading later (avoids SQLITE_BUSY on upgrade), WAL for concurrent
# readers, and wait a while for the lock instead of failing at once.
config :feather, Feather.Repo,
  default_transaction_mode: :immediate,
  journal_mode: :wal,
  busy_timeout: 5_000

# Configure the endpoint
config :feather, FeatherWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FeatherWeb.ErrorHTML, json: FeatherWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Feather.PubSub,
  live_view: [signing_salt: "3Bym1Y4h"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :feather, Feather.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  feather: [
    args:
      ~w(js/app.js css/app.css --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Magic link, email confirmation and invitation tokens are path parameters:
# filter them from logged parameters. FeatherWeb.Endpoint.log_level/1 keeps
# them out of the request lines.
config :phoenix, :filter_parameters, ["password", "token"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
