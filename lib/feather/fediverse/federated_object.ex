defmodule Feather.Fediverse.FederatedObject do
  @moduledoc """
  A document of a site's account as its followers last received it
  (`Feather.Fediverse.FederatedObjects`): its address, its post (nil for
  the account itself and once the post is deleted), a hash of the document
  last sent, the `updated` it last went out with (or its `published`) and
  whether a `Delete` of it went out.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "fediverse_federated_objects" do
    field :uri, :string
    field :document_hash, :string
    field :document_updated_at, :utc_datetime
    field :deleted, :boolean, default: false

    belongs_to :site, Feather.Sites.Site
    belongs_to :post, Feather.Content.Post

    timestamps()
  end
end
