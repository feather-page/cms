defmodule Feather.PublishingTest do
  use Feather.DataCase

  alias Feather.Publishing
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Accounts.Scope

  setup do
    %{scope: site_scope_fixture()}
  end

  test "targets are listed staging first", %{scope: scope} do
    deployment_target_fixture(scope, type: "backup")
    deployment_target_fixture(scope, type: "production")

    assert Enum.map(Publishing.list_targets(scope), & &1.type) == ~w(staging production backup)
    assert [%{type: "production"}] = Publishing.list_targets(scope, :production)
    assert Publishing.get_staging_target(scope).provider == "internal"
  end

  test "validates type, provider and a unique, normalized hostname", %{scope: scope} do
    target = deployment_target_fixture(scope, public_hostname: "  WWW.Example.COM ")
    assert target.public_hostname == "www.example.com"

    assert {:error, changeset} =
             Publishing.create_target(scope, %{
               type: "preview",
               provider: "s3",
               public_hostname: "www.example.com"
             })

    errors = errors_on(changeset)
    assert "is invalid" in errors.type
    assert "is invalid" in errors.provider
    assert "has already been taken" in errors.public_hostname
  end

  test "update_target/3 changes hostname and type only", %{scope: scope} do
    target = deployment_target_fixture(scope)

    assert {:ok, updated} =
             Publishing.update_target(scope, target, %{
               public_hostname: "New.Example.com",
               type: "backup",
               provider: "internal"
             })

    assert updated.public_hostname == "new.example.com"
    assert updated.type == "backup"
    assert updated.provider == "hetzner_ftps"

    assert {:error, changeset} = Publishing.update_target(scope, target, %{public_hostname: ""})
    assert "can't be blank" in errors_on(changeset).public_hostname
  end

  describe "encrypted config" do
    test "round trips and is not stored in plaintext", %{scope: scope} do
      target = deployment_target_fixture(scope)
      config = %{"host" => "ftp.example.com", "user" => "u1", "password" => "secret"}

      assert Publishing.get_target!(scope, target.public_id).config == config

      [[raw]] =
        Repo.query!("SELECT config FROM deployment_targets WHERE id = ?", [target.id]).rows

      assert is_binary(raw)
      refute raw =~ "secret"
      refute raw =~ "ftp.example.com"

      {:ok, updated} = Publishing.update_target_config(scope, target, %{password: "new"})
      assert Publishing.get_target!(scope, updated.public_id).config == %{"password" => "new"}
    end

    test "uses a fresh IV for every write" do
      {:ok, a} = Feather.Encrypted.Map.dump(%{"a" => 1})
      {:ok, b} = Feather.Encrypted.Map.dump(%{"a" => 1})
      refute a == b
      assert {:ok, %{"a" => 1}} = Feather.Encrypted.Map.load(a)
    end

    test "tampered ciphertext does not load" do
      {:ok, <<head::binary-size(30), byte, rest::binary>>} =
        Feather.Encrypted.Map.dump(%{"a" => 1})

      tampered = <<head::binary, Bitwise.bxor(byte, 1), rest::binary>>
      assert :error = Feather.Encrypted.Map.load(tampered)
    end
  end

  describe "deploy lock" do
    test "only one caller acquires the lock", %{scope: scope} do
      target = Publishing.get_staging_target(scope)

      assert Publishing.acquire_deploy_lock(target)
      refute Publishing.acquire_deploy_lock(target)
      assert Publishing.deploying?(target)

      :ok = Publishing.release_deploy_lock(target)
      refute Publishing.deploying?(target)
      assert Publishing.acquire_deploy_lock(target)
    end

    test "release_stale_locks/0 releases every held lock", %{scope: scope} do
      target = Publishing.get_staging_target(scope)
      other = deployment_target_fixture(scope)
      assert Publishing.acquire_deploy_lock(target)
      assert Publishing.acquire_deploy_lock(other)

      assert Publishing.release_stale_locks() == 2
      refute Publishing.deploying?(target)
      refute Publishing.deploying?(other)
    end
  end

  describe "undeployed_changes?/1" do
    defp deployed(target, at) do
      target |> Ecto.Changeset.change(last_deployed_at: at) |> Repo.update!()
    end

    defp in_a_minute, do: DateTime.add(DateTime.utc_now(), 60)

    test "is false without a production target", %{scope: scope} do
      post_fixture(scope)
      deployment_target_fixture(scope, type: "backup")

      refute Publishing.undeployed_changes?(scope)
    end

    test "compares the newest publish of posts, pages and projects with the last deploy", %{
      scope: scope
    } do
      target = deployment_target_fixture(scope)

      for publish <- [&post_fixture/1, &page_fixture/1, &project_fixture/1] do
        deployed(target, DateTime.utc_now())
        refute Publishing.undeployed_changes?(scope)

        publish.(scope)
        assert Publishing.undeployed_changes?(scope)
      end
    end

    test "ignores drafts and other sites", %{scope: scope} do
      scope |> deployment_target_fixture() |> deployed(in_a_minute())
      later = DateTime.add(DateTime.utc_now(), 3600)
      other = site_scope_fixture()
      post_fixture(other)

      Repo.update_all(Feather.Content.PostVersion, set: [published_at: later])

      refute Publishing.undeployed_changes?(scope)
      post_fixture(scope, draft: true)
      refute Publishing.undeployed_changes?(scope)
    end

    test "a production target never deployed counts as not deployed", %{scope: scope} do
      scope |> deployment_target_fixture() |> deployed(in_a_minute())
      deployment_target_fixture(scope)

      assert Publishing.undeployed_changes?(scope)
    end
  end

  describe "get_preview_target/2" do
    test "returns the target only for users with access", %{scope: scope} do
      target = Publishing.get_staging_target(scope)

      assert %DeploymentTarget{site: %{id: site_id}} =
               Publishing.get_preview_target(Scope.for_user(scope.user), target.public_id)

      assert site_id == scope.site.id
      assert Publishing.get_preview_target(user_scope_fixture(), target.public_id) == nil
      assert Publishing.get_preview_target(Scope.for_user(scope.user), "nope") == nil
    end
  end
end
