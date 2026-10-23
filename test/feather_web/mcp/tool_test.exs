defmodule FeatherWeb.MCP.ToolTest do
  use ExUnit.Case, async: true

  alias Feather.Content.BlockValidator
  alias FeatherWeb.MCP.Tool

  describe "input_schema/2" do
    test "is an object of the properties and no others" do
      assert Tool.input_schema(%{"query" => %{"type" => "string"}}, ["query"]) == %{
               "type" => "object",
               "properties" => %{"query" => %{"type" => "string"}},
               "required" => ["query"],
               "additionalProperties" => false
             }

      refute Map.has_key?(Tool.input_schema(%{}), "required")
    end

    test "adds the site's property when the site is required" do
      assert %{"properties" => %{"site" => %{"type" => "string"}}, "required" => ["site"]} =
               Tool.input_schema(%{}, ["site"])
    end

    test "adds the block schemas with a content property" do
      assert Tool.input_schema(%{"content" => %{"type" => "array"}})["$defs"] ==
               BlockValidator.definitions()
    end
  end
end
