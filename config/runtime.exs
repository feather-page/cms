import Config

if System.get_env("PHX_SERVER") do
  config :feather, FeatherWeb.Endpoint, server: true
end

config :feather, FeatherWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Tests never read the environment.
if config_env() != :test do
  if unsplash_access_key = System.get_env("UNSPLASH_ACCESS_KEY") do
    config :feather, :unsplash_access_key, unsplash_access_key
  end

  if hardcover_token = System.get_env("HARDCOVER_TOKEN") do
    config :feather, :hardcover_token, hardcover_token
  end

  if ollama_url = System.get_env("OLLAMA_URL") do
    config :feather, :ollama_url, ollama_url
  end

  if ollama_model = System.get_env("OLLAMA_MODEL") do
    config :feather, :ollama_model, ollama_model
  end

  case System.get_env("FEDIVERSE_PROXY", "") do
    "" ->
      :ok

    fediverse_proxy ->
      case URI.new(fediverse_proxy) do
        {:ok, %URI{scheme: scheme, host: host, port: port}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          config :feather,
                 :fediverse_proxy,
                 {if(scheme == "https", do: :https, else: :http), host, port}

        _invalid ->
          raise """
          environment variable FEDIVERSE_PROXY must be the URL of an HTTP proxy,
          for example: http://proxy:3128
          """
      end
  end

  if System.get_env("IMAGE_CLEANUP") == "false" do
    config :feather, Feather.Media.CleanupScheduler, enabled: false
  end
end

if config_env() == :dev do
  config :feather, FeatherWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        ~r"priv/gettext/.*\.po$"E,
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
    config_encryption_key: config_encryption_key

  config :feather, FeatherWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
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
