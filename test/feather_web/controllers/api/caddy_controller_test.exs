defmodule FeatherWeb.Api.CaddyControllerTest do
  use FeatherWeb.ConnCase

  alias Feather.Publishing

  setup do
    scope = site_scope_fixture()
    %{scope: scope, staging: Publishing.get_staging_target(scope)}
  end

  defp check(domain), do: get(build_conn(), "/api/caddy/check_domain", domain: domain)

  test "allows the staging host of a site", %{staging: staging} do
    assert staging.provider == "internal"
    assert check(staging.public_hostname).status == 200
  end

  test "ignores case and surrounding whitespace", %{staging: staging} do
    assert check(" " <> String.upcase(staging.public_hostname)).status == 200
  end

  test "allows an internal production host", %{scope: scope} do
    target =
      deployment_target_fixture(scope, %{
        provider: "internal",
        public_hostname: "www.my-site.example",
        config: %{}
      })

    assert check(target.public_hostname).status == 200
  end

  test "refuses hosts deployed elsewhere", %{scope: scope} do
    target = deployment_target_fixture(scope, %{provider: "fastmail"})

    assert check(target.public_hostname).status == 404
  end

  test "refuses internal backup targets", %{scope: scope} do
    target =
      deployment_target_fixture(scope, %{
        type: "backup",
        provider: "internal",
        public_hostname: "backup.my-site.example",
        config: %{}
      })

    assert check(target.public_hostname).status == 404
  end

  test "refuses unknown hosts and requests without a domain" do
    assert check("example.com").status == 404
    assert get(build_conn(), "/api/caddy/check_domain").status == 404
  end
end
