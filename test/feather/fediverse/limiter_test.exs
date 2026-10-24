defmodule Feather.Fediverse.LimiterTest do
  use ExUnit.Case, async: true

  alias Feather.Fediverse.Limiter

  setup %{test: name} do
    start_supervised!({Limiter, name: name, max_total: 3, max_per_host: 2})
    %{limiter: name}
  end

  defp start_request(limiter, host, timeout \\ 5_000) do
    test_pid = self()

    Task.async(fn ->
      Limiter.run(
        host,
        fn ->
          send(test_pid, {:running, self()})

          receive do
            :finish -> {:done, host}
          end
        end,
        server: limiter,
        timeout: timeout
      )
    end)
  end

  defp assert_running(%Task{pid: pid}), do: assert_receive({:running, ^pid})
  defp refute_running(%Task{pid: pid}), do: refute_receive({:running, ^pid}, 100)

  defp finish(%Task{pid: pid} = task) do
    send(pid, :finish)
    Task.await(task)
  end

  test "runs at most max_per_host requests to a host at once", %{limiter: limiter} do
    first = start_request(limiter, "a.example")
    second = start_request(limiter, "a.example")
    assert_running(first)
    assert_running(second)

    third = start_request(limiter, "a.example")
    refute_running(third)

    other_host = start_request(limiter, "b.example")
    assert_running(other_host)

    assert finish(first) == {:done, "a.example"}
    assert_running(third)

    for task <- [second, third], do: assert(finish(task) == {:done, "a.example"})
    assert finish(other_host) == {:done, "b.example"}
  end

  test "runs at most max_total requests at once", %{limiter: limiter} do
    for host <- ~w(a.example b.example c.example),
        do: limiter |> start_request(host) |> assert_running()

    fourth = start_request(limiter, "d.example", 100)
    refute_running(fourth)
    assert Task.await(fourth) == {:error, :busy}
  end

  test "frees the slot of a request whose process dies", %{limiter: limiter} do
    first = start_request(limiter, "a.example")
    second = start_request(limiter, "a.example")
    assert_running(first)
    assert_running(second)

    third = start_request(limiter, "a.example")
    refute_running(third)
    Task.shutdown(first, :brutal_kill)
    assert_running(third)

    assert finish(third) == {:done, "a.example"}
  end

  test "a request that gave up waiting takes no slot", %{limiter: limiter} do
    first = start_request(limiter, "a.example")
    second = start_request(limiter, "a.example")
    assert_running(first)
    assert_running(second)

    assert limiter |> start_request("a.example", 50) |> Task.await() == {:error, :busy}

    assert finish(second) == {:done, "a.example"}
    next = start_request(limiter, "a.example")
    assert_running(next)
    assert finish(next) == {:done, "a.example"}
  end
end
