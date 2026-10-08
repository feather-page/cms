defmodule Feather.Sites.NavigationItem do
  @moduledoc """
  A page in the site's main navigation. Positions start at 1 and are kept
  contiguous by `Feather.Sites`.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "navigation_items" do
    field :position, :integer

    belongs_to :site, Feather.Sites.Site
    belongs_to :page, Feather.Content.Page

    timestamps()
  end
end
