defmodule FeatherWeb.HealthControllerTest do
  use FeatherWeb.ConnCase

  test "GET /up answers ok without a session", %{conn: conn} do
    conn = get(conn, ~p"/up")

    assert response(conn, 200) == "ok"
    assert response_content_type(conn, :text) =~ "text/plain"
    assert get_resp_header(conn, "set-cookie") == []
  end

  describe "force_ssl in production" do
    setup do
      opts =
        "config/prod.exs"
        |> Config.Reader.read!(env: :prod)
        |> get_in([:feather, FeatherWeb.Endpoint, :force_ssl])
        |> Plug.SSL.init()

      %{opts: opts}
    end

    test "lets the health check through over plain HTTP", %{opts: opts} do
      conn = Plug.SSL.call(Plug.Test.conn(:get, "http://172.18.0.5:4000/up"), opts)
      refute conn.halted
    end

    test "still redirects everything else", %{opts: opts} do
      conn = Plug.SSL.call(Plug.Test.conn(:get, "http://app.feather.page/users/log-in"), opts)
      assert conn.halted
      assert conn.status == 301
    end
  end
end
