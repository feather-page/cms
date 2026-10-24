defmodule Feather.Encrypted.ListTest do
  use ExUnit.Case, async: true

  alias Feather.Encrypted.List, as: EncryptedList

  test "stores a list as encrypted JSON" do
    list = [%{"url" => "https://e.example/secret.png", "name" => "A secret"}]
    {:ok, stored} = EncryptedList.dump(list)

    refute stored =~ "secret"
    assert EncryptedList.load(stored) == {:ok, list}
    assert EncryptedList.cast(nil) == {:ok, []}
    assert EncryptedList.load(nil) == {:ok, []}
  end

  @tag :capture_log
  test "tampered ciphertext does not load" do
    {:ok, <<head::binary-size(30), byte, rest::binary>>} = EncryptedList.dump(["secret"])

    assert EncryptedList.load(<<head::binary, Bitwise.bxor(byte, 1), rest::binary>>) == :error
  end
end
