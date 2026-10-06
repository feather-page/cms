defmodule Feather.Publishing.Rclone.Internal do
  @moduledoc """
  The `internal` provider of staging targets: a local copy into
  `<staging_sites_path>/<public hostname without port>`, which the web
  server in front of the CMS serves.
  """

  @behaviour Feather.Publishing.Rclone.Provider

  alias Feather.Publishing.DeploymentTarget

  @impl true
  def config(%DeploymentTarget{}, _obscure), do: {:ok, "[internal]\ntype = local\n"}

  @impl true
  def remote(%DeploymentTarget{public_hostname: hostname}, opts) do
    host = hostname |> to_string() |> String.split(":") |> List.first()

    # The host name becomes a directory name: never a path.
    if host =~ ~r/\A[a-z0-9-]+(\.[a-z0-9-]+)*\z/ do
      path =
        opts
        |> Keyword.get_lazy(:staging_sites_path, fn ->
          Application.fetch_env!(:feather, :staging_sites_path)
        end)
        |> Path.join(host)
        |> Path.expand()

      File.mkdir_p!(path)
      {:ok, "internal:" <> path}
    else
      {:error, "invalid host name #{inspect(hostname)}"}
    end
  end
end
