defmodule Feather.Publishing.RcloneTest do
  use ExUnit.Case, async: true

  alias Feather.Publishing.DeploymentTarget
  alias Feather.Publishing.Rclone

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

  test "ftps: ftp with explicit TLS and an obscured password" do
    target = %DeploymentTarget{
      provider: "ftps",
      config: %{"host" => "ftp.example.com", "user" => "u1", "password" => "pw", "path" => "/"}
    }

    assert {:ok, _} = Rclone.deploy(target, "/src/", runner: runner())
    assert_received {:rclone, [_, _, config, "/src/", "ftps:/"], content, mode}

    assert content ==
             "[ftps]\ntype = ftp\nhost = ftp.example.com\nuser = u1\npass = obscured(pw)\n" <>
               "port = 21\nexplicit_tls = true\n"

    refute content =~ "pass = pw"
    assert Bitwise.band(mode, 0o077) == 0
    refute File.exists?(config)
  end

  test "missing config or line breaks in values are errors without running rclone" do
    target = %DeploymentTarget{
      provider: "ftps",
      config: %{"host" => "ftp.example.com\n[evil]", "user" => "u1", "path" => "/"}
    }

    assert {:error, message} = Rclone.deploy(target, "/src/", runner: runner())
    assert message =~ "host, password"
    refute_received {:rclone, _, _, _}
  end

  test "a failing sync is returned and the config is still removed" do
    target = %DeploymentTarget{
      provider: "ftps",
      config: %{
        "host" => "ftp.example.com",
        "user" => "u1",
        "password" => "secret",
        "path" => "/"
      }
    }

    assert {:error, "boom"} = Rclone.deploy(target, "/src/", runner: runner({:error, "boom"}))
    assert_received {:rclone, [_, _, config | _], _content, _mode}
    refute File.exists?(config)
  end

  test "the password goes to rclone obscure on stdin, the sync gets a timeout" do
    target = %DeploymentTarget{
      provider: "ftps",
      config: %{
        "host" => "ftp.example.com",
        "user" => "u1",
        "password" => "secret",
        "path" => "/"
      }
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
