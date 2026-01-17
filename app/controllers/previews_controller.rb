class PreviewsController < ApplicationController
  skip_after_action :verify_pundit_checked

  def show
    authorize deployment_target, :show?, policy_class: PreviewPolicy

    send_preview_file
  end

  private

  def deployment_target
    @deployment_target ||= DeploymentTarget.find(params[:deployment_target_id])
  end

  def requested_path
    return "index.html" if params[:path].blank?

    path = params[:path]
    path = "#{path}.#{params[:format]}" if params[:format].present?
    path
  end

  def file_path
    path = File.join(deployment_target.source_dir, requested_path)
    return path if File.file?(path)

    index_path = File.join(path, "index.html")
    return index_path if File.file?(index_path)

    path
  end

  def send_preview_file
    return head(:forbidden) unless safe_path?
    return head(:not_found) unless File.exist?(file_path)

    send_file(file_path, disposition: :inline)
  end

  def safe_path?
    expanded = File.expand_path(file_path)
    expanded.start_with?(File.expand_path(deployment_target.source_dir))
  end
end
