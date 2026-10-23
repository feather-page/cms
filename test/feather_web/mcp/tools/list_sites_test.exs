defmodule FeatherWeb.MCP.Tools.ListSitesTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Publishing
  alias FeatherWeb.MCP.Tools.ListSites

  test "lists the member's sites with what is not deployed yet" do
    scope = Scope.for_user(user_fixture())
    site_fixture(scope, title: "Quiet", domain: "quiet.example")
    busy = Scope.put_site(scope, site_fixture(scope, title: "Busy", domain: "busy.example"))

    target = deployment_target_fixture(busy)
    deployed_at = DateTime.utc_now()
    Publishing.record_deploy(target, deployed_at)
    post_fixture(busy)
    assert Publishing.acquire_deploy_lock(target)

    assert ListSites.call(scope, %{}) ==
             {:ok,
              %{
                sites: [
                  %{
                    domain: "busy.example",
                    title: "Busy",
                    undeployed_changes: 1,
                    deploying: true,
                    last_deployed_at: deployed_at
                  },
                  %{
                    domain: "quiet.example",
                    title: "Quiet",
                    undeployed_changes: 0,
                    deploying: false,
                    last_deployed_at: nil
                  }
                ]
              }}
  end
end
