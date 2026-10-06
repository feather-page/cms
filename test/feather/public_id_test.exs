defmodule Feather.PublicIdTest do
  use ExUnit.Case, async: true

  alias Feather.PublicId

  test "generates 12 characters from 0-9a-zA-Z" do
    for _ <- 1..200 do
      id = PublicId.generate()
      assert id =~ ~r/\A[0-9a-zA-Z]{12}\z/
      assert PublicId.valid?(id)
    end
  end

  test "generates distinct ids" do
    ids = for _ <- 1..1000, do: PublicId.generate()
    assert length(Enum.uniq(ids)) == 1000
  end

  test "valid?/1 rejects other strings" do
    refute PublicId.valid?("too-short")
    refute PublicId.valid?("abc_def-ghij")
    refute PublicId.valid?(nil)
  end

  test "put_new/1 keeps an existing public id" do
    changeset = Ecto.Changeset.change(%Feather.Sites.Site{public_id: "AAAAAAAAAAAA"})
    assert Ecto.Changeset.get_field(PublicId.put_new(changeset), :public_id) == "AAAAAAAAAAAA"

    changeset = Ecto.Changeset.change(%Feather.Sites.Site{})
    assert PublicId.valid?(Ecto.Changeset.get_field(PublicId.put_new(changeset), :public_id))
  end
end
