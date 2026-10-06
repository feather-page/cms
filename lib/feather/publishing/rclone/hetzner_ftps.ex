defmodule Feather.Publishing.Rclone.HetznerFtps do
  @moduledoc """
  The `hetzner_ftps` provider: FTP with explicit TLS on port 21 (Hetzner
  web hosting). Config: `host`, `user`, `password` and `path`.
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
       [hetzner-ftps]
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
  def remote(%DeploymentTarget{} = target, _opts) do
    with {:ok, [path]} <- Provider.fetch_config(target, ["path"]) do
      {:ok, "hetzner-ftps:#{path}"}
    end
  end
end
