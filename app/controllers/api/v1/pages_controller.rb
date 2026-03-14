module Api
  module V1
    class PagesController < BaseController
      before_action :set_page, only: %i[show update destroy]

      def index
        @pagy, @pages = pagy(current_site.pages, **API_PAGY_DEFAULTS)
      end

      def show; end

      def create
        content = validate_and_normalize_content!(extract_content(:page))
        return unless content

        @page = current_site.pages.new(resolve_image_ids!(page_params))
        @page.content = content

        if @page.save
          render :show, status: :created
        else
          render_validation_errors(@page)
        end
      end

      def update
        content = extract_content(:page)
        if content
          validated = validate_and_normalize_content!(content)
          return unless validated

          @page.content = validated
        end
        return render_validation_errors(@page) unless @page.update(resolve_image_ids!(page_params))

        render :show
      end

      def destroy
        if @page.destroy
          render json: { message: "Page deleted" }
        else
          render json: { error: @page.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_page
        @page = current_site.pages.find_by!(public_id: params[:id])
      end

      def page_params
        page = params.require(:page)
        page.permit(:title, :slug, :emoji, :page_type, :header_image_id, :thumbnail_image_id, :tags)
      end
    end
  end
end
