require "rails_helper"

RSpec.describe SchemaValidator do
  describe ".validate" do
    it "returns empty array for valid data" do
      schema = { "type" => "object", "required" => ["name"], "properties" => { "name" => { "type" => "string" } } }
      errors = described_class.validate({ "name" => "test" }, schema)

      expect(errors).to be_empty
    end

    context "with type validation" do
      it "validates string type" do
        errors = described_class.validate(42, { "type" => "string" })

        expect(errors.first["type"]).to eq("type")
      end

      it "validates integer type" do
        errors = described_class.validate("hi", { "type" => "integer" })

        expect(errors.first["type"]).to eq("type")
      end

      it "validates number type accepts integers" do
        errors = described_class.validate(42, { "type" => "number" })

        expect(errors).to be_empty
      end

      it "validates boolean type" do
        errors = described_class.validate("yes", { "type" => "boolean" })

        expect(errors.first["type"]).to eq("type")
        expect(described_class.validate(true, { "type" => "boolean" })).to be_empty
        expect(described_class.validate(false, { "type" => "boolean" })).to be_empty
      end

      it "validates array type" do
        errors = described_class.validate("not array", { "type" => "array" })

        expect(errors.first["type"]).to eq("type")
      end

      it "validates null type" do
        expect(described_class.validate(nil, { "type" => "null" })).to be_empty
        expect(described_class.validate("x", { "type" => "null" }).first["type"]).to eq("type")
      end

      it "validates union types like ['string', 'null']" do
        schema = { "type" => %w[string null] }

        expect(described_class.validate("hello", schema)).to be_empty
        expect(described_class.validate(nil, schema)).to be_empty
        expect(described_class.validate(42, schema).first["type"]).to eq("type")
      end
    end

    context "with const validation" do
      it "accepts matching const value" do
        errors = described_class.validate("paragraph", { "type" => "string", "const" => "paragraph" })

        expect(errors).to be_empty
      end

      it "rejects non-matching const value" do
        errors = described_class.validate("header", { "type" => "string", "const" => "paragraph" })

        expect(errors.first["type"]).to eq("const")
      end
    end

    context "with enum validation" do
      it "accepts valid enum value" do
        errors = described_class.validate(2, { "type" => "integer", "enum" => [2, 3, 4] })

        expect(errors).to be_empty
      end

      it "rejects invalid enum value" do
        errors = described_class.validate(1, { "type" => "integer", "enum" => [2, 3, 4] })

        expect(errors.first["type"]).to eq("enum")
        expect(errors.first["schema"]["enum"]).to eq([2, 3, 4])
      end
    end

    context "with required fields" do
      it "reports missing required fields" do
        schema = { "type" => "object", "required" => %w[a b], "properties" => {} }
        errors = described_class.validate({ "a" => 1 }, schema)

        expect(errors.first["type"]).to eq("required")
        expect(errors.first["details"]["missing_keys"]).to eq(["b"])
      end
    end

    context "with additionalProperties: false" do
      it "rejects unexpected properties" do
        schema = {
          "type" => "object",
          "additionalProperties" => false,
          "properties" => { "name" => { "type" => "string" } }
        }
        errors = described_class.validate({ "name" => "ok", "extra" => "bad" }, schema)

        expect(errors.first["type"]).to eq("additionalProperties")
      end
    end

    context "with additionalProperties as schema" do
      it "validates additional properties against the schema" do
        schema = {
          "type" => "object",
          "additionalProperties" => { "type" => "string" }
        }

        expect(described_class.validate({ "x" => "ok" }, schema)).to be_empty
        expect(described_class.validate({ "x" => 42 }, schema).first["type"]).to eq("type")
      end
    end

    context "with nested array items" do
      it "validates each item against the items schema" do
        schema = { "type" => "array", "items" => { "type" => "string" } }
        errors = described_class.validate(["ok", 42, "fine"], schema)

        expect(errors.size).to eq(1)
        expect(errors.first["data_pointer"]).to eq("/1")
      end
    end

    context "with nested properties" do
      it "validates nested object properties" do
        schema = {
          "type" => "object",
          "properties" => {
            "data" => {
              "type" => "object",
              "required" => ["id"],
              "properties" => { "id" => { "type" => "string" } }
            }
          }
        }
        errors = described_class.validate({ "data" => {} }, schema)

        expect(errors.first["data_pointer"]).to eq("/data")
        expect(errors.first["details"]["missing_keys"]).to eq(["id"])
      end
    end

    context "with oneOf and discriminator" do
      let(:schema) do
        {
          "oneOf" => [
            {
              "type" => "object",
              "required" => %w[type text],
              "properties" => {
                "type" => { "type" => "string", "const" => "paragraph" },
                "text" => { "type" => "string" }
              }
            },
            {
              "type" => "object",
              "required" => %w[type code],
              "properties" => {
                "type" => { "type" => "string", "const" => "code" },
                "code" => { "type" => "string" }
              }
            }
          ],
          "discriminator" => { "propertyName" => "type" }
        }
      end

      it "validates against the discriminated schema" do
        errors = described_class.validate({ "type" => "paragraph", "text" => "hi" }, schema)

        expect(errors).to be_empty
      end

      it "reports errors for wrong discriminated schema" do
        errors = described_class.validate({ "type" => "paragraph" }, schema)

        expect(errors.first["type"]).to eq("required")
      end

      it "rejects data matching no schema" do
        errors = described_class.validate({ "type" => "unknown" }, schema)

        expect(errors.first["type"]).to eq("oneOf")
      end
    end

    context "with oneOf without discriminator" do
      it "accepts data matching any schema" do
        schema = {
          "oneOf" => [
            { "type" => "string" },
            { "type" => "integer" }
          ]
        }

        expect(described_class.validate("hello", schema)).to be_empty
        expect(described_class.validate(42, schema)).to be_empty
        expect(described_class.validate([], schema).first["type"]).to eq("oneOf")
      end
    end
  end
end
