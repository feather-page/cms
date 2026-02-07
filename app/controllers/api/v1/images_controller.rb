module Api
  module V1
    class ImagesController < BaseController
      def show
        image = current_site.images.find_by!(public_id: params[:id])
        render json: { data: serialize_image(image) }
      end

      def create
        url = params.require(:url)
        checked = ExternalUrlChecker.new(url).check!
        image = RemoteImageCreator.new(current_site, nil).create_from(checked)
        if image
          render json: { data: serialize_image(image) }, status: :created
        else
          render json: { error: "Image creation failed" }, status: :unprocessable_content
        end
      rescue ExternalUrlChecker::Error, RemoteImageCreator::Error => e
        render json: { error: e.message }, status: :unprocessable_content
      end
    end
  end
end
