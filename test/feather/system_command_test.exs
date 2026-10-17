defmodule Feather.SystemCommandTest do
  use ExUnit.Case, async: false

  alias Feather.SystemCommand

  @moduletag :tmp_dir

  test "kills a command that times out without a kill executable on the PATH", %{tmp_dir: dir} do
    path = System.get_env("PATH")
    System.put_env("PATH", dir)
    on_exit(fn -> System.put_env("PATH", path) end)

    started = System.monotonic_time(:millisecond)
    assert {:timeout, ""} = SystemCommand.run("/bin/sleep", ["30"], timeout: 200)
    assert System.monotonic_time(:millisecond) - started < 5_000
  end
end
