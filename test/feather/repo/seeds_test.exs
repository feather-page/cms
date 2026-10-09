defmodule Feather.Repo.SeedsTest do
  use Feather.DataCase

  import ExUnit.CaptureIO

  alias Feather.Content
  alias Feather.Content.{Page, Post}

  test "the seeds publish the demo site's records and can run again" do
    for _run <- 1..2, do: capture_io(fn -> Code.eval_file("priv/repo/seeds.exs") end)

    records = Repo.all(Post) ++ Repo.all(Page)

    assert Enum.sort(Enum.map(records, & &1.title)) == ["About", "Hello World", "Home"]
    refute Enum.any?(records, &Content.draft?/1)
  end
end
