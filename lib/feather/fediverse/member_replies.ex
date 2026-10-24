defmodule Feather.Fediverse.MemberReplies do
  @moduledoc """
  The replies members write in the CMS to the Mentions of a site's account
  and to the posts in its Timeline (`Feather.Fediverse.MemberReply`).

    * **Audience.** A reply to something public is public: it goes to the
      public, the site's followers and the accounts named in what it
      answers, its author and the other accounts it mentions. Any other
      reply goes only to those accounts, never to a followers collection.
    * **Sending.** A reply goes out at once as a `Create` with its `Note`
      embedded (`Feather.StaticSite.ActivityStreams.member_reply/4`),
      through the delivery queue. A public one also starts a deploy, which
      puts its document online at `/activitypub/replies/<public id>`.
      While the reply it answers is approved, the post's thread shows its
      text below that reply, where its `url` points (a reply to a Timeline
      post is in no thread). One that is not public has no document
      anywhere public.
    * **Deleting.** Deleting a public reply deploys first; the `Delete`
      goes out after the deploy that took its document off the site
      (`send_deletes/2`). A reply that is not public, or one of a site
      without a deployment target, is deleted at once. A reply whose
      mention or Timeline post is gone stays listed (`paginate/2`), so it
      can still be deleted.
  """

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias Feather.Fediverse

  alias Feather.Fediverse.{
    Deliveries,
    MemberReply,
    Mention,
    RemoteAccount,
    RemoteAccounts,
    TimelinePost
  }

  alias Feather.{Pagination, PublicId, Publishing, Repo}
  alias Feather.Sites.Site
  alias Feather.StaticSite.{ActivityStreams, Routes}

  require Logger

  @activity_streams "https://www.w3.org/ns/activitystreams"

  @doc """
  Replies to a mention of the scope's site with `attrs` (`"content"`, the
  member's text) and sends the reply at once; a public reply starts a
  deploy. A site without a fediverse name sends nothing
  (`{:error, :not_an_account}`).
  """
  @spec reply_to_mention(Scope.t(), Mention.t(), map()) ::
          {:ok, MemberReply.t()} | {:error, Ecto.Changeset.t() | :not_an_account}
  def reply_to_mention(
        %Scope{site: %Site{id: site_id} = site},
        %Mention{site_id: site_id} = mention,
        attrs
      ) do
    mention = Repo.preload(mention, [:remote_account, :post])
    public? = mention.visibility == :public
    reply = %MemberReply{mention_id: mention.id, post_id: if(public?, do: mention.post_id)}
    thread_post = if public? and mention.approval == :approved, do: mention.post

    send_new(site, reply, mention, mention.remote_account, thread_post, attrs)
  end

  @doc "Replies to a post in the scope site's Timeline like `reply_to_mention/3`."
  @spec reply_to_timeline_post(Scope.t(), TimelinePost.t(), map()) ::
          {:ok, MemberReply.t()} | {:error, Ecto.Changeset.t() | :not_an_account}
  def reply_to_timeline_post(
        %Scope{site: %Site{id: site_id} = site},
        %TimelinePost{site_id: site_id} = post,
        attrs
      ) do
    post = Repo.preload(post, followed_account: :remote_account)
    reply = %MemberReply{timeline_post_id: post.id}

    send_new(site, reply, post, post.followed_account.remote_account, nil, attrs)
  end

  defp send_new(%Site{fediverse_name: nil}, _reply, _answered, _author, _post, _attrs),
    do: {:error, :not_an_account}

  defp send_new(site, reply, answered, author, post, attrs) do
    reply = %{
      reply
      | site_id: site.id,
        in_reply_to: answered.uri,
        visibility: if(answered.visibility == :public, do: :public, else: :direct)
    }

    changeset = MemberReply.changeset(reply, attrs)

    with {:ok, _valid} <- apply_action(changeset, :insert),
         recipients = recipients(site, author, answered.named_accounts),
         {:ok, reply} <-
           changeset
           |> put_change(:recipients, Enum.map(recipients, & &1.uri))
           |> PublicId.put()
           |> Repo.insert() do
      send_reply(site, reply, recipients, post)
      {:ok, reply}
    end
  end

  defp send_reply(site, reply, recipients, post) do
    post = shown_post(post)
    note = ActivityStreams.member_reply(site, Fediverse.canonical_routes(site), reply, post)
    activity = ActivityStreams.create_activity(note)
    :ok = Deliveries.deliver(site, audience(site, reply, recipients), activity)
    if reply.visibility == :public, do: Fediverse.deploy(site)
  end

  defp recipients(site, author, named_accounts) do
    named =
      for uri <- named_accounts,
          {:ok, account} <- [RemoteAccounts.get(site, uri)],
          do: account

    Enum.uniq_by([author | named], & &1.uri)
  end

  defp shown_post(nil), do: nil

  defp shown_post(post) do
    case Content.as_published([post]) do
      [published] -> if Content.due?(published, DateTime.utc_now()), do: published
      [] -> nil
    end
  end

  defp audience(site, %MemberReply{visibility: :public}, recipients),
    do: Fediverse.followers(site) ++ recipients

  defp audience(_site, %MemberReply{}, recipients), do: recipients

  @doc "The scope site's reply with `id`, unless it is being deleted."
  @spec get!(Scope.t(), Ecto.UUID.t()) :: MemberReply.t()
  def get!(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one!(
      from r in MemberReply,
        where: r.site_id == ^site_id and r.id == ^id and is_nil(r.deleted_at)
    )
  end

  @doc """
  One page of the scope site's replies, newest first, without those being
  deleted. Those whose mention or Timeline post is gone are listed too;
  the others come with what they answer and its author, each with the
  post in whose thread it is, if any.
  """
  @spec paginate(Scope.t(), pos_integer() | String.t() | nil) :: Pagination.t()
  def paginate(%Scope{site: %Site{id: site_id}}, page) do
    query =
      from r in MemberReply,
        where: r.site_id == ^site_id and is_nil(r.deleted_at),
        order_by: [desc: r.inserted_at],
        preload: [
          :post,
          mention: :remote_account,
          timeline_post: [followed_account: :remote_account]
        ]

    Pagination.paginate(query, page)
  end

  @doc "The site's public replies that are not being deleted: those with a document."
  @spec list_public(Site.t()) :: [MemberReply.t()]
  def list_public(%Site{id: site_id}) do
    Repo.all(
      from r in MemberReply,
        where: r.site_id == ^site_id and r.visibility == :public and is_nil(r.deleted_at),
        order_by: [asc: r.inserted_at]
    )
  end

  @doc """
  Deletes a reply of the scope's site. A public one leaves the site with a
  deploy first, after which its `Delete` goes out (`send_deletes/2`).
  """
  @spec delete(Scope.t(), MemberReply.t()) :: :ok
  def delete(%Scope{site: %Site{id: site_id} = site}, %MemberReply{site_id: site_id} = reply) do
    case reply.visibility do
      :public ->
        reply = reply |> change(deleted_at: DateTime.utc_now()) |> Repo.update!()

        case Publishing.deploy_site(Scope.for_site(site)) do
          :ok -> :ok
          {:error, :no_target} -> send_delete(site, reply)
        end

      :direct ->
        send_delete(site, reply)
    end
  end

  @doc """
  Sends the `Delete` of each reply of the site being deleted whose
  document the export below `dir`, which a deploy just put online, no
  longer has, and removes the reply. Failures are only logged: the deploy
  has succeeded.
  """
  @spec send_deletes(Site.t(), Path.t()) :: :ok
  def send_deletes(%Site{id: site_id} = site, dir) do
    routes = Routes.new(site)

    from(r in MemberReply, where: r.site_id == ^site_id and not is_nil(r.deleted_at))
    |> Repo.all()
    |> Enum.reject(&File.exists?(Path.join(dir, Routes.activitypub_path(routes, &1))))
    |> Enum.each(&send_delete(site, &1))
  rescue
    exception ->
      Logger.error(
        "Sending the Delete of members' replies of #{site.domain} failed: " <>
          Exception.message(exception)
      )
  end

  defp send_delete(site, reply) do
    note = ActivityStreams.member_reply(site, Fediverse.canonical_routes(site), reply, nil)
    recipients = Repo.all(from a in RemoteAccount, where: a.uri in ^reply.recipients)

    :ok = Deliveries.deliver(site, audience(site, reply, recipients), delete_activity(note))
    Repo.delete!(reply, allow_stale: true)
    :ok
  end

  defp delete_activity(note) do
    Map.merge(
      %{
        "@context" => @activity_streams,
        "id" => note["id"] <> "#delete",
        "type" => "Delete",
        "actor" => note["attributedTo"],
        "object" => %{"id" => note["id"], "type" => "Tombstone"}
      },
      Map.take(note, ["to", "cc"])
    )
  end
end
