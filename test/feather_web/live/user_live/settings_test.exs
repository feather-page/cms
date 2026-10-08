defmodule FeatherWeb.UserLive.SettingsTest do
  use FeatherWeb.ConnCase

  alias Feather.Accounts
  import Phoenix.LiveViewTest

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change email"
      refute html =~ ~s(type="password")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/settings")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change email"
      assert result =~ "did not change"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end

  describe "API tokens" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "creates a token and shows it once", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      refute has_element?(lv, "#new-api-token")

      lv |> form("#api_token_form", api_token: %{name: "Importer"}) |> render_submit()

      assert [token] = Accounts.list_api_tokens(user)
      assert token.name == "Importer"
      assert has_element?(lv, "#api-token-#{token.id}", "Importer")

      plain = lv |> element("#new-api-token code") |> render() |> LazyHTML.from_fragment()
      plain = LazyHTML.text(plain)
      assert Accounts.get_user_by_api_token(plain).id == user.id

      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      refute has_element?(lv, "#new-api-token")
      assert has_element?(lv, "#api-token-#{token.id}")
    end

    test "lists only own tokens and deletes them", %{conn: conn, user: user} do
      {:ok, _plain, own} = Accounts.create_api_token(user, "Mine")
      {:ok, _plain, other} = Accounts.create_api_token(user_fixture(), "Not mine")

      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      assert has_element?(lv, "#api-token-#{own.id}")
      refute has_element?(lv, "#api-token-#{other.id}")

      lv |> element("#delete-api-token-#{own.id}") |> render_click()

      refute has_element?(lv, "#api-token-#{own.id}")
      assert Accounts.list_api_tokens(user) == []
    end

    test "cannot delete another user's token", %{conn: conn} do
      other_user = user_fixture()
      {:ok, _plain, other} = Accounts.create_api_token(other_user, "Not mine")

      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      render_hook(lv, "delete_api_token", %{"id" => other.id})

      assert [_] = Accounts.list_api_tokens(other_user)
    end
  end
end
