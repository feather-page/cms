defmodule Feather.Content.Project do
  @moduledoc """
  A portfolio entry describing work by the site owner. Projects are
  exported under `projects/<slug>/`, so their slugs are exempt from the
  reserved path check.
  """
  use Feather.Schema

  alias Feather.Content.{BlocksType, Slug, Tags}

  @type t :: %__MODULE__{}

  @statuses ~w(ongoing completed paused abandoned)
  @project_types ~w(professional personal open_source freelance)

  schema "projects" do
    field :public_id, :string
    field :title, :string
    field :slug, :string
    field :emoji, :string
    field :tags, :string
    field :content, BlocksType, default: []
    field :lock_version, :integer, default: 1
    field :short_description, :string
    field :company, :string
    field :role, :string
    field :period, :string
    field :started_at, :date
    field :ended_at, :date
    field :status, :string, default: "ongoing"
    field :project_type, :string, default: "professional"

    embeds_many :links, Link, on_replace: :delete, primary_key: false do
      field :label, :string
      field :url, :string
    end

    belongs_to :site, Feather.Sites.Site
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
    belongs_to :published_version, Feather.Content.ProjectVersion
    has_many :images, Feather.Media.Image

    timestamps()
  end

  @doc "The valid statuses."
  def statuses, do: @statuses

  @doc "The valid project types."
  def project_types, do: @project_types

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :title,
      :slug,
      :emoji,
      :tags,
      :content,
      :short_description,
      :company,
      :role,
      :period,
      :started_at,
      :ended_at,
      :status,
      :project_type,
      :header_image_id,
      :thumbnail_image_id
    ])
    |> cast_embed(:links,
      with: &link_changeset/2,
      sort_param: :links_sort,
      drop_param: :links_drop
    )
    |> Feather.Validations.trim_to_nil(:emoji)
    |> Slug.cast_slug(required: true, own_namespace: true)
    |> Tags.cast_tags()
    |> validate_required([:title, :short_description, :started_at, :status, :project_type])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:project_type, @project_types)
    |> Feather.Validations.validate_emoji(:emoji)
    |> Slug.unsafe_validate_unique()
    |> unique_constraint([:site_id, :slug], error_key: :slug, message: "has already been taken")
  end

  @doc false
  def create_changeset(project, attrs) do
    project
    |> changeset(attrs)
    |> Feather.PublicId.put_new()
  end

  defp link_changeset(link, attrs) do
    link
    |> cast(attrs, [:label, :url])
    |> validate_required([:label, :url])
  end

  @doc """
  The period shown for a project: the free text `period` if set, otherwise
  `"MM.YYYY - MM.YYYY"` with `"ongoing"` as the end of unfinished projects.
  """
  @spec display_period(t()) :: String.t()
  def display_period(%__MODULE__{period: period} = project) do
    if is_binary(period) and String.trim(period) != "" do
      period
    else
      start = Calendar.strftime(project.started_at, "%m.%Y")

      finish =
        if project.ended_at, do: Calendar.strftime(project.ended_at, "%m.%Y"), else: "ongoing"

      "#{start} - #{finish}"
    end
  end
end
