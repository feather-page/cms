defmodule Feather.Fediverse do
  @moduledoc """
  A site's account in the fediverse (ADR 0033). A site with a fediverse
  name is the account `@<name>@<domain>`; without one it is not in the
  fediverse.

  The account lives on the site's domain: the static export writes the
  WebFinger answer, the account at `/activitypub/<name>`, its outbox and
  a document per post (`Feather.StaticSite.ActivityStreams`). Only its
  inbox is on the CMS, at `/fediverse/inbox/<site public id>` on the
  CMS's public host (`config :feather, :base_url`).

  Setting the name gives the site an RSA key pair of 2048 bits. The
  private key is stored encrypted and not loaded with the site
  (`private_key/1`), so it never reaches the export, the preview or the
  API. A deploy that puts the account online records when it first did
  (`record_online/2`); from then on the name is fixed. A new domain starts
  the account over (`start_over/1`). Rotating the key (`rotate_key/1`)
  gives the account a new pair that is pending until a deploy has
  published its public half; only then does the account sign with it, and
  the old pair is discarded.

  The account talks to other servers only through checked, signed
  requests (`Feather.Fediverse.Client`). Accounts on other servers are
  cached (`Feather.Fediverse.RemoteAccounts`), and activities go out
  through a queue that retries them (`Feather.Fediverse.Deliveries`). The inbox takes in what other servers
  send (`receive_activity/3`, see `Feather.Fediverse.Inbox`): it accepts
  follows and keeps the followers (`count_followers/1`), and files what is
  addressed to the account into its Mentions (`paginate_mentions/3`, see
  `Feather.Fediverse.Mentions`). Replies to the site's posts appear below
  them once a member approves them (`approve_reply/3`, `hide_reply/2`,
  `approved_replies/2`). Members follow accounts by their handles
  (`follow/2`, `unfollow/2`, see `Feather.Fediverse.Following`), whose
  posts the inbox files into the site's Timeline (`paginate_timeline/2`,
  see `Feather.Fediverse.Timeline`). Members answer mentions and Timeline
  posts from the CMS (`reply_to_mention/3`, `reply_to_timeline_post/3`,
  `paginate_member_replies/2`, `delete_member_reply/2`, see
  `Feather.Fediverse.MemberReplies`). Members
  block accounts or whole servers, which then can neither follow the site
  nor reach its Mentions (`block/3`, `unblock/2`, see
  `Feather.Fediverse.Blocks`). Each deploy sends the followers the
  posts it adds, changes or removes and a changed profile, and the
  `Delete` of the members' replies it took off the site; then the
  pictures of repliers the site no longer shows are deleted
  (`federate/2`, see `Feather.Fediverse.FederatedObjects`).
  """

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.Post

  alias Feather.Fediverse.{
    Blocks,
    Deliveries,
    Delivery,
    FederatedObject,
    FederatedObjects,
    FollowedAccount,
    Follower,
    Following,
    Inbox,
    MemberReplies,
    MemberReply,
    Mentions,
    Pictures,
    RemoteAccount,
    RemoteAccounts,
    Timeline,
    TimelinePost
  }

  alias Feather.{Pagination, Publishing, Repo, Sites}
  alias Feather.Sites.Site
  alias Feather.StaticSite.Routes

  require Logger
  require Record

  Record.defrecordp(
    :rsa_private_key,
    :RSAPrivateKey,
    Record.extract(:RSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
  )

  @inbox_prefix "/fediverse/inbox/"
  @key_bits 2048
  @key_exponent 65_537
  @name_format ~r/\A[a-z0-9_]+\z/
  @name_max_length 30
  # The account's documents take these paths below activitypub/ besides the account itself.
  @reserved_names ~w(followers following outbox posts replies)

  defdelegate remote_account_addresses(uris), to: RemoteAccounts, as: :addresses
  defdelegate receive_activity(site_public_id, request, activity), to: Inbox
  defdelegate check_inbox_client(ip), to: Inbox, as: :check_client
  defdelegate paginate_mentions(scope, page, filter), to: Mentions, as: :paginate
  defdelegate count_unread_mentions(scope), to: Mentions, as: :count_unread
  defdelegate mark_mentions_read(scope, mentions), to: Mentions, as: :mark_read
  defdelegate get_mention!(scope, id), to: Mentions, as: :get!
  defdelegate approve_reply(scope, mention, version), to: Mentions, as: :approve
  defdelegate hide_reply(scope, mention), to: Mentions, as: :hide
  defdelegate mention_picture(scope, public_id), to: Mentions, as: :picture
  defdelegate approved_replies(site, posts), to: Mentions
  defdelegate reply_pictures(site), to: Mentions
  defdelegate reply_to_mention(scope, mention, attrs), to: MemberReplies
  defdelegate delete_member_reply(scope, reply), to: MemberReplies, as: :delete
  defdelegate get_member_reply!(scope, id), to: MemberReplies, as: :get!
  defdelegate paginate_member_replies(scope, page), to: MemberReplies, as: :paginate
  defdelegate public_member_replies(site), to: MemberReplies, as: :list_public
  defdelegate reply_to_timeline_post(scope, post, attrs), to: MemberReplies
  defdelegate follow(scope, handles), to: Following
  defdelegate unfollow(scope, followed), to: Following
  defdelegate get_followed_account!(scope, id), to: Following, as: :get!
  defdelegate paginate_followed_accounts(scope, page), to: Following, as: :paginate
  defdelegate count_following(scope), to: Following, as: :count
  defdelegate paginate_timeline(scope, page), to: Timeline, as: :paginate
  defdelegate get_timeline_post!(scope, id), to: Timeline, as: :get!
  defdelegate get_timeline_post(scope, id), to: Timeline, as: :get
  defdelegate subscribe_timeline(scope), to: Timeline, as: :subscribe
  defdelegate timeline_picture(scope, public_id, index), to: Timeline, as: :picture
  defdelegate followed_account_picture(scope, public_id), to: Timeline, as: :account_picture
  defdelegate block(scope, account, what), to: Blocks
  defdelegate unblock(scope, block), to: Blocks
  defdelegate list_blocks(scope), to: Blocks, as: :list
  defdelegate get_block!(scope, id), to: Blocks, as: :get!

  @doc "Returns true if the site has a fediverse name and so is an account."
  @spec account?(Site.t()) :: boolean()
  def account?(%Site{fediverse_name: name}), do: is_binary(name)

  @doc "Returns true once a deploy has put the site's account online."
  @spec online?(Site.t()) :: boolean()
  def online?(%Site{fediverse_online_at: online_at}), do: not is_nil(online_at)

  @doc "Returns true while a new key pair waits for a deploy to publish it (`rotate_key/1`)."
  @spec key_pending?(Site.t()) :: boolean()
  def key_pending?(%Site{fediverse_pending_public_key: key}), do: not is_nil(key)

  @doc "The public key the export publishes: a pending one, else the current one."
  @spec public_key(Site.t()) :: String.t() | nil
  def public_key(%Site{fediverse_pending_public_key: nil, fediverse_public_key: key}), do: key
  def public_key(%Site{fediverse_pending_public_key: key}), do: key

  @doc "The site's handle (`@timon@timon.blog`), or nil without a fediverse name."
  @spec handle(Site.t()) :: String.t() | nil
  def handle(%Site{fediverse_name: nil}), do: nil
  def handle(%Site{fediverse_name: name, domain: domain}), do: "@#{name}@#{domain}"

  @doc "The address of the site's account on its domain, or nil without a fediverse name."
  @spec account_url(Site.t()) :: String.t() | nil
  def account_url(%Site{fediverse_name: nil}), do: nil

  def account_url(%Site{} = site),
    do: site |> canonical_routes() |> Routes.activitypub_url(:account)

  @doc "The address of a post's document on the site's domain, or nil without a fediverse name."
  @spec post_url(Site.t(), Post.t()) :: String.t() | nil
  def post_url(%Site{fediverse_name: nil}, %Post{}), do: nil

  def post_url(%Site{} = site, %Post{} = post),
    do: site |> canonical_routes() |> Routes.activitypub_url(post)

  @doc "The address of a member's reply on the site's domain, or nil without a fediverse name."
  @spec member_reply_url(Site.t(), MemberReply.t()) :: String.t() | nil
  def member_reply_url(%Site{fediverse_name: nil}, %MemberReply{}), do: nil

  def member_reply_url(%Site{} = site, %MemberReply{} = reply),
    do: site |> canonical_routes() |> Routes.activitypub_url(reply)

  @doc "The routes of the site at its public address, where its fediverse documents live."
  @spec canonical_routes(Site.t()) :: Routes.t()
  def canonical_routes(%Site{} = site), do: site |> Routes.public() |> Routes.canonical()

  @doc "The inbox of the site's account, on the CMS's public host."
  @spec inbox_url(Site.t()) :: String.t()
  def inbox_url(%Site{public_id: public_id}),
    do: Application.fetch_env!(:feather, :base_url) <> @inbox_prefix <> public_id

  @doc "The accounts that follow the site."
  @spec followers(Site.t()) :: [RemoteAccount.t()]
  def followers(%Site{id: site_id}) do
    Repo.all(
      from a in RemoteAccount,
        join: f in Follower,
        on: f.remote_account_id == a.id,
        where: f.site_id == ^site_id
    )
  end

  @doc """
  Sends what the deploy that wrote the export below `dir` changed: the
  followers get its posts and profile (`Feather.Fediverse.FederatedObjects`),
  the recipients of the members' replies it took off the site their
  `Delete` (`Feather.Fediverse.MemberReplies.send_deletes/2`). Then the
  pictures of repliers the site no longer uses are deleted
  (`Feather.Fediverse.Pictures.delete_unused/1`).
  """
  @spec federate(Site.t(), Path.t()) :: :ok
  def federate(%Site{} = site, dir) do
    :ok = FederatedObjects.sync(site, dir)
    :ok = MemberReplies.send_deletes(site, dir)
    Pictures.delete_unused(site)
  end

  @doc """
  Starts a deploy of the site after a change of what it shows, where it
  has a deployment target; concurrent deploys coalesce
  (`Feather.Publishing.Deploy`).
  """
  @spec deploy(Site.t()) :: :ok
  def deploy(%Site{} = site) do
    Publishing.deploy_site(Scope.for_site(site))
    :ok
  end

  @doc "The number of accounts that follow the scope's site."
  @spec count_followers(Scope.t()) :: non_neg_integer()
  def count_followers(%Scope{site: %Site{id: site_id}}),
    do: Repo.aggregate(from(f in Follower, where: f.site_id == ^site_id), :count)

  @doc "One page of the accounts that follow the scope's site, newest first."
  @spec paginate_followers(Scope.t(), pos_integer() | String.t() | nil) :: Pagination.t()
  def paginate_followers(%Scope{site: %Site{id: site_id}}, page) do
    query =
      from a in RemoteAccount,
        join: f in Follower,
        on: f.remote_account_id == a.id,
        where: f.site_id == ^site_id,
        order_by: [desc: f.inserted_at]

    Pagination.paginate(query, page)
  end

  @doc """
  The fediverse's periodic work, every minute
  (`Feather.Fediverse.Scheduler`): drops the Timeline posts and the ids of
  received activities older than 30 days, processes the received
  activities that wait for it (`Feather.Fediverse.Inbox.process_due/0`)
  and sends the due deliveries.
  """
  @spec run_due() :: :ok
  def run_due do
    :ok = Timeline.purge_expired()
    :ok = Inbox.purge_received()
    :ok = Inbox.process_due()
    Deliveries.deliver_due()
  end

  @doc """
  Returns a changeset for the site's fediverse name: trimmed and
  lowercased, letters, digits and underscores only, none of the paths the
  account's documents take, and fixed once the account is online. A blank
  name is nil.
  """
  @spec change_name(Site.t(), map()) :: Ecto.Changeset.t()
  def change_name(%Site{} = site, attrs \\ %{}) do
    site
    |> cast(attrs, [:fediverse_name])
    |> Feather.Validations.trim_to_nil(:fediverse_name)
    |> update_change(:fediverse_name, &downcase/1)
    |> validate_format(:fediverse_name, @name_format,
      message: "may only contain letters, digits and underscores"
    )
    |> validate_length(:fediverse_name, max: @name_max_length)
    |> validate_exclusion(:fediverse_name, @reserved_names,
      message: "is taken by the account's documents"
    )
    |> validate_not_online()
  end

  defp downcase(name) when is_binary(name), do: String.downcase(name)
  defp downcase(nil), do: nil

  defp validate_not_online(changeset) do
    if online?(changeset.data) and changed?(changeset, :fediverse_name),
      do:
        add_error(
          changeset,
          :fediverse_name,
          "can no longer be changed after the first deploy with it"
        ),
      else: changeset
  end

  @doc """
  Sets the fediverse name of the scope's site (see `change_name/2`) and
  gives the site its key pair if it has none yet. The site is read afresh,
  so a deploy that just put the account online fixes the name. Moves the
  site's `updated_at`: the export shows the change. The site comes back
  as loaded sites do, without its private key.
  """
  @spec update_name(Scope.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def update_name(%Scope{site: %Site{id: site_id} = site} = scope, attrs) do
    true = Sites.can_access_site?(scope, site)

    Repo.transact(fn ->
      with {:ok, site} <-
             Site |> Repo.get!(site_id) |> change_name(attrs) |> put_key_pair() |> Repo.update() do
        {:ok, %{site | fediverse_private_key: nil}}
      end
    end)
  end

  defp put_key_pair(%Ecto.Changeset{valid?: true} = changeset) do
    if get_field(changeset, :fediverse_name) &&
         is_nil(get_field(changeset, :fediverse_public_key)) do
      {public_key, private_key} = generate_key_pair()

      changeset
      |> put_change(:fediverse_public_key, public_key)
      |> put_change(:fediverse_private_key, private_key)
    else
      changeset
    end
  end

  defp put_key_pair(changeset), do: changeset

  defp generate_key_pair do
    private_key = :public_key.generate_key({:rsa, @key_bits, @key_exponent})

    public_key =
      {:RSAPublicKey, rsa_private_key(private_key, :modulus),
       rsa_private_key(private_key, :publicExponent)}

    {pem(:SubjectPublicKeyInfo, public_key), pem(:RSAPrivateKey, private_key)}
  end

  defp pem(type, key) do
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(type, key)])
    String.trim_trailing(pem) <> "\n"
  end

  @doc """
  Gives the account of the scope's site a new key pair, stored like the
  current one, pending until a deploy publishes its public half
  (`record_online/2`). Until then the account signs with its current key.
  A key pending already is replaced. Moves the site's `updated_at`: the
  export shows the change. The site comes back without private keys.
  """
  @spec rotate_key(Scope.t()) :: {:ok, Site.t()} | {:error, :not_an_account}
  def rotate_key(%Scope{site: %Site{id: site_id} = site} = scope) do
    true = Sites.can_access_site?(scope, site)
    site = Repo.get!(Site, site_id)

    if account?(site) do
      {public_key, private_key} = generate_key_pair()

      site =
        site
        |> change(
          fediverse_pending_public_key: public_key,
          fediverse_pending_private_key: private_key
        )
        |> Repo.update!()

      {:ok, %{site | fediverse_pending_private_key: nil}}
    else
      {:error, :not_an_account}
    end
  end

  @doc """
  The private key of the site's account as PEM, or nil. Raises
  `ArgumentError` when it does not decrypt.
  """
  @spec private_key(Site.t()) :: String.t() | nil
  def private_key(%Site{id: site_id}),
    do: Repo.one(from s in Site, where: s.id == ^site_id, select: s.fediverse_private_key)

  @doc """
  Starts the site's account over after its domain changed (ADR 0033): the
  account at the new address is a new one, which goes online with the next
  deploy. What belonged to the account at the old address is deleted: its
  followers, the accounts it follows with their Timeline posts, its
  federated objects and the deliveries still queued.
  """
  @spec start_over(Site.t()) :: :ok
  def start_over(%Site{id: site_id}) do
    Repo.update_all(from(s in Site, where: s.id == ^site_id), set: [fediverse_online_at: nil])

    for schema <- [Follower, TimelinePost, FollowedAccount, FederatedObject, Delivery],
        do: Repo.delete_all(from r in schema, where: r.site_id == ^site_id)

    :ok
  end

  @doc """
  Records that a deploy put the site's account online, at `at` (the start
  of its export), unless it went online before. Only for the fediverse
  name the deploy exported: a name changed meanwhile goes online with the
  next deploy. A pending key the deploy published becomes the account's
  key, unless a newer one replaced it meanwhile. A failure is only logged:
  the deploy has succeeded, and the next one records it.
  """
  @spec record_online(Site.t(), DateTime.t()) :: :ok
  def record_online(%Site{fediverse_name: nil}, %DateTime{}), do: :ok

  def record_online(%Site{id: site_id, fediverse_name: name} = site, %DateTime{} = at) do
    Repo.update_all(
      from(s in Site,
        where: s.id == ^site_id and s.fediverse_name == ^name and is_nil(s.fediverse_online_at)
      ),
      set: [fediverse_online_at: at]
    )

    record_key(site)
  rescue
    exception ->
      Logger.error(
        "Recording the fediverse account of #{site.domain} as online failed: " <>
          Exception.message(exception)
      )
  end

  defp record_key(%Site{fediverse_pending_public_key: nil}), do: :ok

  defp record_key(%Site{id: site_id, fediverse_pending_public_key: public_key}) do
    Repo.update_all(
      from(s in Site,
        where: s.id == ^site_id and s.fediverse_pending_public_key == ^public_key,
        update: [
          set: [
            fediverse_public_key: s.fediverse_pending_public_key,
            fediverse_private_key: s.fediverse_pending_private_key,
            fediverse_pending_public_key: nil,
            fediverse_pending_private_key: nil
          ]
        ]
      ),
      []
    )

    :ok
  end
end
