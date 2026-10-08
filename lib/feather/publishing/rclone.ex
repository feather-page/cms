defmodule Feather.Publishing.Rclone do
  @moduledoc """
  Syncs an exported site to a deployment target with `rclone`.

  The target's provider (`Feather.Publishing.Rclone.Provider`) supplies an
  rclone config and the remote path. The config is written to a private
  temporary file (passwords obscured with `rclone obscure -`, which reads
  them from standard input so they never appear in a process list), used
  for `rclone sync --config <file> <source> <remote>` and deleted
  afterwards.

  A sync that runs longer than 30 minutes is killed, so a hanging transfer
  cannot hold the target's deploy lock forever
  (`config :feather, :rclone_sync_timeout`, milliseconds).

  Commands go through a runner (`Feather.Publishing.Rclone.Runner`): a
  module or a function taking the argument list and the options. Tests
  pass a fake one; the default is `config :feather, :rclone_runner` or
  `Feather.Publishing.Rclone.SystemRunner`.
  """

  require Logger

  alias Feather.Publishing.DeploymentTarget
  alias Feather.Publishing.Rclone.{Fastmail, HetznerFtps, Internal, SystemRunner}

  @providers %{
    "internal" => Internal,
    "fastmail" => Fastmail,
    "hetzner_ftps" => HetznerFtps
  }

  @default_sync_timeout :timer.minutes(30)
  @obscure_timeout :timer.seconds(30)

  @type runner ::
          module() | ([String.t()], keyword() -> {:ok, String.t()} | {:error, String.t()})

  @doc "The provider module of a provider name, or nil."
  @spec provider(String.t()) :: module() | nil
  def provider(name), do: Map.get(@providers, name)

  @doc """
  Syncs `source_dir` to the target.

  ## Options

    * `:runner` - the command runner (default: see the module doc)
    * `:staging_sites_path` - where the `internal` provider writes
      (default: `config :feather, :staging_sites_path`)
    * `:sync_timeout` - milliseconds (default: `config :feather,
      :rclone_sync_timeout`, or 30 minutes)
  """
  @spec deploy(DeploymentTarget.t(), Path.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def deploy(%DeploymentTarget{} = target, source_dir, opts \\ []) do
    runner = Keyword.get_lazy(opts, :runner, &default_runner/0)

    with {:ok, provider} <- fetch_provider(target),
         {:ok, remote} <- provider.remote(target, opts),
         {:ok, config} <- provider.config(target, &obscure(runner, &1)) do
      with_config_file(config, fn path ->
        run(runner, ["sync", "--config", path, source_dir, remote], timeout: sync_timeout(opts))
      end)
    end
  end

  @doc """
  Obscures a password the way rclone config files expect it. The password
  goes to `rclone obscure -` on standard input, which reads its first
  line: a password with a line break is refused.
  """
  @spec obscure(runner(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def obscure(runner, password) do
    if String.contains?(password, ["\n", "\r"]) do
      {:error, "passwords with line breaks are not supported"}
    else
      with {:ok, output} <-
             run(runner, ["obscure", "-"], input: password <> "\n", timeout: @obscure_timeout) do
        {:ok, String.trim(output)}
      end
    end
  end

  @doc "Runs an rclone command through the runner."
  @spec run(runner(), [String.t()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def run(runner, args, opts \\ [])
  def run(runner, args, opts) when is_function(runner, 2), do: runner.(args, opts)
  def run(runner, args, opts) when is_atom(runner), do: runner.run(args, opts)

  defp sync_timeout(opts) do
    Keyword.get_lazy(opts, :sync_timeout, fn ->
      Application.get_env(:feather, :rclone_sync_timeout, @default_sync_timeout)
    end)
  end

  defp default_runner, do: Application.get_env(:feather, :rclone_runner, SystemRunner)

  defp fetch_provider(%DeploymentTarget{provider: name}) do
    case provider(name) do
      nil -> {:error, "unknown provider #{inspect(name)}"}
      provider -> {:ok, provider}
    end
  end

  # The config holds credentials: it is created empty and private before
  # anything is written to it, and removed whatever happens.
  defp with_config_file(config, fun) do
    dir = Path.join(System.tmp_dir!(), "feather-rclone")
    File.mkdir_p!(dir)
    File.chmod!(dir, 0o700)
    path = Path.join(dir, "#{Feather.PublicId.generate()}.conf")

    try do
      File.touch!(path)
      File.chmod!(path, 0o600)
      File.write!(path, config)
      fun.(path)
    after
      File.rm(path)
    end
  end
end
