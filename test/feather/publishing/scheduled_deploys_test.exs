defmodule Feather.Publishing.ScheduledDeploysTest do
  use ExUnit.Case, async: true

  alias Feather.Publishing.ScheduledDeploys

  defp start(name, deploy) do
    start_supervised!(
      {ScheduledDeploys,
       enabled: true, name: name, initial_delay: 0, interval: 10, deploy: deploy}
    )
  end

  test "checks the time since boot first, then since the last check" do
    test_pid = self()

    start(:scheduled_deploys, fn from, to ->
      send(test_pid, {:checked, from, to})
      []
    end)

    assert_receive {:checked, nil, first}
    assert_receive {:checked, ^first, second}
    assert DateTime.compare(first, second) == :lt
  end

  @tag :capture_log
  test "moves on after a failing check" do
    test_pid = self()

    start(:failing_scheduled_deploys, fn from, to ->
      send(test_pid, {:checked, from, to})
      raise "boom"
    end)

    assert_receive {:checked, nil, first}
    assert_receive {:checked, ^first, _second}
  end

  test "does not start when disabled" do
    assert ScheduledDeploys.start_link(enabled: false) == :ignore
    # Disabled in config/test.exs.
    assert ScheduledDeploys.start_link([]) == :ignore
  end
end
