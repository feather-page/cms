defmodule Feather.MixProject do
  use Mix.Project

  def project do
    [
      app: :feather,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {Feather.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.15"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      # Formats the static site's pages (DECISIONS.md, 0022)
      {:lazy_html, "~> 0.1.13"},
      {:phoenix_live_dashboard, "~> 0.9.1"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.7.50",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      # Shared admin components, daisyUI themes and patches (DECISIONS.md, 0013)
      {:setzkasten, github: "shostakovich/setzkasten"},
      {:swoosh, "~> 1.16"},
      {:gen_smtp, "~> 1.2"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:floki, "~> 0.38"},
      {:vix, "~> 0.35"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      # npm packages (ProseMirror) from assets/package-lock.json
      "assets.npm": ["cmd --cd assets npm ci --no-audit --no-fund"],
      "assets.build": ["compile", "assets.npm", "tailwind feather", "esbuild feather"],
      "assets.deploy": [
        # app.js imports phoenix-colocated/feather, which only compiling writes
        "compile",
        "assets.npm",
        "tailwind feather --minify",
        "esbuild feather --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --strict",
        "test"
      ]
    ]
  end
end
