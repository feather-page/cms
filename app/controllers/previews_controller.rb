# frozen_string_literal: true

class PreviewsController < ApplicationController
  skip_after_action :verify_pundit_checked

  def show
    authorize deployment_target, :show?, policy_class: PreviewPolicy

    file_path = resolve_file_path
    return head(:not_found) unless file_path && File.exist?(file_path)

    send_file(file_path, type: content_type_for(file_path), disposition: :inline)
  end

  private

  def deployment_target
    @deployment_target ||= DeploymentTarget.find(params[:deployment_target_id])
  end

  def requested_path
    @requested_path ||= params[:path].to_s
  end

  def source_dir
    deployment_target.source_dir
  end

  def resolve_file_path
    path = requested_path.presence || "index.html"

    # Try the exact path first
    full_path = safe_join(source_dir, path)
    return full_path if full_path && File.file?(full_path)

    # Try with index.html appended (directory-style URLs)
    index_path = safe_join(source_dir, "#{path.chomp('/')}/index.html")
    return index_path if index_path && File.file?(index_path)

    nil
  end

  def safe_join(base, relative)
    joined = File.expand_path(relative, base)
    return nil unless joined.start_with?(File.expand_path(base))

    joined
  end

  def content_type_for(path)
    case File.extname(path).downcase
    when ".html" then "text/html; charset=utf-8"
    when ".css" then "text/css; charset=utf-8"
    when ".js" then "application/javascript; charset=utf-8"
    when ".xml" then "application/xml; charset=utf-8"
    when ".json" then "application/json; charset=utf-8"
    when ".webp" then "image/webp"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".png" then "image/png"
    when ".svg" then "image/svg+xml"
    when ".txt" then "text/plain; charset=utf-8"
    else "application/octet-stream"
    end
  end
end
