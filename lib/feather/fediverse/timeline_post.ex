defmodule Feather.Fediverse.TimelinePost do
  @moduledoc """
  A post of an account the site follows, in the site's Timeline
  (`Feather.Fediverse.Timeline`): `:public` or, once the follow was
  accepted, `:followers` (to its author's followers). Members answer it
  with replies of their own (`Feather.Fediverse.MemberReply`).

  Its title (an `Article`'s name), content (sanitized HTML), content
  warning and attachments (`url`, `media_type` and `name`, the alt text)
  are stored encrypted, the public ones too; who wrote it to which site and
  when stay in clear text.
  """
  use Feather.Schema

  alias Feather.Fediverse.{FollowedAccount, MemberReply, RemoteAccount, RemoteObject}

  @type t :: %__MODULE__{}

  schema "fediverse_timeline_posts" do
    field :public_id, :string
    field :uri, :string
    field :url, :string
    field :in_reply_to, :string
    field :visibility, Ecto.Enum, values: [:public, :followers]
    field :name, Feather.Encrypted.Binary, redact: true
    field :content, Feather.Encrypted.Binary, redact: true
    field :summary, Feather.Encrypted.Binary, redact: true
    field :attachments, Feather.Encrypted.List, default: [], redact: true
    field :named_accounts, {:array, :string}, default: []
    field :published_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :followed_account, FollowedAccount
    has_many :member_replies, MemberReply

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :uri,
      :url,
      :in_reply_to,
      :visibility,
      :name,
      :content,
      :summary,
      :attachments,
      :named_accounts,
      :published_at
    ])
    |> validate_required([:uri, :visibility, :published_at])
    |> RemoteAccount.validate_https([:uri, :url])
    |> RemoteObject.validate_size()
    |> unique_constraint([:site_id, :uri])
  end
end
