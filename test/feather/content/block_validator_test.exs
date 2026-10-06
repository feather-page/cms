defmodule Feather.Content.BlockValidatorTest do
  use ExUnit.Case, async: true

  alias Feather.Content.BlockValidator

  describe "schemas" do
    test "are the block schemas of docs/api/openapi.yml" do
      schemas = FeatherWeb.ApiHelpers.openapi_schemas()
      mapping = get_in(schemas, ["Block", "discriminator", "mapping"])

      openapi_blocks =
        Map.new(mapping, fn {type, "#/components/schemas/" <> name} ->
          {type, strip_descriptions(Map.fetch!(schemas, name))}
        end)

      assert BlockValidator.schemas() == openapi_blocks
      assert BlockValidator.types() == Enum.map(schemas["Block"]["oneOf"], &type_of(&1, schemas))
    end

    test "resolve their references like docs/api/openapi.yml" do
      schemas = FeatherWeb.ApiHelpers.openapi_schemas()

      for {name, schema} <- BlockValidator.definitions() do
        assert schema == strip_descriptions(Map.fetch!(schemas, name)), "#{name} differs"
      end

      referenced =
        BlockValidator.schemas()
        |> references()
        |> MapSet.new(fn "#/components/schemas/" <> name -> name end)

      assert referenced == MapSet.new(Map.keys(BlockValidator.definitions()))
    end
  end

  describe "validate/1" do
    test "accepts every block type" do
      content = [
        %{"type" => "paragraph", "text" => "Hello world"},
        %{"type" => "header", "text" => "Title", "level" => 2},
        %{"type" => "code", "code" => "x = 1", "language" => "ruby"},
        %{"type" => "image", "image_id" => "abc123xyz456"},
        %{"type" => "quote", "text" => "To be or not to be", "caption" => "Shakespeare"},
        %{"type" => "list", "style" => "ul", "items" => ["one", "two", "three"]},
        %{"type" => "table", "content" => [["A", "B"], ["1", "2"]], "with_headings" => true},
        %{
          "type" => "embed",
          "service" => "youtube",
          "source" => "https://youtu.be/x",
          "embed" => "https://www.youtube.com/embed/x",
          "width" => nil
        },
        %{"type" => "book", "book_public_id" => "abc123"}
      ]

      assert {:ok, blocks} = BlockValidator.validate(content)
      assert length(blocks) == 9
    end

    test "accepts empty content" do
      assert BlockValidator.validate([]) == {:ok, []}
    end

    test "accepts nested list items as objects or strings" do
      content = [
        %{
          "type" => "list",
          "items" => [
            %{"content" => "one", "items" => ["one.a", %{"content" => "one.b", "items" => []}]}
          ]
        }
      ]

      assert {:ok, [block]} = BlockValidator.validate(content)

      assert block["items"] == [
               %{
                 "content" => "one",
                 "items" => [
                   %{"content" => "one.a", "items" => []},
                   %{"content" => "one.b", "items" => []}
                 ]
               }
             ]
    end

    test "generates missing ids and keeps given ones" do
      assert {:ok, [generated, kept]} =
               BlockValidator.validate([
                 %{"type" => "paragraph", "text" => "Hello"},
                 %{"type" => "paragraph", "text" => "Hello", "id" => "my-id"}
               ])

      assert generated["id"] =~ ~r/\A[0-9a-zA-Z]{10}\z/
      assert kept["id"] == "my-id"
    end

    test "normalizes valid content" do
      assert {:ok, [code]} = BlockValidator.validate([%{"type" => "code", "code" => "x"}])
      assert code["language"] == "plaintext"
    end

    test "rejects content that is not a list" do
      assert BlockValidator.validate("not an array") ==
               {:error, ["Content must be an array of blocks"]}
    end

    test "rejects unknown and missing types, listing the valid ones" do
      assert {:error, [unknown, missing, not_a_map]} =
               BlockValidator.validate([%{"type" => "fancy"}, %{"text" => "no type"}, "text"])

      assert unknown ==
               "Block 0: unknown or missing type 'fancy'. Valid types: " <>
                 "paragraph, header, code, image, quote, list, table, embed, book"

      assert missing =~ "Block 1: unknown or missing type ''"
      assert not_a_map =~ "Block 2: unknown or missing type ''"
    end

    test "reports every error with block index and type" do
      assert {:error, errors} =
               BlockValidator.validate([
                 %{"type" => "paragraph", "text" => "fine"},
                 %{"type" => "header", "text" => 1, "level" => 1}
               ])

      assert errors == [
               "Block 1 (header): /level must be one of: 2, 3, 4",
               "Block 1 (header): /text expected string, got integer"
             ]
    end

    for {type, block, message} <- [
          {"paragraph", %{"type" => "paragraph"}, "missing required fields: text"},
          {"paragraph", %{"type" => "paragraph", "text" => "x", "html" => "y"},
           "unexpected: html"},
          {"header", %{"type" => "header", "text" => "Missing level"},
           "missing required fields: level"},
          {"header", %{"type" => "header", "text" => "x", "level" => "2"},
           "/level expected integer, got string"},
          {"code", %{"type" => "code", "code" => "x", "language" => nil},
           "/language expected string, got null"},
          {"image", %{"type" => "image", "caption" => "x"}, "missing required fields: image_id"},
          {"quote", %{"type" => "quote", "text" => "x"}, "missing required fields: caption"},
          {"list", %{"type" => "list"}, "missing required fields: items"},
          {"list", %{"type" => "list", "items" => [], "style" => "dl"},
           "/style must be one of: ul, ol"},
          {"list", %{"type" => "list", "items" => [%{"content" => 1, "items" => []}]},
           "/items/0 does not match any schema"},
          {"table", %{"type" => "table", "content" => [["a", 1]]},
           "/content/0/1 expected string, got integer"},
          {"table", %{"type" => "table", "content" => [], "with_headings" => "yes"},
           "/with_headings expected boolean, got string"},
          {"embed", %{"type" => "embed", "service" => "youtube"},
           "missing required fields: source, embed"},
          {"embed",
           %{
             "type" => "embed",
             "service" => "a",
             "source" => "b",
             "embed" => "c",
             "width" => 1.5
           }, "/width expected integer/null, got number"},
          {"book", %{"type" => "book"}, "missing required fields: book_public_id"}
        ] do
      test "rejects an invalid #{type} block: #{message}" do
        assert {:error, [error]} = BlockValidator.validate([unquote(Macro.escape(block))])
        assert error == "Block 0 (#{unquote(type)}): #{unquote(message)}"
      end
    end
  end

  defp strip_descriptions(%{} = schema) do
    schema |> Map.delete("description") |> Map.new(fn {k, v} -> {k, strip_descriptions(v)} end)
  end

  defp strip_descriptions(list) when is_list(list), do: Enum.map(list, &strip_descriptions/1)
  defp strip_descriptions(value), do: value

  defp type_of(%{"$ref" => "#/components/schemas/" <> name}, schemas),
    do: get_in(schemas, [name, "properties", "type", "const"])

  defp references(%{"$ref" => ref}), do: [ref]
  defp references(%{} = map), do: Enum.flat_map(Map.values(map), &references/1)
  defp references(list) when is_list(list), do: Enum.flat_map(list, &references/1)
  defp references(_value), do: []
end
