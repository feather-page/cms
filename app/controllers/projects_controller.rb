class ProjectsController < ApplicationController
  before_action :set_project, only: %i[edit update destroy]

  def index
    @projects = current_site.projects.ordered
  end

  def new
    @project = current_site.projects.new
  end

  def edit
    @project = set_project
  end

  def create
    @project = current_site.projects.new(project_params)

    if @project.save
      turbo_redirect_to site_projects_path(current_site), notice: t(".notice")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @project.update(project_params)
      turbo_redirect_to site_projects_path(current_site), notice: t(".notice")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @project.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end

  private

  def set_site
    @project&.site || super
  end

  def set_project
    @project = policy_scope(Project).find_by(public_id: params[:id])
    authorize @project
  end

  def project_params
    params.expect(
      project: [
        :title, :slug, :company, :period, :started_at, :ended_at, :status,
        :role, :short_description, :project_type, :emoji, :header_image_id,
        :content, { links: [%i[label url]] }
      ]
    )
  end
end
