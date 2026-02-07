module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization

      before_action :authenticate_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

      private

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
        @api_token = ApiToken.find_by(token: token_string) if token_string.present?
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

      def serialize_post(post)
        {
          id: post.public_id, title: post.title,
          slug: post.slug, emoji: post.emoji, draft: post.draft,
          publish_at: post.publish_at&.iso8601,
          content: post.content.presence || [],
          header_image_id: post.header_image&.public_id,
          created_at: post.created_at.iso8601,
          updated_at: post.updated_at.iso8601
        }
      end

      def serialize_page(page)
        {
          id: page.public_id, title: page.title,
          slug: page.slug, emoji: page.emoji,
          page_type: page.page_type,
          content: page.content.presence || [],
          header_image_id: page.header_image&.public_id,
          created_at: page.created_at.iso8601,
          updated_at: page.updated_at.iso8601
        }
      end

      def serialize_image(image)
        {
          id: image.public_id, source_url: image.source_url,
          created_at: image.created_at.iso8601,
          updated_at: image.updated_at.iso8601
        }
      end
    end
  end
end
