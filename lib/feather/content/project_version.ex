defmodule Feather.Content.ProjectVersion do
  @moduledoc """
  A published state of a project, see `Feather.Content.publish/2`.
  """
  use Feather.Schema

  alias Feather.Content.BlocksType

  @type t :: %__MODULE__{}

  @copied_fields [
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
    :links,
    :header_image_id,
    :thumbnail_image_id
  ]

  schema "project_versions" do
    field :number, :integer
    field :published_at, :utc_datetime_usec
    field :title, :string
    field :slug, :string
    field :emoji, :string
    field :tags, :string
    field :content, BlocksType, default: []
    field :short_description, :string
    field :company, :string
    field :role, :string
    field :period, :string
    field :started_at, :date
    field :ended_at, :date
    field :status, :string
    field :project_type, :string

    embeds_many :links, Feather.Content.Project.Link

    belongs_to :project, Feather.Content.Project
    belongs_to :published_by, Feather.Accounts.User
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
  end

  @doc "The project's fields a version copies."
  def copied_fields, do: @copied_fields
end
