defmodule FeatherWeb.SecureCookiesTest do
  use FeatherWeb.ConnCase

  alias FeatherWeb.Endpoint

  setup do
    %{user: user_fixture()}
  end

  defp log_in(conn, user) do
    {token, _hashed_token} = generate_user_magic_link_token(user)
    post(conn, ~p"/users/log-in", %{"user" => %{"token" => token, "remember_me" => "true"}})
  end

  defp set_cookies(conn) do
    for header <- get_resp_header(conn, "set-cookie"), into: %{} do
      [name | _] = String.split(header, "=", parts: 2)
      {name, header}
    end
  end

  test "cookies are not Secure over http (dev, test)", %{conn: conn, user: user} do
    refute Endpoint.secure_cookies?()
    cookies = conn |> log_in(user) |> set_cookies()

    refute cookies["_feather_key"] =~ ~r/;\s*secure/i
    refute cookies["_feather_web_user_remember_me"] =~ ~r/;\s*secure/i
  end

  test "session and remember-me cookies are Secure when the URL is https", %{
    conn: conn,
    user: user
  } do
    original = Application.get_env(:feather, Endpoint)
    https = Keyword.put(original, :url, host: "localhost", scheme: "https", port: 443)
    Endpoint.config_change([{Endpoint, https}], [])
    on_exit(fn -> Endpoint.config_change([{Endpoint, original}], []) end)

    assert Endpoint.secure_cookies?()
    cookies = conn |> log_in(user) |> set_cookies()

    assert cookies["_feather_key"] =~ ~r/;\s*secure/i
    assert cookies["_feather_web_user_remember_me"] =~ ~r/;\s*secure/i
  end
end
