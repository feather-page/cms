module Api
  module V1
    class BaseController < ActionController::API
      include ActionView::Layouts
      include Pundit::Authorization
      include Pagy::Method

      API_PAGY_DEFAULTS = { page_key: :p }.freeze

      before_action :force_json_format
      before_action :authenticate_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

      private

      def force_json_format
        request.format = :json
      end

      def current_user
        @current_user ||= @api_token&.user
      end

      def current_site
        @current_site ||= begin
          site = policy_scope(Site).find_by!(public_id: params[:site_id])
          authorize(site, :show?)
          site
        end
      end

      def authenticate_api_token!
        token_string = request.headers["Authorization"]&.delete_prefix("Bearer ")
        @api_token = ApiToken.authenticate(token_string)
        render_unauthorized unless @api_token
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def render_forbidden
        render json: { error: "Forbidden" }, status: :forbidden
      end

      def render_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def render_validation_errors(record)
        render json: { error: "Validation failed", details: record.errors.messages },
               status: :unprocessable_content
      end

      def render_content_errors(errors)
        render json: { error: "Content validation failed", details: { content: errors } },
               status: :unprocessable_content
      end

      def resolve_image_ids!(permitted_params)
        %i[header_image_id thumbnail_image_id].each do |key|
          next if permitted_params[key].blank?

          image = current_site.images.find_by(public_id: permitted_params[key])
          permitted_params[key] = image&.id
        end
        permitted_params
      end

      def extract_content(resource_key)
        raw_content = params.dig(resource_key, :content)
        return nil if raw_content.blank?
        return nil unless raw_content.is_a?(Array)

        raw_content.map do |block|
          block.respond_to?(:to_unsafe_h) ? block.to_unsafe_h : block.to_h
        end
      end

      def validate_and_normalize_content!(content)
        return [] if content.blank?

        validator = Blocks::ContentValidator.new(content)

        unless validator.valid?
          render_content_errors(validator.errors)
          return nil
        end

        validator.normalized_content
      end
    end
  end
end
