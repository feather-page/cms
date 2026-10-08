defmodule Feather.Sites.SocialMediaLink do
  @moduledoc """
  A link from a site to one of its owner's social media profiles.
  """
  use Feather.Schema

  alias Feather.Sites.SocialMediaService

  @type t :: %__MODULE__{}

  schema "social_media_links" do
    field :name, :string
    field :url, :string
    field :icon, :string

    belongs_to :site, Feather.Sites.Site

    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:name, :url, :icon])
    |> validate_required([:name, :url, :icon])
    |> validate_inclusion(:icon, SocialMediaService.icons())
  end

  @doc "The SVG markup of the link's icon."
  def svg(%__MODULE__{icon: icon}), do: SocialMediaService.svg(icon)
end
