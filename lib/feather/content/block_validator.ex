defmodule Feather.Content.BlockValidator do
  @moduledoc """
  Validates content coming in through the content API against the block
  schemas of `docs/api/openapi.yml` (port of Rails'
  `Blocks::ContentValidator`).

  Each block is checked against the schema of its `type` (the `Block`
  discriminator mapping in the OpenAPI document). Error messages name the
  block index and type so an API client (often an AI import tool) can fix
  its input:

      Block 0: unknown or missing type 'fancy'. Valid types: paragraph, header, ...
      Block 0 (header): missing required fields: level
      Block 0 (header): /level must be one of: 2, 3, 4
      Block 1 (code): /code expected string, got integer

  Valid content is normalized with `Feather.Content.Blocks.normalize/1`:
  blocks without an `id` get a random 10 character alphanumeric one and
  defaults are filled in.

  The schemas are hand-ported from the OpenAPI document (without
  descriptions). `test/feather/content/block_validator_test.exs` checks
  that they stay identical to it.
  """

  alias Feather.Content.{Blocks, SchemaValidator}

  @ref_list_item %{"$ref" => "#/components/schemas/ListItem"}
  @list_item_entry %{"oneOf" => [@ref_list_item, %{"type" => "string"}]}

  @id %{"type" => "string"}

  @block_schemas [
    {"paragraph",
     %{
       "type" => "object",
       "required" => ["type", "text"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "paragraph"},
         "text" => %{"type" => "string"}
       }
     }},
    {"header",
     %{
       "type" => "object",
       "required" => ["type", "text", "level"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "header"},
         "text" => %{"type" => "string"},
         "level" => %{"type" => "integer", "enum" => [2, 3, 4]}
       }
     }},
    {"code",
     %{
       "type" => "object",
       "required" => ["type", "code"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "code"},
         "code" => %{"type" => "string"},
         "language" => %{"type" => "string", "default" => "plaintext"}
       }
     }},
    {"image",
     %{
       "type" => "object",
       "required" => ["type", "image_id"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "image"},
         "image_id" => %{"type" => "string"},
         "caption" => %{"type" => "string", "default" => ""}
       }
     }},
    {"quote",
     %{
       "type" => "object",
       "required" => ["type", "text", "caption"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "quote"},
         "text" => %{"type" => "string"},
         "caption" => %{"type" => "string"}
       }
     }},
    {"list",
     %{
       "type" => "object",
       "required" => ["type", "items"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "list"},
         "style" => %{"type" => "string", "enum" => ["ul", "ol"], "default" => "ul"},
         "items" => %{"type" => "array", "items" => @list_item_entry}
       }
     }},
    {"table",
     %{
       "type" => "object",
       "required" => ["type", "content"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "table"},
         "content" => %{
           "type" => "array",
           "items" => %{"type" => "array", "items" => %{"type" => "string"}}
         },
         "with_headings" => %{"type" => "boolean", "default" => false}
       }
     }},
    {"embed",
     %{
       "type" => "object",
       "required" => ["type", "service", "source", "embed"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "embed"},
         "service" => %{"type" => "string"},
         "source" => %{"type" => "string"},
         "embed" => %{"type" => "string"},
         "width" => %{"type" => ["integer", "null"]},
         "height" => %{"type" => ["integer", "null"]},
         "caption" => %{"type" => "string", "default" => ""}
       }
     }},
    {"book",
     %{
       "type" => "object",
       "required" => ["type", "book_public_id"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "book"},
         "book_public_id" => %{"type" => "string"},
         "title" => %{"type" => "string"},
         "author" => %{"type" => "string"},
         "cover_url" => %{"type" => "string"},
         "emoji" => %{"type" => "string"}
       }
     }}
  ]

  @definitions %{
    "ListItem" => %{
      "type" => "object",
      "required" => ["content", "items"],
      "properties" => %{
        "content" => %{"type" => "string"},
        "items" => %{"type" => "array", "items" => @list_item_entry}
      }
    }
  }

  @types Enum.map(@block_schemas, &elem(&1, 0))
  @schemas Map.new(@block_schemas)

  @doc "The block types in the order of the OpenAPI discriminator mapping."
  @spec types() :: [String.t()]
  def types, do: @types

  @doc "The block schemas by type."
  @spec schemas() :: %{String.t() => map()}
  def schemas, do: @schemas

  @doc "The schemas the block schemas refer to with `$ref`, by name."
  @spec definitions() :: %{String.t() => map()}
  def definitions, do: @definitions

  @doc """
  Validates content (a list of blocks with string keys, as decoded from
  JSON). Returns the normalized blocks or the list of error messages.
  """
  @spec validate(term()) :: {:ok, [Blocks.block()]} | {:error, [String.t()]}
  def validate(content) when is_list(content) do
    errors =
      content
      |> Enum.with_index()
      |> Enum.flat_map(fn {block, index} -> validate_block(block, index) end)

    case errors do
      [] -> {:ok, Blocks.normalize(content)}
      errors -> {:error, errors}
    end
  end

  def validate(_content), do: {:error, ["Content must be an array of blocks"]}

  defp validate_block(%{"type" => type} = block, index) when is_map_key(@schemas, type) do
    block
    |> SchemaValidator.validate(Map.fetch!(@schemas, type), @definitions)
    |> Enum.map(&"Block #{index} (#{type}): #{format_error(&1)}")
  end

  defp validate_block(block, index) do
    type = if is_map(block), do: Map.get(block, "type")

    [
      "Block #{index}: unknown or missing type '#{type_label(type)}'. " <>
        "Valid types: #{Enum.join(@types, ", ")}"
    ]
  end

  defp type_label(nil), do: ""
  defp type_label(type) when is_binary(type) or is_number(type), do: to_string(type)
  defp type_label(type), do: Jason.encode!(type)

  defp format_error(%{type: "required", missing_keys: missing}),
    do: "missing required fields: #{Enum.join(missing, ", ")}"

  defp format_error(%{type: "const", pointer: path}), do: "#{path} has invalid value"

  defp format_error(%{type: "enum", pointer: path, enum: enum}),
    do: "#{path} must be one of: #{Enum.join(enum, ", ")}"

  defp format_error(%{pointer: "", message: message}), do: message
  defp format_error(%{pointer: path, message: message}), do: "#{path} #{message}"
end
