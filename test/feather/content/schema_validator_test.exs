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
        "children" => %{"type" => "array", "items" => %{"$ref" => "#/$defs/Node"}}
      }
    }
  }

  @one_of %{"oneOf" => [%{"$ref" => "#/$defs/A"}, %{"$ref" => "#/$defs/B"}]}

  test "oneOf accepts data that matches any of its schemas" do
    assert SchemaValidator.validate(%{"kind" => "a", "n" => 1}, @one_of, @definitions) == []
    assert SchemaValidator.validate(%{"kind" => "b"}, @one_of, @definitions) == []

    assert [%{type: "oneOf", message: "does not match any schema"}] =
             SchemaValidator.validate(%{"kind" => "a", "n" => "1"}, @one_of, @definitions)

    assert [%{type: "oneOf"}] = SchemaValidator.validate("x", @one_of, @definitions)
  end

  test "resolves recursive references" do
    tree = %{"children" => [%{"children" => [%{"children" => "leaf"}]}]}

    assert [%{pointer: "/children/0/children/0/children", type: "type"}] =
             SchemaValidator.validate(
               tree,
               %{"$ref" => "#/$defs/Node"},
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
      SchemaValidator.validate(%{}, %{"$ref" => "#/$defs/Missing"})
    end
  end
end
