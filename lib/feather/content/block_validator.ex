defmodule Feather.Content.BlockValidator do
  @moduledoc """
  Validates content against the JSON Schema of each block type (port of
  Rails' `Blocks::ContentValidator`).

  Each block is checked against the schema of its `type`. Error messages
  name the block index and type so the sender (often an AI agent) can fix
  its input:

      Block 0: unknown or missing type 'fancy'. Valid types: paragraph, header, ...
      Block 0 (header): missing required fields: level
      Block 0 (header): /level must be one of: 2, 3, 4
      Block 1 (code): /code expected string, got integer

  Valid content is normalized with `Feather.Content.Blocks.normalize/1`:
  blocks without an `id` get a random 10 character alphanumeric one and
  defaults are filled in.
  """

  alias Feather.Content.{Blocks, SchemaValidator}

  @ref_list_item %{"$ref" => "#/$defs/ListItem"}
  @list_item_entry %{"oneOf" => [@ref_list_item, %{"type" => "string"}]}

  @id %{"type" => "string", "description" => "Unique block identifier, generated if left out"}
  @inline "inline HTML with only <b>, <i>, <u>, <code>, <br> and <a href>"

  @block_schemas [
    {"paragraph",
     %{
       "type" => "object",
       "required" => ["type", "text"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "paragraph"},
         "text" => %{"type" => "string", "description" => "The paragraph's text, " <> @inline}
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
         "text" => %{"type" => "string", "description" => "The header's text, " <> @inline},
         "level" => %{
           "type" => "integer",
           "enum" => [2, 3, 4],
           "description" => "Header level (H2, H3 or H4)"
         }
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
         "code" => %{"type" => "string", "description" => "Source code"},
         "language" => %{
           "type" => "string",
           "default" => "plaintext",
           "description" => "Programming language for syntax highlighting"
         }
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
         "image_id" => %{
           "type" => "string",
           "description" => "The id of one of the site's images"
         },
         "caption" => %{
           "type" => "string",
           "default" => "",
           "description" => "Optional caption, " <> @inline
         }
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
         "text" => %{"type" => "string", "description" => "The quote, " <> @inline},
         "caption" => %{
           "type" => "string",
           "description" => "Attribution or source, " <> @inline <> "; empty for none"
         }
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
         "style" => %{
           "type" => "string",
           "enum" => ["ul", "ol"],
           "default" => "ul",
           "description" => "List style: unordered (ul) or ordered (ol)"
         },
         "items" => %{
           "type" => "array",
           "items" => @list_item_entry,
           "description" =>
             "Nested list items, each with its own sub-items. A plain string is shorthand " <>
               "for an item without sub-items; results always give ListItem objects."
         }
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
           "items" => %{"type" => "array", "items" => %{"type" => "string"}},
           "description" => "Rows of cells, each " <> @inline
         },
         "with_headings" => %{
           "type" => "boolean",
           "default" => false,
           "description" => "Whether the first row of content holds the headings"
         }
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
         "service" => %{
           "type" => "string",
           "description" => "Embed service name, such as youtube or vimeo"
         },
         "source" => %{
           "type" => "string",
           "description" => "Original URL of the embedded content"
         },
         "embed" => %{"type" => "string", "description" => "Embed URL for the iframe"},
         "width" => %{
           "type" => ["integer", "null"],
           "description" => "Embed width in pixels; the theme decides if left out"
         },
         "height" => %{
           "type" => ["integer", "null"],
           "description" => "Embed height in pixels; the theme decides if left out"
         },
         "caption" => %{
           "type" => "string",
           "default" => "",
           "description" => "Optional caption, " <> @inline
         }
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
         "book_public_id" => %{
           "type" => "string",
           "description" => "The id of a book on the site's bookshelf"
         },
         "title" => %{"type" => "string", "description" => "Filled from the bookshelf"},
         "author" => %{"type" => "string", "description" => "Filled from the bookshelf"},
         "cover_url" => %{"type" => "string", "description" => "Filled from the bookshelf"},
         "emoji" => %{"type" => "string", "description" => "Filled from the bookshelf"}
       }
     }},
    {"diagram",
     %{
       "type" => "object",
       "required" => ["type", "code"],
       "additionalProperties" => false,
       "properties" => %{
         "id" => @id,
         "type" => %{"type" => "string", "const" => "diagram"},
         "code" => %{
           "type" => "string",
           "description" =>
             "Diagram source in D2 (https://d2lang.com) without icons, links or imports, " <>
               "rendered to an SVG image on the published site"
         },
         "caption" => %{
           "type" => "string",
           "default" => "",
           "description" => "Optional caption, also the image's alternative text"
         }
       }
     }}
  ]

  @definitions %{
    "ListItem" => %{
      "type" => "object",
      "required" => ["content", "items"],
      "properties" => %{
        "content" => %{"type" => "string", "description" => "The item's text, " <> @inline},
        "items" => %{
          "type" => "array",
          "items" => @list_item_entry,
          "description" =>
            "Nested sub-items; a plain string is shorthand for an item without sub-items"
        }
      }
    }
  }

  @types Enum.map(@block_schemas, &elem(&1, 0))
  @schemas Map.new(@block_schemas)

  @doc "The block types, in the order error messages list them."
  @spec types() :: [String.t()]
  def types, do: @types

  @doc "The block schemas by type."
  @spec schemas() :: %{String.t() => map()}
  def schemas, do: @schemas

  @doc "The schemas the block schemas refer to with `$ref`, by name."
  @spec definitions() :: %{String.t() => map()}
  def definitions, do: @definitions

  @doc """
  The JSON Schema of content for clients: an array of blocks, each
  matching the schema of its type. Its `$ref`s point into `definitions/0`
  as `#/$defs/<name>`.
  """
  @spec content_schema() :: map()
  def content_schema do
    %{"type" => "array", "items" => %{"anyOf" => Enum.map(@types, &Map.fetch!(@schemas, &1))}}
  end

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
