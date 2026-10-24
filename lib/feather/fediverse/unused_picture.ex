defmodule Feather.Fediverse.UnusedPicture do
  @moduledoc """
  A kept picture of a reply's author, by its file name, that no approved
  reply of the site uses any more. It waits for the site's next
  successful deploy to be deleted (`Feather.Fediverse.Pictures`).
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_unused_pictures" do
    field :name, :string

    belongs_to :site, Feather.Sites.Site

    timestamps(updated_at: false)
  end
end
