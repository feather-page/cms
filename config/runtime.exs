import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/feather start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :feather, FeatherWeb.Endpoint, server: true
end

config :feather, FeatherWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Settings read from the environment in dev and prod. Defaults live in
# config/config.exs and config/dev.exs; tests never read the environment.
if config_env() != :test do
  if staging_host = System.get_env("BASE_HOSTNAME_AND_PORT") do
    config :feather, :staging_host, staging_host
  end

  if staging_sites_path = System.get_env("STAGING_SITES_PATH") do
    config :feather, :staging_sites_path, staging_sites_path
  end

  if unsplash_access_key = System.get_env("UNSPLASH_ACCESS_KEY") do
    config :feather, :unsplash_access_key, unsplash_access_key
  end

  if System.get_env("IMAGE_CLEANUP") == "false" do
    config :feather, Feather.Media.CleanupScheduler, enabled: false
  end
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :feather, FeatherWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/feather_web/router\.ex$"E,
        ~r"lib/feather_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/feather.db
      """

  config :feather, Feather.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  storage_root =
    System.get_env("STORAGE_PATH") ||
      raise """
      environment variable STORAGE_PATH is missing.
      It holds uploaded images and build output, for example: /data/storage
      """

  config_encryption_key =
    System.get_env("CONFIG_ENCRYPTION_KEY") ||
      raise """
      environment variable CONFIG_ENCRYPTION_KEY is missing.
      It encrypts deployment target credentials. Generate one with:
      elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'
      """

  case Base.decode64(config_encryption_key) do
    {:ok, <<_key::binary-size(32)>>} ->
      :ok

    _ ->
      raise """
      environment variable CONFIG_ENCRYPTION_KEY must be 32 bytes encoded as base64.
      Generate one with:
      elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'
      Changing the key makes the stored deployment target credentials unreadable.
      """
  end

  host = System.get_env("PHX_HOST") || "example.com"

  config :feather,
    base_url: "https://#{host}",
    storage_root: storage_root,
    staging_sites_path:
      System.get_env("STAGING_SITES_PATH") || Path.join(storage_root, "staging_sites"),
    config_encryption_key: config_encryption_key

  config :feather, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :feather, FeatherWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  smtp_relay = System.get_env("SMTP_ADDRESS", "localhost")

  config :feather, Feather.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_relay,
    port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    auth: :if_available,
    tls: :if_available,
    tls_options: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_relay),
      depth: 99,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ],
    retries: 2

  # TLS is terminated by the reverse proxy in front of the app (see ops/).
end
