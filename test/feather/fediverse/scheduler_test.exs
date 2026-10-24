defmodule Feather.Fediverse.SchedulerTest do
  use ExUnit.Case, async: true

  alias Feather.Fediverse.Scheduler

  defp start(name, run) do
    start_supervised!(
      {Scheduler, enabled: true, name: name, initial_delay: 0, interval: 10, run: run}
    )
  end

  test "runs what is due, again and again" do
    test_pid = self()
    start(:fediverse_scheduler, fn -> send(test_pid, :ran) end)

    assert_receive :ran
    assert_receive :ran
  end

  @tag :capture_log
  test "moves on after a failing run" do
    test_pid = self()

    start(:failing_fediverse_scheduler, fn ->
      send(test_pid, :ran)
      raise "boom"
    end)

    assert_receive :ran
    assert_receive :ran
  end

  test "does not start when disabled" do
    assert Scheduler.start_link(enabled: false) == :ignore
    # Disabled in config/test.exs.
    assert Scheduler.start_link([]) == :ignore
  end
end
