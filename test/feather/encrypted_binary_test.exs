defmodule Feather.Encrypted.BinaryTest do
  use ExUnit.Case, async: true

  alias Feather.Encrypted.Binary

  test "stores a secret encrypted, with a fresh IV for every write" do
    {:ok, a} = Binary.dump("secret")
    {:ok, b} = Binary.dump("secret")

    refute a =~ "secret"
    refute a == b
    assert Binary.load(a) == {:ok, "secret"}
    assert Binary.dump(nil) == {:ok, nil}
    assert Binary.load(nil) == {:ok, nil}
  end

  @tag :capture_log
  test "tampered ciphertext does not load" do
    {:ok, <<head::binary-size(30), byte, rest::binary>>} = Binary.dump("secret")

    assert Binary.load(<<head::binary, Bitwise.bxor(byte, 1), rest::binary>>) == :error
  end
end
