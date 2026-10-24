defmodule Feather.Fediverse.ReceivedActivity do
  @moduledoc """
  An activity a site's inbox took in from an actor (`Feather.Fediverse.Inbox`).
  Until it is processed it keeps the activity's JSON, stored encrypted,
  and when it is tried next; once processed only its id, kept 30 days so
  that the same activity again is not processed twice.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_received_activities" do
    field :activity_id, :string
    field :payload, Feather.Encrypted.Binary, redact: true
    field :attempts, :integer, default: 0
    field :next_attempt_at, :utc_datetime_usec
    field :claimed_until, :utc_datetime_usec
    field :processed_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :remote_account, Feather.Fediverse.RemoteAccount

    timestamps()
  end
end
