defmodule Feather.Content.SchemaValidatorTest do
  use ExUnit.Case, async: true

  alias Feather.Content.SchemaValidator

  @definitions %{
    "A" => %{
      "type" => "object",
      "required" => ["kind"],
      "properties" => %{"kind" => %{"const" => "a"}, "n" => %{"type" => "integer"}}
    },
    "B" => %{"type" => "object", "properties" => %{"kind" => %{"const" => "b"}}},
    "Node" => %{
      "type" => "object",
      "properties" => %{
        "children" => %{"type" => "array", "items" => %{"$ref" => "#/components/schemas/Node"}}
      }
    }
  }

  @one_of %{
    "oneOf" => [%{"$ref" => "#/components/schemas/A"}, %{"$ref" => "#/components/schemas/B"}],
    "discriminator" => %{"propertyName" => "kind"}
  }

  test "validates against the schema the discriminator picks" do
    assert SchemaValidator.validate(%{"kind" => "a", "n" => 1}, @one_of, @definitions) == []

    assert [%{pointer: "/n", type: "type", message: "expected integer, got string"}] =
             SchemaValidator.validate(%{"kind" => "a", "n" => "1"}, @one_of, @definitions)
  end

  test "without a matching discriminator any matching schema will do" do
    assert [%{type: "oneOf", message: "does not match any schema"}] =
             SchemaValidator.validate(%{"kind" => "c"}, @one_of, @definitions)

    assert [%{type: "oneOf"}] = SchemaValidator.validate("x", @one_of, @definitions)
  end

  test "resolves recursive references" do
    tree = %{"children" => [%{"children" => [%{"children" => "leaf"}]}]}

    assert [%{pointer: "/children/0/children/0/children", type: "type"}] =
             SchemaValidator.validate(
               tree,
               %{"$ref" => "#/components/schemas/Node"},
               @definitions
             )
  end

  test "checks additional properties against a schema" do
    schema = %{"type" => "object", "additionalProperties" => %{"type" => "array"}}

    assert [%{pointer: "/b", message: "expected array, got object"}] =
             SchemaValidator.validate(%{"a" => [], "b" => %{}}, schema)
  end

  test "raises on unknown references" do
    assert_raise ArgumentError, fn ->
      SchemaValidator.validate(%{}, %{"$ref" => "#/components/schemas/Missing"})
    end
  end
end
