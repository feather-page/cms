defmodule Feather.Content.Projects do
  @moduledoc """
  The projects of a site, called through `Feather.Content`.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.{Project, Saving}
  alias Feather.Repo
  alias Feather.Sites.Site

  @doc """
  Lists the projects of the scope's site, most recently started first, with
  their published version preloaded.
  """
  @spec list_projects(Scope.t()) :: [Project.t()]
  def list_projects(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from p in Project,
        where: p.site_id == ^site_id,
        order_by: [desc: p.started_at, asc: p.title],
        preload: :published_version
    )
  end

  @doc """
  Gets a project of the scope's site by public id. Raises if not found.
  """
  @spec get_project!(Scope.t(), String.t()) :: Project.t()
  def get_project!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from p in Project, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc """
  Gets a project of the scope's site by public id, or nil.
  """
  @spec get_project(Scope.t(), String.t()) :: Project.t() | nil
  def get_project(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one(from p in Project, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc "Creates a project in the scope's site."
  @spec create_project(Scope.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(%Scope{site: %Site{id: site_id}} = scope, attrs) do
    %Project{site_id: site_id}
    |> Project.create_changeset(attrs)
    |> Saving.save_with_images(scope, :project_id, [])
  end

  @doc "Updates a project."
  @spec update_project(Scope.t(), Project.t(), map()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(
        %Scope{site: %Site{id: site_id}} = scope,
        %Project{site_id: site_id} = project,
        attrs
      ) do
    project
    |> Project.changeset(attrs)
    |> Saving.save_with_images(scope, :project_id, [])
  end

  @doc "Deletes a project and the images it owns that nothing else uses."
  @spec delete_project(Scope.t(), Project.t()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def delete_project(
        %Scope{site: %Site{id: site_id}} = scope,
        %Project{site_id: site_id} = project
      ) do
    Saving.delete_with_images(scope, project, :project_id)
  end

  @doc "Returns a changeset for a project form."
  @spec change_project(Scope.t(), Project.t(), map()) :: Ecto.Changeset.t()
  def change_project(%Scope{}, %Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end
end
