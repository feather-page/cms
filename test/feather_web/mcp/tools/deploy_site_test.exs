defmodule FeatherWeb.MCP.Tools.DeploySiteTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias FeatherWeb.MCP.Tools.DeploySite

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "starts a deploy and returns at once", %{site_scope: site_scope, scope: scope} do
    target = deployment_target_fixture(site_scope)

    assert DeploySite.call(scope, %{"site" => "notes.example"}) ==
             {:ok, %{site: "notes.example", deploying: true}}

    assert_received {:deploy_requested, %{id: id}}
    assert id == target.id
  end

  test "is an error for a site without deployment target", %{scope: scope} do
    assert DeploySite.call(scope, %{"site" => "notes.example"}) ==
             {:error,
              "notes.example has no deployment target. " <>
                "A member adds one in the CMS under Deployments."}
  end
end
