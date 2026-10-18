defmodule Feather.RenderToolTest do
  use ExUnit.Case, async: true

  alias Feather.RenderTool

  test "run/3 aborts when the runner raises" do
    assert RenderTool.run(fn _args, _opts -> raise "boom" end, [], []) == {:aborted, "boom"}

    assert RenderTool.run(fn _args, _opts -> raise ErlangError, original: :eacces end, [], []) ==
             {:aborted, "Erlang error: :eacces"}
  end
end
