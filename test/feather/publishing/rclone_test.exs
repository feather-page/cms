defmodule Feather.Publishing.RcloneTest do
  use ExUnit.Case, async: true

  alias Feather.Publishing.DeploymentTarget
  alias Feather.Publishing.Rclone

  @moduletag :tmp_dir

  # Answers like rclone and reports every call (with the config file's
  # content, which is gone once deploy/3 returns) to the test process.
  defp runner(sync_result \\ {:ok, "done"}) do
    test = self()

    fn
      ["obscure", "-"], opts ->
        {:ok, "obscured(#{String.trim_trailing(opts[:input], "\n")})\n"}

      ["sync", "--config", config | _] = args, opts ->
        send(test, {:rclone, args, File.read!(config), File.stat!(config).mode})
        send(test, {:sync_timeout, opts[:timeout]})
        sync_result
    end
  end

  test "internal: local copy into the staging sites path", %{tmp_dir: tmp} do
    target = %DeploymentTarget{provider: "internal", public_hostname: "abc.stage.localhost:4000"}

    assert {:ok, "done"} =
             Rclone.deploy(target, "/src/", runner: runner(), staging_sites_path: tmp)

    assert_received {:rclone, ["sync", "--config", config, "/src/", remote], content, mode}
    assert remote == "internal:" <> Path.join(tmp, "abc.stage.localhost")
    assert File.dir?(Path.join(tmp, "abc.stage.localhost"))
    assert content == "[internal]\ntype = local\n"
    assert Bitwise.band(mode, 0o077) == 0
    refute File.exists?(config)
  end

  test "internal: a host name that is not a host name is refused", %{tmp_dir: tmp} do
    for hostname <- ["../../etc", "a/b", "..", ""] do
      target = %DeploymentTarget{provider: "internal", public_hostname: hostname}

      assert {:error, _} =
               Rclone.deploy(target, "/src/", runner: runner(), staging_sites_path: tmp)
    end

    refute_received {:rclone, _, _, _}
  end

  test "fastmail: webdav with an obscured password" do
    target = %DeploymentTarget{
      provider: "fastmail",
      public_hostname: "www.example.com",
      config: %{"email" => "me@example.com", "password" => "secret", "path" => "/site"}
    }

    assert {:ok, _} = Rclone.deploy(target, "/src/", runner: runner())
    assert_received {:rclone, [_, _, _, "/src/", remote], content, _mode}
    assert remote == "fastmail:/me.example.com/files/site"
    assert content =~ "type = webdav\nurl = https://webdav.fastmail.com/\nvendor = fastmail\n"
    assert content =~ "user = me@example.com\npass = obscured(secret)\n"
    refute content =~ "pass = secret"
  end

  test "hetzner_ftps: ftp with explicit TLS" do
    target = %DeploymentTarget{
      provider: "hetzner_ftps",
      public_hostname: "www.example.com",
      config: %{"host" => "ftp.example.com", "user" => "u1", "password" => "pw", "path" => "/"}
    }

    assert {:ok, _} = Rclone.deploy(target, "/src/", runner: runner())
    assert_received {:rclone, [_, _, _, "/src/", "hetzner-ftps:/"], content, _mode}

    assert content ==
             "[hetzner-ftps]\ntype = ftp\nhost = ftp.example.com\nuser = u1\npass = obscured(pw)\n" <>
               "port = 21\nexplicit_tls = true\n"
  end

  test "missing config or line breaks in values are errors without running rclone" do
    target = %DeploymentTarget{
      provider: "hetzner_ftps",
      public_hostname: "www.example.com",
      config: %{"host" => "ftp.example.com\n[evil]", "user" => "u1", "path" => "/"}
    }

    assert {:error, message} = Rclone.deploy(target, "/src/", runner: runner())
    assert message =~ "host, password"
    refute_received {:rclone, _, _, _}
  end

  test "a failing sync is returned and the config is still removed" do
    target = %DeploymentTarget{
      provider: "fastmail",
      public_hostname: "www.example.com",
      config: %{"email" => "me@example.com", "password" => "secret", "path" => "/site"}
    }

    assert {:error, "boom"} = Rclone.deploy(target, "/src/", runner: runner({:error, "boom"}))
    assert_received {:rclone, [_, _, config | _], _content, _mode}
    refute File.exists?(config)
  end

  test "the password goes to rclone obscure on stdin, the sync gets a timeout" do
    target = %DeploymentTarget{
      provider: "fastmail",
      public_hostname: "www.example.com",
      config: %{"email" => "me@example.com", "password" => "secret", "path" => "/site"}
    }

    assert {:ok, _} = Rclone.deploy(target, "/src/", runner: runner())
    assert_received {:sync_timeout, 1_800_000}

    assert {:ok, _} = Rclone.deploy(target, "/src/", runner: runner(), sync_timeout: 5)
    assert_received {:sync_timeout, 5}

    assert Rclone.obscure(runner(), "a\nb") ==
             {:error, "passwords with line breaks are not supported"}
  end

  test "unknown providers" do
    assert {:error, _} =
             Rclone.deploy(%DeploymentTarget{provider: "s3"}, "/src/", runner: runner())
  end
end
