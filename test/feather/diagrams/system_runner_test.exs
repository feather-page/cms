defmodule Feather.Diagrams.SystemRunnerTest do
  use ExUnit.Case, async: false

  alias Feather.Diagrams.SystemRunner

  @moduletag :tmp_dir

  defp script(dir, body) do
    path = Path.join(dir, "d2")
    File.write!(path, "#!/bin/sh\n" <> body)
    File.chmod!(path, 0o755)
    path
  end

  test "runs in the given directory with an empty environment", %{tmp_dir: dir} do
    work = Path.join(dir, "work")
    File.mkdir_p!(work)

    fake =
      script(dir, """
      echo "args=$*"
      echo "home=$HOME"
      echo "path=$PATH"
      pwd -P
      env | cut -d= -f1 | sort
      """)

    System.put_env("D2_LAYOUT", "elk")
    System.put_env("FEATHER_TEST_SECRET", "secret")

    on_exit(fn ->
      System.delete_env("D2_LAYOUT")
      System.delete_env("FEATHER_TEST_SECRET")
    end)

    assert {:ok, output} =
             SystemRunner.run(["in.d2", "out.svg"], cd: work, timeout: 5_000, executable: fake)

    assert ["args=in.d2 out.svg", "home=" <> home, "path=" <> path, pwd | names] =
             String.split(output, "\n", trim: true)

    assert home == work
    assert path == System.get_env("PATH")
    assert pwd == real_path(work)
    assert "HOME" in names and "PATH" in names
    assert names -- ~w(HOME PATH PWD OLDPWD SHLVL _) == []
  end

  test "limits d2's address space on Linux only" do
    assert SystemRunner.command("/usr/bin/d2", ["in.d2", "out.svg"], {:unix, :linux}) ==
             {"/bin/sh",
              ["-c", ~s(ulimit -v 4194304 && exec "$0" "$@"), "/usr/bin/d2", "in.d2", "out.svg"]}

    assert SystemRunner.command("/usr/bin/d2", ["in.d2"], {:unix, :darwin}) ==
             {"/usr/bin/d2", ["in.d2"]}
  end

  @tag skip:
         (:os.type() != {:unix, :linux} or is_nil(System.find_executable("d2"))) &&
           "needs d2 on Linux"
  test "the real d2 starts under the address space limit" do
    assert {:ok, "v" <> _version} = SystemRunner.run(["--version"], timeout: 10_000)
  end

  test "returns d2's message when it fails", %{tmp_dir: dir} do
    fake = script(dir, "echo 'err: failed to compile' >&2; exit 1\n")

    assert SystemRunner.run(["in.d2"], timeout: 5_000, executable: fake) ==
             {:error, "err: failed to compile"}
  end

  test "aborts when d2 is not installed" do
    assert SystemRunner.run(["in.d2"], timeout: 5_000, executable: nil) ==
             {:aborted, "d2 is not installed"}
  end

  test "kills d2 when it runs longer than the timeout", %{tmp_dir: dir} do
    fake = script(dir, "exec sleep 30\n")

    assert SystemRunner.run(["in.d2"], timeout: 1_000, executable: fake) ==
             {:aborted, "d2 timed out after 1 seconds"}
  end

  defp real_path(path) do
    {resolved, 0} = System.cmd("pwd", ["-P"], cd: path)
    String.trim(resolved)
  end
end
