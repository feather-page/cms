module Api
  module V1
    class PagesController < BaseController
      before_action :set_page, only: %i[show update destroy]

      def index
        pages = current_site.pages
        render json: { data: pages.map { |page| serialize_page(page) } }
      end

      def show
        render json: { data: serialize_page(@page) }
      end

      def create
        content = validate_and_normalize_content!(extract_content(:page))
        return unless content

        @page = current_site.pages.new(page_params)
        @page.content = content

        if @page.save
          render json: { data: serialize_page(@page) }, status: :created
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
        return render_validation_errors(@page) unless @page.update(page_params)

        render json: { data: serialize_page(@page) }
      end

      def destroy
        @page.destroy!
        render json: { message: "Page deleted" }
      end

      private

      def set_page
        @page = current_site.pages.find_by!(public_id: params[:id])
      end

      def page_params
        page = params.require(:page)
        page.permit(:title, :slug, :emoji, :page_type, :header_image_id)
      end
    end
  end
end
