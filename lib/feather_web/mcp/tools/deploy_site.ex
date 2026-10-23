defmodule FeatherWeb.MCP.Tools.DeploySite do
  @moduledoc """
  The tool `deploy_site`: starts a deploy of the site and returns at once.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Publishing
  alias FeatherWeb.MCP.Tool

  @impl true
  def definition do
    %{
      name: "deploy_site",
      title: "Deploy site",
      description:
        "Starts a deploy of the site, which puts everything published on the live site. " <>
          "Returns at once; list_sites shows when the deploy has finished.",
      inputSchema: Tool.input_schema(%{}, ["site"]),
      annotations: %{readOnlyHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      case Publishing.deploy_site(scope) do
        :ok ->
          {:ok, %{site: scope.site.domain, deploying: true}}

        {:error, :no_target} ->
          {:error,
           "#{scope.site.domain} has no deployment target. " <>
             "A member adds one in the CMS under Deployments."}
      end
    end
  end
end
