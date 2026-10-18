defmodule FeatherWeb.UserLive.LoginTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      refute html =~ "Sign up"
      refute html =~ ~s(type="password")
      assert html =~ "Log in with email"
    end

    test "the submit button guards against double submits", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(
               lv,
               ~s(#login_form_magic button[type=submit][phx-disable-with="Sending…"])
             )
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        lv |> form("#login_form_magic", user: %{email: user.email}) |> render_submit()

      assert html =~ "Check your email"
      assert has_element?(lv, "#login-sent", user.email)
      refute has_element?(lv, "#login_form_magic")

      assert Feather.Repo.get_by!(Feather.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      lv
      |> form("#login_form_magic", user: %{email: "idonotexist@example.com"})
      |> render_submit()

      # The same answer as for a known address.
      assert has_element?(lv, "#login-sent", "If idonotexist@example.com has an account")

      lv |> element("#use-another-email") |> render_click()
      assert has_element?(lv, "#login_form_magic")
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "You need to reauthenticate"
      refute html =~ "Register"
      assert html =~ "Log in with email"

      assert has_element?(
               lv,
               ~s(input#login_form_magic_email[type="email"][name="user[email]"][value="#{user.email}"][readonly])
             )
    end

    test "going back to the form keeps the email", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      lv |> form("#login_form_magic") |> render_submit()
      lv |> element("#use-another-email") |> render_click()

      assert has_element?(lv, ~s(#login_form_magic_email[value="#{user.email}"][readonly]))
    end
  end
end
