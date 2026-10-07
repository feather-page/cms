defmodule FeatherWeb.RequestLogTest do
  use FeatherWeb.ConnCase

  import ExUnit.CaptureLog

  # Logs the request at :info (the test config only prints warnings).
  defp request_log(fun) do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)
    capture_log([level: :info], fun)
  end

  test "tokens in paths are filtered from the request log", %{conn: conn} do
    for path <- [
          "/users/log-in/SECRETMAGICTOKEN",
          "/invitations/SECRETMAGICTOKEN",
          "/users/settings/confirm-email/SECRETMAGICTOKEN"
        ] do
      log = request_log(fn -> get(build_conn(), path) end)

      refute log =~ "SECRETMAGICTOKEN", log
      assert log =~ "GET " <> String.replace(path, "SECRETMAGICTOKEN", "[FILTERED]")
    end

    log = request_log(fn -> post(conn, "/invitations/SECRETMAGICTOKEN/accept") end)
    refute log =~ "SECRETMAGICTOKEN", log
    assert log =~ "POST /invitations/[FILTERED]/accept"
  end

  test "other paths are logged as they are", %{conn: conn} do
    assert request_log(fn -> get(conn, "/users/log-in") end) =~ "GET /users/log-in"
  end
end
