class PreviewsController < ApplicationController
  skip_after_action :verify_pundit_checked

  before_action :set_deployment_target

  def show
    Hugo::BuildJob.perform_now(@deployment_target, preview: true)
    serve_static_file
  end

  private

  def set_deployment_target
    @deployment_target = current_user.sites
      .joins(:deployment_targets)
      .find_by!(deployment_targets: { public_id: params[:deployment_target_id] })
      .deployment_targets
      .find_by!(public_id: params[:deployment_target_id])
  end

  def serve_static_file
    path = params[:path] || ""
    path = "#{path}.#{params[:format]}" if params[:format].present?
    file_path = resolve_file_path(path)

    if file_path && File.exist?(file_path)
      content_type = Rack::Mime.mime_type(File.extname(file_path), "text/html")
      send_file file_path, type: content_type, disposition: "inline"
    else
      head :not_found
    end
  end

  def resolve_file_path(path)
    preview_root = @deployment_target.preview_output_path
    candidates = [
      preview_root.join(path),
      preview_root.join(path, "index.html")
    ]
    found = candidates.find { |p| p.cleanpath.to_s.start_with?(preview_root.to_s) && File.file?(p) }
    found&.to_s
  end
end
