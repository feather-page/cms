defmodule Feather.Fediverse.Follower do
  @moduledoc """
  An account that follows a site (`Feather.Fediverse.Inbox`), with the id
  of the `Follow` it sent, which its `Undo` may name.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_followers" do
    field :follow_id, :string

    belongs_to :site, Feather.Sites.Site
    belongs_to :remote_account, Feather.Fediverse.RemoteAccount

    timestamps()
  end
end
