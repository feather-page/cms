module Api
  module V1
    class PostsController < BaseController
      before_action :set_post, only: %i[show update destroy]

      def index
        @pagy, @posts = pagy(current_site.posts.latest, **API_PAGY_DEFAULTS)
      end

      def show; end

      def create
        content = validate_and_normalize_content!(extract_content(:post))
        return unless content

        @post = current_site.posts.new(resolve_image_ids!(post_params))
        @post.content = content

        if @post.save
          render :show, status: :created
        else
          render_validation_errors(@post)
        end
      end

      def update
        content = extract_content(:post)
        if content
          validated = validate_and_normalize_content!(content)
          return unless validated

          @post.content = validated
        end
        return render_validation_errors(@post) unless @post.update(resolve_image_ids!(post_params))

        render :show
      end

      def destroy
        if @post.destroy
          render json: { message: "Post deleted" }
        else
          render json: { error: @post.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_post
        @post = current_site.posts.find_by!(public_id: params[:id])
      end

      def post_params
        post = params.require(:post)
        post.permit(:title, :slug, :draft, :emoji, :publish_at, :header_image_id, :thumbnail_image_id, :tags)
      end
    end
  end
end
