defmodule Feather.Fediverse.Timeline do
  @moduledoc """
  The Timeline of a site's account: the posts of the accounts it follows
  (`Feather.Fediverse.TimelinePost`), newest first, kept 30 days
  (`purge_expired/0`).

  The inbox (`Feather.Fediverse.Inbox`) files the `Note` or `Article` of a
  `Create` by an account the site follows (`files?/3`): a public post, or
  one to its author's followers once the site's follow was accepted
  (`Feather.Fediverse.Following`). Private messages go to Mentions only;
  boosts and likes are not filed. `Update` changes a post, or removes it
  when the site may no longer see it, and `Delete` removes it, leaving a
  tombstone so that a late `Create` does not file it again; both only from
  its author.

  Every filed, changed or removed post is broadcast to the members who
  look at the Timeline (`subscribe/1`) as `{:timeline_post, :created |
  :updated | :deleted, id}`. The pictures of the posts and of their
  authors load through the CMS (`picture/3`), so their servers do not see
  the members' addresses.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope

  alias Feather.Fediverse.{
    FollowedAccount,
    Following,
    MemberReply,
    Pictures,
    RemoteAccount,
    RemoteObject,
    TimelinePost,
    Tombstone
  }

  alias Feather.{Pagination, PublicId, Repo}
  alias Feather.Sites.Site

  require Logger

  @lifetime_days 30
  @changeable [:url, :visibility, :name, :content, :summary, :attachments, :named_accounts]

  @doc """
  Returns true if `object` by the actor at `actor` belongs into the site's
  Timeline: a note or article of an account the site follows that the
  site may see.
  """
  @spec files?(Site.t(), String.t(), term()) :: boolean()
  def files?(%Site{} = site, actor, object) do
    with true <- RemoteObject.post?(object),
         %FollowedAccount{} = followed <- Following.get_by_uri(site, actor) do
      visible?(RemoteObject.visibility(object, followed.remote_account), followed)
    else
      _other -> false
    end
  end

  defp visible?(:public, _followed), do: true
  defp visible?(:followers, followed), do: FollowedAccount.accepted?(followed)
  defp visible?(:direct, _followed), do: false

  @doc "Returns true if the site's Timeline holds the object at `uri` by the actor at `author`."
  @spec filed?(Site.t(), String.t() | nil, String.t()) :: boolean()
  def filed?(%Site{}, nil, _author), do: false

  def filed?(%Site{id: site_id}, uri, author) do
    Repo.exists?(
      from t in TimelinePost,
        join: f in assoc(t, :followed_account),
        join: a in assoc(f, :remote_account),
        where: t.site_id == ^site_id and t.uri == ^uri and a.uri == ^author
    )
  end

  @doc """
  Files `object` by `account` into the site's Timeline, unless the site no
  longer follows the account or may not see the post, its author deleted
  it before or it is there.
  """
  @spec file(Site.t(), RemoteAccount.t(), map()) :: :ok
  def file(%Site{} = site, %RemoteAccount{} = account, %{} = object) do
    attrs = RemoteObject.attrs(site, object, account)

    with %FollowedAccount{} = followed <- Following.get_by_uri(site, account.uri),
         true <- visible?(attrs.visibility, followed),
         false <- Tombstone.exists?(site, attrs.uri, account.uri),
         {:ok, post} <- insert(site, followed, attrs) do
      broadcast(site, :created, post)
    end

    :ok
  end

  defp insert(site, followed, attrs) do
    %TimelinePost{site_id: site.id, followed_account_id: followed.id}
    |> TimelinePost.changeset(attrs)
    |> PublicId.put()
    |> Repo.insert()
    |> log_failure()
  end

  @doc """
  Changes the site's Timeline post of `object` by `account` to what
  `object` says now, or removes it when the site may no longer see it.
  """
  @spec update(Site.t(), RemoteAccount.t(), map()) :: :ok
  def update(%Site{} = site, %RemoteAccount{} = account, object) do
    with true <- RemoteObject.post?(object),
         %TimelinePost{} = post <- get_by_author(site, account, object["id"]) do
      attrs = RemoteObject.attrs(site, object, account)

      if visible?(attrs.visibility, post.followed_account),
        do: change(site, post, attrs),
        else: remove(site, post)
    end

    :ok
  end

  defp change(site, post, attrs) do
    with {:ok, post} <-
           post
           |> TimelinePost.changeset(Map.take(attrs, @changeable))
           |> Repo.update()
           |> log_failure() do
      broadcast(site, :updated, post)
    end
  end

  @doc """
  Removes the site's Timeline post at `uri` by `account` and leaves a
  tombstone.
  """
  @spec delete(Site.t(), RemoteAccount.t(), String.t()) :: :ok
  def delete(%Site{} = site, %RemoteAccount{} = account, uri) do
    with %TimelinePost{} = post <- get_by_author(site, account, uri) do
      :ok = Tombstone.insert!(site, post.uri, account.uri)
      remove(site, post)
    end

    :ok
  end

  defp remove(site, post) do
    Repo.delete!(post, allow_stale: true)
    broadcast(site, :deleted, post)
  end

  defp get_by_author(site, account, uri) when is_binary(uri) do
    Repo.one(
      from t in TimelinePost,
        join: f in assoc(t, :followed_account),
        where: t.site_id == ^site.id and t.uri == ^uri and f.remote_account_id == ^account.id,
        preload: [followed_account: f]
    )
  end

  defp get_by_author(_site, _account, _uri), do: nil

  defp log_failure({:ok, _post} = result), do: result

  defp log_failure({:error, changeset} = result) do
    Logger.info("A Timeline post was not stored: #{inspect(changeset.errors)}")
    result
  end

  @doc "Drops the Timeline posts kept for more than #{@lifetime_days} days, of all sites."
  @spec purge_expired() :: :ok
  def purge_expired do
    cutoff = DateTime.add(DateTime.utc_now(), -@lifetime_days, :day)
    Repo.delete_all(from t in TimelinePost, where: t.inserted_at < ^cutoff)
    :ok
  end

  @doc """
  One page of the scope site's Timeline, newest first, with the authors
  and the members' replies.
  """
  @spec paginate(Scope.t(), pos_integer() | String.t() | nil) :: Pagination.t()
  def paginate(%Scope{site: %Site{id: site_id}}, page) do
    query =
      from t in TimelinePost,
        where: t.site_id == ^site_id,
        order_by: [desc: t.published_at, desc: t.inserted_at],
        preload: ^preloads()

    Pagination.paginate(query, page)
  end

  @doc "The scope site's Timeline post with `id`, with its author and the members' replies."
  @spec get!(Scope.t(), Ecto.UUID.t()) :: TimelinePost.t()
  def get!(%Scope{} = scope, id), do: scope |> by_id(id) |> Repo.one!()

  @doc "Like `get!/2`, but nil when the post is gone."
  @spec get(Scope.t(), Ecto.UUID.t()) :: TimelinePost.t() | nil
  def get(%Scope{} = scope, id), do: scope |> by_id(id) |> Repo.one()

  defp by_id(%Scope{site: %Site{id: site_id}}, id),
    do:
      from(t in TimelinePost, where: t.site_id == ^site_id and t.id == ^id, preload: ^preloads())

  defp preloads do
    [
      followed_account: :remote_account,
      member_replies:
        from(r in MemberReply, where: is_nil(r.deleted_at), order_by: [asc: r.inserted_at])
    ]
  end

  @doc """
  The picture of a Timeline post of the scope's site: the attachment at
  `index` of the post with `public_id`, fetched from its server
  (`Feather.Fediverse.Pictures.get/2`). A site without a fediverse name
  has none.
  """
  @spec picture(Scope.t(), String.t(), non_neg_integer()) ::
          {:ok, binary(), String.t()} | {:error, term()}
  def picture(%Scope{site: %Site{fediverse_name: nil}}, _public_id, _index),
    do: {:error, :not_found}

  def picture(%Scope{site: %Site{id: site_id} = site}, public_id, index) do
    post = Repo.get_by(TimelinePost, site_id: site_id, public_id: public_id)

    case post && Enum.at(post.attachments, index) do
      %{"url" => url} -> Pictures.get(site, url)
      nil -> {:error, :not_found}
    end
  end

  @doc """
  The picture of an account the scope's site follows, by the public id of
  the follow, fetched from its server (`Feather.Fediverse.Pictures.get/2`).
  A site without a fediverse name has none.
  """
  @spec account_picture(Scope.t(), String.t()) :: {:ok, binary(), String.t()} | {:error, term()}
  def account_picture(%Scope{site: %Site{fediverse_name: nil}}, _public_id),
    do: {:error, :not_found}

  def account_picture(%Scope{site: %Site{id: site_id} = site}, public_id) do
    url =
      Repo.one(
        from f in FollowedAccount,
          join: a in assoc(f, :remote_account),
          where: f.site_id == ^site_id and f.public_id == ^public_id,
          select: a.picture_url
      )

    if url, do: Pictures.get(site, url), else: {:error, :not_found}
  end

  @doc "Subscribes the caller to the changes of the scope site's Timeline (see the module doc)."
  @spec subscribe(Scope.t()) :: :ok | {:error, term()}
  def subscribe(%Scope{site: %Site{} = site}),
    do: Phoenix.PubSub.subscribe(Feather.PubSub, topic(site))

  defp broadcast(site, event, %TimelinePost{id: id}),
    do: Phoenix.PubSub.broadcast(Feather.PubSub, topic(site), {:timeline_post, event, id})

  defp topic(%Site{id: site_id}), do: "fediverse:timeline:" <> site_id
end
