defmodule Feather.PublicIdTest do
  use ExUnit.Case, async: true

  alias Feather.PublicId

  test "generates 12 characters from 0-9a-zA-Z" do
    for _ <- 1..200 do
      id = PublicId.generate()
      assert id =~ ~r/\A[0-9a-zA-Z]{12}\z/
    end
  end

  test "generates distinct ids" do
    ids = for _ <- 1..1000, do: PublicId.generate()
    assert length(Enum.uniq(ids)) == 1000
  end

  test "put/1 puts a generated public id into the changeset" do
    changeset = PublicId.put(Ecto.Changeset.change(%Feather.Sites.Site{}))
    assert Ecto.Changeset.get_change(changeset, :public_id) =~ ~r/\A[0-9a-zA-Z]{12}\z/
  end
end
