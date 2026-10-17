defmodule FeatherWeb.DiagramPreviewControllerTest do
  use FeatherWeb.ConnCase

  setup [:register_and_log_in_user, :create_site_for_user]

  setup do
    Feather.FakeD2.install()
  end

  defp preview(conn, site, params),
    do: post(conn, ~p"/sites/#{site.public_id}/diagrams/preview", params)

  test "returns the SVG of valid source", %{conn: conn, site: site} do
    assert json_response(preview(conn, site, %{code: "a -> b"}), 200) == %{
             "svg" => "<svg>a -> b\nstyle.fill: transparent\n</svg>"
           }
  end

  test "returns d2's error message for invalid source", %{conn: conn, site: site} do
    assert json_response(preview(conn, site, %{code: "broken"}), 422) == %{
             "error" => "err: failed to compile diagram.d2: diagram.d2:1:1: broken"
           }
  end

  test "rejects a request without source", %{conn: conn, site: site} do
    assert %{"error" => _} = json_response(preview(conn, site, %{}), 400)
    refute_received {:d2_rendered, _source}
  end

  test "denies access to sites the user is not a member of", %{conn: conn} do
    assert_error_sent 404, fn -> preview(conn, site_fixture(), %{code: "a -> b"}) end
    refute_received {:d2_rendered, _source}
  end
end
