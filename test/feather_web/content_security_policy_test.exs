defmodule FeatherWeb.ContentSecurityPolicyTest do
  use FeatherWeb.ConnCase

  setup [:register_and_log_in_user, :create_site_for_user]

  defp directives(conn) do
    conn |> get_resp_header("content-security-policy") |> List.first() |> String.split("; ")
  end

  test "admin pages only run scripts from our own origin", %{conn: conn, site: site} do
    for path <- ["/", "/sites/#{site.public_id}/posts", "/users/log-in"] do
      directives = conn |> get(path) |> directives()

      assert "script-src 'self'" in directives, path
      assert "style-src 'self' 'unsafe-inline'" in directives
      refute Enum.any?(directives, &String.contains?(&1, "felt-css"))
      assert "object-src 'none'" in directives
    end
  end

  test "the preview, on the same origin, gets the policy too", %{conn: conn, site: site} do
    assert "script-src 'self'" in (conn |> get("/preview/#{site.public_id}/") |> directives())
  end
end
