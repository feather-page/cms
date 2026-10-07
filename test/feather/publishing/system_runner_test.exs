defmodule Feather.Publishing.Rclone.SystemRunnerTest do
  use ExUnit.Case, async: true

  alias Feather.Publishing.Rclone
  alias Feather.Publishing.Rclone.SystemRunner

  @moduletag :tmp_dir

  defp script(dir, name, body) do
    path = Path.join(dir, name)
    File.write!(path, "#!/bin/sh\n" <> body)
    File.chmod!(path, 0o755)
    path
  end

  test "passes input on stdin and returns the output", %{tmp_dir: dir} do
    fake = script(dir, "rclone", ~S|read line; echo "args=$* line=$line"| <> "\n")

    assert SystemRunner.run(["obscure", "-"], input: "secret\n", executable: fake) ==
             {:ok, "args=obscure - line=secret\n"}
  end

  test "reports a failing command", %{tmp_dir: dir} do
    fake = script(dir, "rclone", "echo nope; exit 3\n")

    assert SystemRunner.run(["sync", "a", "b"], executable: fake) ==
             {:error, "rclone sync failed (exit 3): nope"}
  end

  @tag :capture_log
  test "kills a command that runs longer than the timeout", %{tmp_dir: dir} do
    pid_file = Path.join(dir, "pid")
    fake = script(dir, "rclone", "echo $$ > #{pid_file}; exec sleep 30\n")

    started = System.monotonic_time(:millisecond)

    assert {:error, "rclone sync timed out after 0 seconds"} =
             SystemRunner.run(["sync", "a", "b"], timeout: 300, executable: fake)

    assert System.monotonic_time(:millisecond) - started < 5_000

    os_pid = pid_file |> File.read!() |> String.trim()
    {_, status} = System.cmd("kill", ["-0", os_pid], stderr_to_stdout: true)
    assert status != 0, "the command still runs"
    refute_received {_port, _message}
  end

  # CI installs rclone; the round trip checks `rclone obscure -` for real.
  @rclone System.find_executable("rclone")
  @tag skip: is_nil(@rclone) && "rclone is not installed"
  test "obscured passwords reveal to the original with the real rclone" do
    assert {:ok, obscured} = Rclone.obscure(SystemRunner, "pa ss:wörd")
    assert obscured != "pa ss:wörd"
    assert {:ok, "pa ss:wörd\n"} = SystemRunner.run(["reveal", obscured])
  end
end
