defmodule Mix.Tasks.FeatherTasksTest do
  use Feather.DataCase

  alias Feather.Accounts

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  test "feather.create_user creates a confirmed user" do
    Mix.Tasks.Feather.CreateUser.run(["new@example.com"])
    assert_received {:mix_shell, :info, ["User new@example.com ready."]}

    user = Accounts.get_user_by_email("new@example.com")
    assert user.confirmed_at
    refute user.super_admin
  end

  test "feather.create_user --super-admin" do
    Mix.Tasks.Feather.CreateUser.run(["Boss@Example.com", "--super-admin"])
    assert_received {:mix_shell, :info, ["User boss@example.com ready (super admin)."]}
    assert Accounts.get_user_by_email("boss@example.com").super_admin
  end

  test "feather.create_user without an email raises" do
    assert_raise Mix.Error, fn -> Mix.Tasks.Feather.CreateUser.run([]) end
  end

  test "feather.api_token prints a token that authenticates" do
    user = user_fixture()
    Mix.Tasks.Feather.ApiToken.run([user.email, "laptop"])
    assert_received {:mix_shell, :info, [token]}
    assert Accounts.get_user_by_api_token(token).id == user.id
    assert [%{name: "laptop"}] = Accounts.list_api_tokens(user)
  end

  test "feather.api_token for an unknown user raises" do
    assert_raise Mix.Error, fn -> Mix.Tasks.Feather.ApiToken.run(["nobody@example.com"]) end
  end

  describe "feather.import" do
    @dump Path.expand("../../fixtures/rails_dump", __DIR__)

    setup do
      on_exit(fn -> File.rm_rf!(Path.join(Feather.Media.storage_root(), "images")) end)
    end

    test "imports a dump and prints the counts" do
      Mix.Tasks.Feather.Import.run([@dump])
      assert_received {:mix_shell, :info, [report]}
      assert report =~ ~r/posts\s+2 dumped\s+2 imported/
      assert_received {:mix_shell, :info, ["Import finished."]}
      assert Repo.aggregate(Feather.Sites.Site, :count) == 2

      assert_raise Mix.Error, ~r/--force/, fn -> Mix.Tasks.Feather.Import.run([@dump]) end

      Mix.Tasks.Feather.Import.run([@dump, "--force"])
      assert_received {:mix_shell, :info, ["Import finished."]}
    end

    test "without a directory raises" do
      assert_raise Mix.Error, ~r/Usage/, fn -> Mix.Tasks.Feather.Import.run([]) end
    end
  end
end
