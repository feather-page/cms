defmodule Feather.Fediverse.Tombstone do
  @moduledoc """
  The address of an object its author deleted: a mention or Timeline post
  (`Feather.Fediverse.Mentions`, `Feather.Fediverse.Timeline`), or one the
  site did not know yet (`Feather.Fediverse.Inbox`), so that a late
  `Create` by that author cannot file it. It holds only against its
  author: an account cannot bury another's objects.
  """
  use Feather.Schema

  import Ecto.Query, only: [from: 2]

  alias Feather.Repo
  alias Feather.Sites.Site

  @type t :: %__MODULE__{}

  schema "fediverse_tombstones" do
    field :uri, :string
    field :author, :string

    belongs_to :site, Site

    timestamps(updated_at: false)
  end

  @doc "Returns true if the site keeps a tombstone at `uri` from the account at `author`."
  @spec exists?(Site.t(), term(), String.t()) :: boolean()
  def exists?(%Site{id: site_id}, uri, author) when is_binary(uri) and is_binary(author) do
    Repo.exists?(
      from t in __MODULE__,
        where: t.site_id == ^site_id and t.uri == ^uri and t.author == ^author
    )
  end

  def exists?(%Site{}, _uri, _author), do: false

  @doc "Leaves a tombstone at `uri` from the account at `author` for the site, unless one is there."
  @spec insert!(Site.t(), String.t(), String.t()) :: :ok
  def insert!(%Site{id: site_id}, uri, author) do
    Repo.insert!(%__MODULE__{site_id: site_id, uri: uri, author: author},
      on_conflict: :nothing,
      conflict_target: [:site_id, :uri, :author]
    )

    :ok
  end
end
