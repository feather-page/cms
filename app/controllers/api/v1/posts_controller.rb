module Api
  module V1
    class PostsController < BaseController
      before_action :set_post, only: %i[show update destroy]

      def index
        @posts = current_site.posts.latest
      end

      def show; end

      def create
        content = validate_and_normalize_content!(extract_content(:post))
        return unless content

        @post = current_site.posts.new(post_params)
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
        return render_validation_errors(@post) unless @post.update(post_params)

        render :show
      end

      def destroy
        @post.destroy!
        render json: { message: "Post deleted" }
      end

      private

      def set_post
        @post = current_site.posts.find_by!(public_id: params[:id])
      end

      def post_params
        post = params.require(:post)
        post.permit(:title, :slug, :draft, :emoji, :publish_at, :header_image_id)
      end
    end
  end
end
