defmodule Feather.Content.SchemaValidator do
  @moduledoc """
  A small JSON Schema validator for the subset of JSON Schema used in
  `docs/api/openapi.yml` (port of Rails' `SchemaValidator`).

  Supported keywords: `type` (a name or a list of names), `const`, `enum`,
  `required`, `properties`, `additionalProperties` (`false` or a schema),
  `items`, `oneOf` (with an optional `discriminator`) and `$ref` to
  `#/components/schemas/<Name>`, resolved against the `definitions` map
  passed in. Everything else (`description`, `default`, `format`,
  `pattern`, ...) is ignored.

  Schemas are maps with string keys, like decoded JSON or YAML. Data is
  decoded JSON: maps with string keys, lists, strings, numbers, booleans
  and nil.

  Errors are maps with the JSON pointer of the offending value (`""` for
  the root), the failed keyword as `type` and a human readable `message`.
  `required` errors carry the missing keys, `enum` errors the allowed
  values.
  """

  @type schema :: map()
  @type error :: %{
          required(:pointer) => String.t(),
          required(:type) => String.t(),
          required(:message) => String.t(),
          optional(:missing_keys) => [String.t()],
          optional(:enum) => list()
        }

  @ref_prefix "#/components/schemas/"

  @doc """
  Validates `data` against `schema` and returns the list of errors (empty
  when valid). `definitions` maps schema names to schemas for `$ref`.
  """
  @spec validate(term(), schema(), %{optional(String.t()) => schema()}) :: [error()]
  def validate(data, schema, definitions \\ %{}) do
    validate(data, schema, "", definitions)
  end

  defp validate(data, %{"$ref" => ref}, path, defs) do
    validate(data, resolve(ref, defs), path, defs)
  end

  defp validate(data, %{"oneOf" => _} = schema, path, defs) do
    validate_one_of(data, schema, path, defs)
  end

  defp validate(data, schema, path, defs) do
    cond do
      not valid_type?(data, schema) ->
        expected = schema |> Map.fetch!("type") |> List.wrap() |> Enum.join("/")
        [error(path, "type", "expected #{expected}, got #{json_type(data)}")]

      Map.has_key?(schema, "const") and data != schema["const"] ->
        [error(path, "const", "has invalid value")]

      is_list(schema["enum"]) and data not in schema["enum"] ->
        [
          path
          |> error("enum", "must be one of: #{Enum.join(schema["enum"], ", ")}")
          |> Map.put(:enum, schema["enum"])
        ]

      is_map(data) ->
        validate_object(data, schema, path, defs)

      is_list(data) ->
        validate_array(data, schema, path, defs)

      true ->
        []
    end
  end

  defp resolve(@ref_prefix <> name = ref, defs) do
    case Map.fetch(defs, name) do
      {:ok, schema} -> schema
      :error -> raise ArgumentError, "unknown schema reference #{ref}"
    end
  end

  defp resolve(ref, _defs), do: raise(ArgumentError, "unsupported schema reference #{ref}")

  defp valid_type?(_data, schema) when not is_map_key(schema, "type"), do: true

  defp valid_type?(data, %{"type" => type}) do
    type |> List.wrap() |> Enum.any?(&type?(data, &1))
  end

  defp type?(data, "string"), do: is_binary(data)
  defp type?(data, "integer"), do: is_integer(data)
  defp type?(data, "number"), do: is_number(data)
  defp type?(data, "boolean"), do: is_boolean(data)
  defp type?(data, "array"), do: is_list(data)
  defp type?(data, "object"), do: is_map(data)
  defp type?(data, "null"), do: is_nil(data)
  defp type?(_data, _type), do: false

  @doc "The JSON type name of a decoded JSON value."
  @spec json_type(term()) :: String.t()
  def json_type(nil), do: "null"
  def json_type(data) when is_boolean(data), do: "boolean"
  def json_type(data) when is_integer(data), do: "integer"
  def json_type(data) when is_number(data), do: "number"
  def json_type(data) when is_binary(data), do: "string"
  def json_type(data) when is_list(data), do: "array"
  def json_type(data) when is_map(data), do: "object"
  def json_type(_data), do: "unknown"

  defp validate_object(data, schema, path, defs) do
    check_required(data, schema, path) ++
      check_properties(data, schema, path, defs) ++
      check_additional(data, schema, path, defs)
  end

  defp check_required(data, %{"required" => required}, path) do
    case Enum.reject(required, &Map.has_key?(data, &1)) do
      [] ->
        []

      missing ->
        [
          path
          |> error("required", "missing required fields: #{Enum.join(missing, ", ")}")
          |> Map.put(:missing_keys, missing)
        ]
    end
  end

  defp check_required(_data, _schema, _path), do: []

  defp check_properties(data, %{"properties" => properties}, path, defs) do
    properties
    |> Enum.sort_by(fn {key, _schema} -> key end)
    |> Enum.flat_map(fn {key, property_schema} ->
      case Map.fetch(data, key) do
        {:ok, value} -> validate(value, property_schema, "#{path}/#{key}", defs)
        :error -> []
      end
    end)
  end

  defp check_properties(_data, _schema, _path, _defs), do: []

  defp check_additional(data, %{"additionalProperties" => %{} = additional} = schema, path, defs) do
    known = Map.keys(schema["properties"] || %{})

    data
    |> Map.drop(known)
    |> Enum.sort()
    |> Enum.flat_map(fn {key, value} -> validate(value, additional, "#{path}/#{key}", defs) end)
  end

  defp check_additional(data, %{"additionalProperties" => false, "properties" => props}, path, _) do
    case data |> Map.keys() |> Enum.reject(&Map.has_key?(props, &1)) |> Enum.sort() do
      [] -> []
      extra -> [error(path, "additionalProperties", "unexpected: #{Enum.join(extra, ", ")}")]
    end
  end

  defp check_additional(_data, _schema, _path, _defs), do: []

  defp validate_array(data, %{"items" => items}, path, defs) do
    data
    |> Enum.with_index()
    |> Enum.flat_map(fn {value, index} -> validate(value, items, "#{path}/#{index}", defs) end)
  end

  defp validate_array(_data, _schema, _path, _defs), do: []

  defp validate_one_of(data, %{"oneOf" => schemas} = schema, path, defs) do
    schemas = Enum.map(schemas, &resolve_top(&1, defs))

    case discriminated_schema(data, schema, schemas) do
      nil ->
        if Enum.any?(schemas, &(validate(data, &1, path, defs) == [])) do
          []
        else
          [error(path, "oneOf", "does not match any schema")]
        end

      matched ->
        validate(data, matched, path, defs)
    end
  end

  defp resolve_top(%{"$ref" => ref}, defs), do: resolve_top(resolve(ref, defs), defs)
  defp resolve_top(schema, _defs), do: schema

  defp discriminated_schema(%{} = data, %{"discriminator" => %{"propertyName" => prop}}, schemas) do
    case Map.get(data, prop) do
      nil -> nil
      value -> Enum.find(schemas, &(get_in(&1, ["properties", prop, "const"]) == value))
    end
  end

  defp discriminated_schema(_data, _schema, _schemas), do: nil

  defp error(path, type, message), do: %{pointer: path, type: type, message: message}
end
