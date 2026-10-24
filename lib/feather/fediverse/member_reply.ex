defmodule Feather.Fediverse.MemberReply do
  @moduledoc """
  A reply a member wrote in the CMS to a mention of the site's account or
  to a post in its Timeline (`Feather.Fediverse.MemberReplies`), sent as a
  `Note` of the account.

  A reply to something public is `:public`: it addresses the public, the
  site's followers and the `recipients`, has a document on the site's
  domain and appears in the thread of `post`, if it has one, while the
  reply it answers is approved. Any other is
  `:direct`: it addresses only the `recipients`, the accounts named in
  what it answers, and has no document anywhere public.

  Its content, the member's plain text, is stored encrypted, the public
  ones too; who it went to and when stays in clear text. A public reply
  that is being deleted keeps `deleted_at` until the deploy that takes its
  document off the site has run and its `Delete` went out.
  """
  use Feather.Schema

  alias Feather.Fediverse.{Mention, TimelinePost}

  @type t :: %__MODULE__{}

  @max_length 5_000

  schema "fediverse_member_replies" do
    field :public_id, :string
    field :in_reply_to, :string
    field :visibility, Ecto.Enum, values: [:public, :direct]
    field :content, Feather.Encrypted.Binary, redact: true
    field :recipients, {:array, :string}, default: []
    field :deleted_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :mention, Mention
    belongs_to :timeline_post, TimelinePost
    belongs_to :post, Feather.Content.Post

    timestamps()
  end

  @doc false
  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [:content])
    |> update_change(:content, &String.trim/1)
    |> validate_required([:content])
    |> validate_length(:content, max: @max_length)
  end
end
