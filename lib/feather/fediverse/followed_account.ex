defmodule Feather.Fediverse.FollowedAccount do
  @moduledoc """
  An account the site follows (`Feather.Fediverse.Following`), with the id
  of the `Follow` the site sent, which its `Accept`, `Reject` and the
  site's `Undo` name. It is accepted once its server sent `Accept`; until
  then the follow is requested. Its posts are the site's Timeline
  (`Feather.Fediverse.TimelinePost`) and go with it.
  """
  use Feather.Schema

  alias Feather.Fediverse.{RemoteAccount, TimelinePost}

  @type t :: %__MODULE__{}

  schema "fediverse_followed_accounts" do
    field :public_id, :string
    field :follow_id, :string
    field :accepted_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :remote_account, RemoteAccount
    has_many :timeline_posts, TimelinePost

    timestamps()
  end

  @doc "Returns true once the account's server accepted the follow."
  @spec accepted?(t()) :: boolean()
  def accepted?(%__MODULE__{accepted_at: accepted_at}), do: not is_nil(accepted_at)
end
