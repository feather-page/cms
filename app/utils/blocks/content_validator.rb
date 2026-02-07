module Blocks
  class ContentValidator
    attr_reader :errors, :normalized_content

    def initialize(content)
      @raw_content = content
      @errors = []
      @normalized_content = []
    end

    def valid?
      validate!
      @errors.empty?
    end

    private

    def validate!
      unless @raw_content.is_a?(Array)
        @errors << "Content must be an array of blocks"
        return
      end

      @raw_content.each_with_index do |block, index|
        validate_block(block, index)
      end
    end

    def validate_block(block, index)
      block = block.to_h.stringify_keys
      type = block["type"]
      return add_unknown_type_error(index, type) unless type.present? && schema_for(type)

      block_errors = validate_against_schema(block, type)
      block_errors.any? ? record_block_errors(block_errors, index, type) : normalize_block(block)
    end

    def validate_against_schema(block, type)
      schemer = JSONSchemer.schema(schema_for(type))
      schemer.validate(block).to_a
    end

    def add_unknown_type_error(index, type)
      @errors << "Block #{index}: unknown or missing type '#{type}'. Valid types: #{valid_types.join(', ')}"
    end

    def record_block_errors(block_errors, index, type)
      block_errors.each do |err|
        @errors << "Block #{index} (#{type}): #{format_error(err)}"
      end
    end

    def normalize_block(block)
      normalized = block.dup
      normalized["id"] ||= SecureRandom.alphanumeric(10)
      @normalized_content << normalized.symbolize_keys
    end

    def format_error(error)
      path = error["data_pointer"]
      case error["type"]
      when "required"
        missing = error.dig("details", "missing_keys")
        "missing required fields: #{missing&.join(', ')}"
      when "const" then "#{path} has invalid value"
      when "enum" then "#{path} must be one of: #{error.dig('schema', 'enum')&.join(', ')}"
      else "#{path} #{error['error'] || error['type']}"
      end
    end

    def schema_for(type)
      self.class.block_schemas[type]
    end

    def valid_types
      self.class.block_schemas.keys
    end

    class << self
      def block_schemas
        @block_schemas ||= load_block_schemas
      end

      def reset_schemas!
        @block_schemas = nil
      end

      private

      def load_block_schemas
        spec = YAML.load_file(Rails.root.join("docs/api/openapi.yml"))
        schemas = spec.dig("components", "schemas")
        mapping = schemas.dig("Block", "discriminator", "mapping") || {}

        mapping.each_with_object({}) do |(type_name, ref), result|
          schema_name = ref.split("/").last
          schema_data = schemas[schema_name]
          next unless schema_data

          result[type_name] = schema_data
        end
      end
    end
  end
end
