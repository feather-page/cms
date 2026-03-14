class SchemaValidator
  TYPE_CHECKS = {
    "string" => ->(d) { d.is_a?(String) },
    "integer" => ->(d) { d.is_a?(Integer) },
    "number" => ->(d) { d.is_a?(Numeric) },
    "boolean" => ->(d) { [true, false].include?(d) },
    "array" => ->(d) { d.is_a?(Array) },
    "object" => ->(d) { d.is_a?(Hash) },
    "null" => ->(d) { d.nil? }
  }.freeze

  def self.validate(data, schema)
    new.validate(data, schema, "")
  end

  def validate(data, schema, path)
    return validate_one_of(data, schema, path) if schema["oneOf"]
    return type_error(data, schema, path) unless valid_type?(data, schema)
    return [error(path, "const", "has invalid value")] if invalid_const?(data, schema)
    return enum_error(data, schema, path) if invalid_enum?(data, schema)

    validate_children(data, schema, path)
  end

  private

  def valid_type?(data, schema)
    return true unless schema["type"]

    Array(schema["type"]).any? { |t| TYPE_CHECKS[t]&.call(data) }
  end

  def invalid_const?(data, schema)
    schema.key?("const") && data != schema["const"]
  end

  def invalid_enum?(data, schema)
    schema["enum"]&.exclude?(data)
  end

  def type_error(data, schema, path)
    expected = Array(schema["type"]).join("/")
    [error(path, "type", "expected #{expected}, got #{data.class}")]
  end

  def enum_error(_data, schema, path)
    [error(path, "enum", "must be one of: #{schema['enum'].join(', ')}", schema: schema)]
  end

  def validate_children(data, schema, path)
    errors = []
    errors.concat(validate_object(data, schema, path)) if data.is_a?(Hash)
    errors.concat(validate_array(data, schema, path)) if data.is_a?(Array)
    errors
  end

  def validate_object(data, schema, path)
    errors = []
    errors.concat(check_required(data, schema, path))
    errors.concat(check_properties(data, schema, path))
    errors.concat(check_additional(data, schema, path))
    errors
  end

  def check_required(data, schema, path)
    return [] unless schema["required"]

    missing = schema["required"].reject { |k| data.key?(k) }
    return [] if missing.empty?

    [error(path, "required", "missing required fields: #{missing.join(', ')}",
           details: { "missing_keys" => missing })]
  end

  def check_properties(data, schema, path)
    return [] unless schema["properties"]

    schema["properties"].each_with_object([]) do |(key, prop_schema), errors|
      next unless data.key?(key)

      errors.concat(validate(data[key], prop_schema, "#{path}/#{key}"))
    end
  end

  def check_additional(data, schema, path)
    return check_additional_schema(data, schema, path) if schema["additionalProperties"].is_a?(Hash)
    return [] unless schema["additionalProperties"] == false && schema["properties"]

    extra = data.keys - schema["properties"].keys
    extra.empty? ? [] : [error(path, "additionalProperties", "unexpected: #{extra.join(', ')}")]
  end

  def check_additional_schema(data, schema, path)
    known = schema["properties"]&.keys || []
    (data.keys - known).each_with_object([]) do |key, errors|
      errors.concat(validate(data[key], schema["additionalProperties"], "#{path}/#{key}"))
    end
  end

  def validate_array(data, schema, path)
    return [] unless schema["items"]

    data.each_index.with_object([]) do |i, errors|
      errors.concat(validate(data[i], schema["items"], "#{path}/#{i}"))
    end
  end

  def validate_one_of(data, schema, path)
    matched = find_discriminated_schema(data, schema)
    return validate(data, matched, path) if matched

    schema["oneOf"].each { |sub| return [] if validate(data, sub, path).empty? }
    [error(path, "oneOf", "does not match any schema")]
  end

  def find_discriminated_schema(data, schema)
    return unless schema["discriminator"] && data.is_a?(Hash)

    prop = schema["discriminator"]["propertyName"]
    type_val = data[prop]
    schema["oneOf"].find { |s| s.dig("properties", prop, "const") == type_val }
  end

  def error(path, type, message, details: nil, schema: nil)
    err = { "data_pointer" => path, "type" => type, "error" => message }
    err["details"] = details if details
    err["schema"] = schema if schema
    err
  end
end
