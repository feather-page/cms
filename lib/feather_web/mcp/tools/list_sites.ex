defmodule FeatherWeb.MCP.Tools.ListSites do
  @moduledoc """
  The tool `list_sites`: the sites the user is a member of, with what is
  not deployed yet.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Accounts.Scope
  alias Feather.{Publishing, Sites}
  alias FeatherWeb.MCP.Tool

  @impl true
  def definition do
    %{
      name: "list_sites",
      title: "List sites",
      description:
        "Lists the sites you can work on: domain and title, how many changes are not " <>
          "deployed yet, whether a deploy is running and when the last deploy ran. " <>
          "Other tools name a site by its domain.",
      inputSchema: Tool.input_schema(%{}),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(%Scope{} = scope, _arguments) do
    sites = for site <- Sites.list_member_sites(scope), do: summary(Scope.put_site(scope, site))
    {:ok, %{sites: sites}}
  end

  defp summary(%Scope{site: site} = scope) do
    target = Publishing.get_target(scope)

    %{
      domain: site.domain,
      title: site.title,
      undeployed_changes: Publishing.undeployed_count(scope),
      deploying: target != nil and target.deploying,
      last_deployed_at: target && target.last_deployed_at
    }
  end
end
