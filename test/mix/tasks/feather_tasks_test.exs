defmodule Mix.Tasks.FeatherTasksTest do
  use Feather.DataCase

  alias Feather.Accounts
  alias Mix.Tasks.Feather.CreateUser

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  test "feather.create_user creates a confirmed user" do
    CreateUser.run(["new@example.com"])
    assert_received {:mix_shell, :info, ["User new@example.com ready."]}

    user = Accounts.get_user_by_email("new@example.com")
    assert user.confirmed_at
    refute user.super_admin
  end

  test "feather.create_user --super-admin" do
    CreateUser.run(["Boss@Example.com", "--super-admin"])
    assert_received {:mix_shell, :info, ["User boss@example.com ready (super admin)."]}
    assert Accounts.get_user_by_email("boss@example.com").super_admin
  end

  test "feather.create_user without an email raises" do
    assert_raise Mix.Error, fn -> CreateUser.run([]) end
  end
end
