defmodule Feather.Fediverse.RateLimitTest do
  use ExUnit.Case, async: true

  alias Feather.Fediverse.RateLimit

  test "allows the limit per key and window and refuses more" do
    key = make_ref()

    for _n <- 1..3, do: assert(RateLimit.hit(key, 3, 60_000) == :ok)

    assert RateLimit.hit(key, 3, 60_000) == {:error, :rate_limited}
    assert RateLimit.hit(make_ref(), 3, 60_000) == :ok
  end

  test "takes back a counted event" do
    key = make_ref()
    assert RateLimit.hit(key, 1, 60_000) == :ok

    assert RateLimit.refund(key, 60_000) == :ok
    assert RateLimit.hit(key, 1, 60_000) == :ok
    assert RateLimit.hit(key, 1, 60_000) == {:error, :rate_limited}

    uncounted = make_ref()
    assert RateLimit.refund(uncounted, 60_000) == :ok
    assert RateLimit.hit(uncounted, 1, 60_000) == :ok
    assert RateLimit.hit(uncounted, 1, 60_000) == {:error, :rate_limited}
  end

  test "counts afresh in the next window" do
    key = make_ref()
    assert RateLimit.hit(key, 1, 5) == :ok

    assert Enum.any?(1..1_000_000, fn _n -> RateLimit.hit(key, 1, 5) == :ok end)
  end
end
