module ApiHelpers
  def api_headers(token: nil)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token
    headers
  end

  def json_response
    JSON.parse(response.body)
  end

  def openapi_spec
    @openapi_spec ||= YAML.load_file(Rails.root.join("docs/api/openapi.yml"))
  end

  def resolve_ref(ref)
    path = ref.delete_prefix("#/").split("/")
    openapi_spec.dig(*path)
  end

  def resolve_schema(schema)
    return resolve_ref(schema["$ref"]).then { |s| resolve_schema(s) } if schema["$ref"]
    return resolve_one_of(schema) if schema["oneOf"]
    return resolve_items(schema) if schema["items"]
    return resolve_properties(schema) if schema["properties"]
    return resolve_additional(schema) if schema["additionalProperties"].is_a?(Hash)

    schema
  end

  def schema_for_response(path, method, status)
    path_spec = openapi_spec.dig("paths", path)
    raise "No path spec for #{path}" unless path_spec

    operation = path_spec[method]
    raise "No #{method} operation for #{path}" unless operation

    response_spec = operation.dig("responses", status.to_s)
    raise "No #{status} response for #{method} #{path}" unless response_spec

    raw_schema = response_spec.dig("content", "application/json", "schema")
    raise "No schema for #{method} #{path} #{status}" unless raw_schema

    resolve_schema(raw_schema)
  end

  def validate_response_schema!(path, method, status)
    schema = schema_for_response(path, method, status)
    errors = SchemaValidator.validate(json_response, schema)

    return if errors.empty?

    error_messages = errors.map { |e| "#{e['data_pointer']}: #{e['error'] || e['type']}" }
    msg = "Response does not match OpenAPI schema for #{method.upcase} #{path} (#{status}):\n"
    msg += "#{error_messages.join("\n")}\n\nResponse body: #{response.body}"
    raise msg
  end

  private

  def resolve_one_of(schema)
    schema.merge("oneOf" => schema["oneOf"].map { |s| resolve_schema(s) })
  end

  def resolve_items(schema)
    schema.merge("items" => resolve_schema(schema["items"]))
  end

  def resolve_properties(schema)
    schema.merge("properties" => schema["properties"].transform_values { |v| resolve_schema(v) })
  end

  def resolve_additional(schema)
    schema.merge("additionalProperties" => resolve_schema(schema["additionalProperties"]))
  end
end
