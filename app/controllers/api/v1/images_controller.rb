module Api
  module V1
    class ImagesController < BaseController
      def show
        @image = current_site.images.find_by!(public_id: params[:id])
      end

      def create
        if params[:file].present?
          create_image_from_file
        elsif params[:url].present?
          create_image_from_url
        else
          render json: { error: "Either file or url parameter is required" }, status: :unprocessable_content
        end
      end

      private

      def create_image_from_file
        @image = current_site.images.build(file: params[:file])

        if @image.save
          render :show, status: :created
        else
          render_validation_errors(@image)
        end
      end

      def create_image_from_url
        url = params.require(:url)
        checked = ExternalUrlChecker.new(url).check!
        @image = RemoteImageCreator.new(current_site, nil).create_from(checked)

        if @image
          render :show, status: :created
        else
          render json: { error: "Image creation failed" }, status: :unprocessable_content
        end
      rescue ExternalUrlChecker::Error, RemoteImageCreator::Error => e
        render json: { error: e.message }, status: :unprocessable_content
      end
    end
  end
end
