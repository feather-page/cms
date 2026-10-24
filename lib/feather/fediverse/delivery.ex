defmodule Feather.Fediverse.Delivery do
  @moduledoc """
  An activity on its way to one inbox (`Feather.Fediverse.Deliveries`).
  The payload is the activity's JSON, stored encrypted and not loaded
  with the delivery; the inbox, its host and the times stay in clear text.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_deliveries" do
    field :inbox, :string
    field :host, :string
    field :payload, Feather.Encrypted.Binary, load_in_query: false, redact: true
    field :attempts, :integer, default: 0
    field :next_attempt_at, :utc_datetime_usec
    field :claimed_until, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site

    timestamps()
  end
end
