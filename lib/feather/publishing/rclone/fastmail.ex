defmodule Feather.Publishing.Rclone.Fastmail do
  @moduledoc """
  The `fastmail` provider: Fastmail's file storage over WebDAV. Config:
  `email`, `password` (an app password) and `path` (e.g. `/mysite`); the
  files land in `/<email with @ as .>/files<path>`.
  """

  @behaviour Feather.Publishing.Rclone.Provider

  alias Feather.Publishing.DeploymentTarget
  alias Feather.Publishing.Rclone.Provider

  @impl true
  def config(%DeploymentTarget{} = target, obscure) do
    with {:ok, [email, password]} <- Provider.fetch_config(target, ["email", "password"]),
         {:ok, pass} <- obscure.(password) do
      {:ok,
       """
       [fastmail]
       type = webdav
       url = https://webdav.fastmail.com/
       vendor = fastmail
       user = #{email}
       pass = #{pass}
       """}
    end
  end

  @impl true
  def remote(%DeploymentTarget{} = target, _opts) do
    with {:ok, [email, path]} <- Provider.fetch_config(target, ["email", "path"]) do
      {:ok, "fastmail:/#{String.replace(email, "@", ".")}/files#{path}"}
    end
  end
end
