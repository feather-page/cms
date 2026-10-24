defmodule Feather.Fediverse.Mention do
  @moduledoc """
  Something addressed to a site's account (`Feather.Fediverse.Mentions`):
  a reply to one of its posts, a mention of the account or a private
  message, with its author, the post it answers, the other accounts it
  names and its visibility: `:public` (to the public, listed or not),
  `:followers` (to its author's followers) or `:direct` (a private
  message). Members answer it with replies of their own
  (`Feather.Fediverse.MemberReply`).

  Its content (sanitized HTML), content warning and attachments (`url`,
  `media_type` and `name`, the alt text) are stored encrypted, the public
  ones too, and loaded with it, since every use shows them; who wrote to
  which site, what it answers and when stay in clear text.

  A public reply to a post is a reply the site may show (`approvable?/1`):
  its `approval` is `:waiting`, `:approved` or `:hidden`. An approved one
  keeps the snapshot the site shows: its content, its author's name and
  handle and the file name of its author's picture
  (`Feather.Fediverse.Pictures`) as the member who approved it saw them
  (`version/1`).
  """
  use Feather.Schema

  alias Feather.Fediverse.{MemberReply, RemoteAccount, RemoteObject}

  @type t :: %__MODULE__{}

  schema "fediverse_mentions" do
    field :public_id, :string
    field :uri, :string
    field :url, :string
    field :in_reply_to, :string
    field :visibility, Ecto.Enum, values: [:public, :followers, :direct]
    field :content, Feather.Encrypted.Binary, redact: true
    field :summary, Feather.Encrypted.Binary, redact: true
    field :attachments, Feather.Encrypted.List, default: [], redact: true
    field :named_accounts, {:array, :string}, default: []
    field :published_at, :utc_datetime_usec
    field :read_at, :utc_datetime_usec
    field :approval, Ecto.Enum, values: [:waiting, :approved, :hidden], default: :waiting
    field :approved_at, :utc_datetime_usec
    field :approved_content, Feather.Encrypted.Binary, redact: true
    field :approved_name, :string
    field :approved_handle, :string
    field :approved_picture, :string

    belongs_to :site, Feather.Sites.Site
    belongs_to :remote_account, RemoteAccount
    belongs_to :post, Feather.Content.Post
    has_many :member_replies, MemberReply

    timestamps()
  end

  @doc false
  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [
      :uri,
      :url,
      :in_reply_to,
      :visibility,
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

  @doc """
  The version of the mention as a member sees it: as stored, which every
  change of it moves, with its author's name, handle and picture, which
  approving it keeps. Needs its `remote_account`.
  """
  @spec version(t()) :: String.t()
  def version(%__MODULE__{updated_at: updated_at, remote_account: %RemoteAccount{} = author}) do
    seen = Jason.encode!([updated_at, author.name, author.handle, author.picture_url])
    :sha256 |> :crypto.hash(seen) |> binary_part(0, 16) |> Base.url_encode64(padding: false)
  end

  @doc "Returns true for a public reply to a post of the site, which the site may show."
  @spec approvable?(t()) :: boolean()
  def approvable?(%__MODULE__{visibility: visibility, post_id: post_id}),
    do: visibility == :public and not is_nil(post_id)

  @doc "Puts the approval to `approval`, with the snapshot of an approved reply or none."
  @spec approval_changeset(t() | Ecto.Changeset.t(), :waiting | :approved | :hidden, map()) ::
          Ecto.Changeset.t()
  def approval_changeset(mention_or_changeset, approval, snapshot \\ %{}) do
    change(mention_or_changeset, %{
      approval: approval,
      approved_at: snapshot[:approved_at],
      approved_content: snapshot[:approved_content],
      approved_name: snapshot[:approved_name],
      approved_handle: snapshot[:approved_handle],
      approved_picture: snapshot[:approved_picture]
    })
  end
end
