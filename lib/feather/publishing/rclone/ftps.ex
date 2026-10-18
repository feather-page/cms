defmodule Feather.Publishing.Rclone.Ftps do
  @moduledoc """
  The `ftps` provider: FTP with explicit TLS on port 21. Config: `host`,
  `user`, `password` and `path`.
  """

  @behaviour Feather.Publishing.Rclone.Provider

  alias Feather.Publishing.DeploymentTarget
  alias Feather.Publishing.Rclone.Provider

  @impl true
  def config(%DeploymentTarget{} = target, obscure) do
    with {:ok, [host, user, password]} <-
           Provider.fetch_config(target, ["host", "user", "password"]),
         {:ok, pass} <- obscure.(password) do
      {:ok,
       """
       [ftps]
       type = ftp
       host = #{host}
       user = #{user}
       pass = #{pass}
       port = 21
       explicit_tls = true
       """}
    end
  end

  @impl true
  def remote(%DeploymentTarget{} = target) do
    with {:ok, [path]} <- Provider.fetch_config(target, ["path"]) do
      {:ok, "ftps:#{path}"}
    end
  end
end
