defmodule Feather.Highlighting.SystemRunnerTest do
  use ExUnit.Case, async: false

  alias Feather.Highlighting.SystemRunner

  @moduletag :tmp_dir

  defp script(dir, body) do
    path = Path.join(dir, "chroma")
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
      pwd -P
      env | cut -d= -f1 | sort
      """)

    System.put_env("FEATHER_TEST_SECRET", "secret")
    on_exit(fn -> System.delete_env("FEATHER_TEST_SECRET") end)

    assert {:ok, output} =
             SystemRunner.run(["--lexer", "ruby", "code"],
               cd: work,
               timeout: 5_000,
               executable: fake
             )

    assert ["args=--lexer ruby code", "home=" <> home, pwd | names] =
             String.split(output, "\n", trim: true)

    assert home == work
    assert pwd == real_path(work)
    assert names -- ~w(HOME PATH PWD OLDPWD SHLVL _) == []
  end

  test "returns chroma's message when it fails", %{tmp_dir: dir} do
    fake = script(dir, "echo 'error: lexer failed' >&2; exit 1\n")

    assert SystemRunner.run(["code"], timeout: 5_000, executable: fake) ==
             {:error, "error: lexer failed"}
  end

  test "aborts when chroma is not installed" do
    assert SystemRunner.run(["code"], timeout: 5_000, executable: nil) ==
             {:aborted, "chroma is not installed"}
  end

  test "kills chroma when it runs longer than the timeout", %{tmp_dir: dir} do
    fake = script(dir, "exec sleep 30\n")

    assert SystemRunner.run(["code"], timeout: 1_000, executable: fake) ==
             {:aborted, "chroma timed out after 1 seconds"}
  end

  defp real_path(path) do
    {resolved, 0} = System.cmd("pwd", ["-P"], cd: path)
    String.trim(resolved)
  end
end
