module Api
  module V1
    class SchemaController < BaseController
      def blocks
        render json: { block_types: Blocks::ContentValidator.block_schemas }
      end
    end
  end
end
