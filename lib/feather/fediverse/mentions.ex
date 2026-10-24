defmodule Feather.Fediverse.Mentions do
  @moduledoc """
  The Mentions of a site's account (`Feather.Fediverse.Mention`):
  everything addressed to it, kept for good.

  The inbox (`Feather.Fediverse.Inbox`) files the `Note` or `Article` of a
  `Create` that addresses the site whose inbox received it (`addresses?/2`):
  a reply to one of its posts or to a member's reply
  (`Feather.Fediverse.MemberReplies`), or one that names the account among
  its recipients or mentions it, private messages included. `Update`
  changes a mention and `Delete` removes it, both only from its author.

    * **Visibility and content.** As `Feather.Fediverse.RemoteObject`
      reads them: public, to its author's followers or a private message;
      its HTML sanitized on arrival and again when shown. It keeps the
      other accounts it mentions, whom a member's reply to it addresses
      too.
    * **Caps.** The accounts of a server file at most 100 mentions a day,
      those that follow the site too, and an account that does not follow
      it at most 20; the others are dropped.
    * **Unread.** A mention is unread until a member has seen it in
      Mentions (`mark_read/2`).
    * **Approval.** A public reply to one of the site's posts, or to a
      member's reply in a post's thread, waits until a member approves it
      (`approve/3`) or hides it (`hide/2`); only approved ones appear below
      the post (`approved_replies/2`), as the snapshot taken at approval
      with its author's picture (`Feather.Fediverse.Pictures`), followed by
      the members' public replies to them. The member approves what they
      saw, its author's name and picture (`picture/2`) included. Its
      `Update` puts it back to waiting; the site shows it until the next
      deploy, unless it is no longer public. Approving, hiding an approved
      reply and taking one off the site otherwise start a deploy, which
      changes no post and so reports nothing to IndexNow and archive.org.
    * **Tombstones.** A deleted mention leaves a tombstone
      (`Feather.Fediverse.Tombstone`), so that a late `Create` does not
      file it again, also when its author's account is deleted
      (`delete_by_author/1`) or blocked (`delete_by_authors/2`).
    * **Pictures.** The picture of a reply that leaves the site, by
      hiding, deletion, an edit or a new approval, goes after the next
      successful deploy (`Feather.Fediverse.Pictures.mark_unused/2`).
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.Post
  alias Feather.Fediverse

  alias Feather.Fediverse.{
    Follower,
    MemberReply,
    Mention,
    Pictures,
    RemoteAccount,
    RemoteAccounts,
    RemoteObject,
    Tombstone
  }

  alias Feather.{Pagination, PublicId, Repo}
  alias Feather.Sites.Site

  require Logger

  @daily_server_cap 100
  @daily_cap 20
  @changeable [:url, :visibility, :content, :summary, :attachments, :named_accounts]

  @type filter :: :all | :waiting | :private

  @doc """
  Returns true if `object` is a note or article addressed to the site's
  account: a reply to one of its posts or to a member's reply, or one that
  names the account among its recipients or mentions it.
  """
  @spec addresses?(Site.t(), term()) :: boolean()
  def addresses?(%Site{} = site, object) do
    account = Fediverse.account_url(site)

    RemoteObject.post?(object) and
      (account in RemoteObject.recipients(object) or account in RemoteObject.mentioned(object) or
         match?({:ok, _post_id}, answered(site, object)))
  end

  @doc "Returns true if the site's Mentions hold the object at `uri` by the actor at `author`."
  @spec filed?(Site.t(), String.t() | nil, String.t()) :: boolean()
  def filed?(%Site{}, nil, _author), do: false

  def filed?(%Site{id: site_id}, uri, author) do
    Repo.exists?(
      from m in Mention,
        join: a in assoc(m, :remote_account),
        where: m.site_id == ^site_id and m.uri == ^uri and a.uri == ^author
    )
  end

  @doc """
  Files `object` by `account` into the site's Mentions, unless it is
  there, its author deleted it before or a cap is reached (see the module
  doc).
  """
  @spec file(Site.t(), RemoteAccount.t(), map()) :: :ok
  def file(%Site{} = site, %RemoteAccount{} = account, %{} = object) do
    if not Tombstone.exists?(site, object["id"], account.uri) and within_caps?(site, account) do
      %Mention{
        site_id: site.id,
        remote_account_id: account.id,
        post_id: replied_post_id(site, object)
      }
      |> Mention.changeset(RemoteObject.attrs(site, object, account))
      |> PublicId.put()
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:site_id, :uri])
      |> log_failure()
    end

    :ok
  end

  defp within_caps?(site, account) do
    from_server =
      from m in filed_today(site),
        join: a in assoc(m, :remote_account),
        where: a.host == ^account.host

    Repo.aggregate(from_server, :count) < @daily_server_cap and
      (follower?(site, account) or
         Repo.aggregate(where(filed_today(site), remote_account_id: ^account.id), :count) <
           @daily_cap)
  end

  defp filed_today(site) do
    since = DateTime.add(DateTime.utc_now(), -1, :day)
    from m in Mention, where: m.site_id == ^site.id and m.inserted_at > ^since
  end

  defp follower?(site, account) do
    Repo.exists?(
      from f in Follower, where: f.site_id == ^site.id and f.remote_account_id == ^account.id
    )
  end

  @doc """
  Changes the site's mention of `object` by `account` to what `object`
  says now. An approved reply waits for approval again; one that is no
  longer public leaves the site with a deploy.
  """
  @spec update(Site.t(), RemoteAccount.t(), map()) :: :ok
  def update(%Site{} = site, %RemoteAccount{} = account, object) do
    with true <- RemoteObject.post?(object),
         %Mention{} = mention <- get(site, account, object["id"]) do
      mention
      |> Mention.changeset(Map.take(RemoteObject.attrs(site, object, account), @changeable))
      |> withdraw_approval(mention)
      |> Repo.update()
      |> log_failure()
      |> after_withdrawal(site, mention)
    end

    :ok
  end

  defp withdraw_approval(changeset, %Mention{approval: :approved}),
    do: Mention.approval_changeset(changeset, :waiting)

  defp withdraw_approval(changeset, _mention), do: changeset

  defp after_withdrawal({:ok, updated}, site, %Mention{approval: :approved} = mention) do
    Pictures.mark_unused(site, [mention.approved_picture])
    if updated.visibility != :public, do: Fediverse.deploy(site)
  end

  defp after_withdrawal(_result, _site, _mention), do: :ok

  @doc """
  Removes the site's mention at `uri` by `account` and leaves a tombstone;
  a reply the site showed leaves it with a deploy.
  """
  @spec delete(Site.t(), RemoteAccount.t(), String.t()) :: :ok
  def delete(%Site{} = site, %RemoteAccount{} = account, uri) do
    with %Mention{} = mention <- get(site, account, uri) do
      {:ok, _deleted} =
        Repo.transact(fn ->
          :ok = Tombstone.insert!(site, mention.uri, account.uri)
          Repo.delete(mention, allow_stale: true)
        end)

      Pictures.mark_unused(site, [mention.approved_picture])
      if mention.approval == :approved, do: Fediverse.deploy(site)
    end

    :ok
  end

  @doc """
  Removes every mention by `account`, in all sites; the sites that showed
  one of its replies deploy.
  """
  @spec delete_by_author(RemoteAccount.t()) :: :ok
  def delete_by_author(%RemoteAccount{id: account_id}),
    do: delete_all(from m in Mention, where: m.remote_account_id == ^account_id)

  @doc """
  Removes the site's mentions by `accounts`; if the site showed one of
  their replies, it deploys.
  """
  @spec delete_by_authors(Site.t(), [RemoteAccount.t()]) :: :ok
  def delete_by_authors(%Site{id: site_id}, accounts) do
    account_ids = Enum.map(accounts, & &1.id)

    delete_all(
      from m in Mention, where: m.site_id == ^site_id and m.remote_account_id in ^account_ids
    )
  end

  defp delete_all(query) do
    shown =
      Repo.all(
        from m in query,
          where: m.approval == :approved,
          select: {m.site_id, m.approved_picture}
      )

    Repo.delete_all(query)
    pictures = Enum.group_by(shown, &elem(&1, 0), &elem(&1, 1))

    for site <- Repo.all(from s in Site, where: s.id in ^Map.keys(pictures)) do
      Pictures.mark_unused(site, pictures[site.id])
      Fediverse.deploy(site)
    end

    :ok
  end

  defp get(site, account, uri) when is_binary(uri),
    do: Repo.get_by(Mention, site_id: site.id, remote_account_id: account.id, uri: uri)

  defp get(_site, _account, _uri), do: nil

  defp log_failure({:ok, _mention} = result), do: result

  defp log_failure({:error, changeset} = result) do
    Logger.info("A mention was not stored: #{inspect(changeset.errors)}")
    result
  end

  defp replied_post_id(site, object) do
    case answered(site, object) do
      {:ok, post_id} -> post_id
      :error -> nil
    end
  end

  # A reply to a member's reply belongs to the thread of that reply's post, if any.
  defp answered(site, object) do
    with uri when is_binary(uri) <- RemoteObject.id_of(object["inReplyTo"]),
         segment = uri |> String.split("/") |> List.last(),
         {:ok, query} <- answered_query(site, uri, segment),
         [post_id] <- Repo.one(query) do
      {:ok, post_id}
    else
      _other -> :error
    end
  end

  defp answered_query(site, uri, segment) do
    post = addressed_post(segment)

    cond do
      post && uri == Fediverse.post_url(site, post) ->
        {:ok,
         from(p in Post,
           where: p.site_id == ^site.id and p.public_id == ^post.public_id,
           where: p.fediverse_generation >= ^post.fediverse_generation,
           select: [p.id]
         )}

      uri == Fediverse.member_reply_url(site, %MemberReply{public_id: segment}) ->
        {:ok,
         from(r in MemberReply,
           where: r.site_id == ^site.id and r.public_id == ^segment and is_nil(r.deleted_at),
           select: [r.post_id]
         )}

      true ->
        :error
    end
  end

  # Any address the post's document had, the earlier ones too (see Feather.Content.Post).
  defp addressed_post(segment) do
    case String.split(segment, "-") do
      [public_id] -> %Post{public_id: public_id}
      [public_id, generation] -> addressed_post(public_id, Integer.parse(generation))
      _other -> nil
    end
  end

  defp addressed_post(public_id, {generation, ""}),
    do: %Post{public_id: public_id, fediverse_generation: generation}

  defp addressed_post(_public_id, _invalid), do: nil

  @doc """
  One page of the scope site's mentions, newest first, with their authors,
  the posts they answer and the members' replies to them: all, only the
  public replies to posts waiting for approval, or only the private
  messages.
  """
  @spec paginate(Scope.t(), pos_integer() | String.t() | nil, filter()) :: Pagination.t()
  def paginate(%Scope{site: %Site{id: site_id}}, page, filter \\ :all) do
    from(m in Mention,
      where: m.site_id == ^site_id,
      order_by: [desc: m.published_at, desc: m.inserted_at],
      preload: ^listed_preloads()
    )
    |> filter(filter)
    |> Pagination.paginate(page)
  end

  defp filter(query, :all), do: query
  defp filter(query, :private), do: where(query, [m], m.visibility == :direct)

  defp filter(query, :waiting) do
    where(
      query,
      [m],
      m.approval == :waiting and m.visibility == :public and not is_nil(m.post_id)
    )
  end

  @doc "The number of the scope site's mentions no member has seen yet."
  @spec count_unread(Scope.t()) :: non_neg_integer()
  def count_unread(%Scope{site: %Site{id: site_id}}),
    do:
      Repo.aggregate(
        from(m in Mention, where: m.site_id == ^site_id and is_nil(m.read_at)),
        :count
      )

  @doc "Marks the mentions, of the scope's site, as seen."
  @spec mark_read(Scope.t(), [Mention.t()]) :: :ok
  def mark_read(%Scope{site: %Site{id: site_id}}, mentions) do
    ids = Enum.map(mentions, & &1.id)

    Repo.update_all(
      from(m in Mention, where: m.site_id == ^site_id and m.id in ^ids and is_nil(m.read_at)),
      set: [read_at: DateTime.utc_now()]
    )

    :ok
  end

  @doc """
  The scope site's mention with `id`, with its author, the post it answers
  and the members' replies to it.
  """
  @spec get!(Scope.t(), Ecto.UUID.t()) :: Mention.t()
  def get!(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one!(
      from m in Mention,
        where: m.site_id == ^site_id and m.id == ^id,
        preload: ^listed_preloads()
    )
  end

  defp listed_preloads, do: [:remote_account, :post, member_replies: member_replies_query()]

  defp member_replies_query,
    do: from(r in MemberReply, where: is_nil(r.deleted_at), order_by: [asc: r.inserted_at])

  @doc """
  Approves a public reply to a post of the scope's site, as the member saw
  it (its `version`, `Feather.Fediverse.Mention.version/1`), so the site
  shows it from the deploy this starts: its content and its author's
  name, handle and picture. The author's account is fetched again when
  its copy is a day old, and the picture downloaded
  (`Feather.Fediverse.Pictures`); without one the reply shows none. A
  mention or author that changed since that version, also by that fetch,
  or a mention changed, approved or deleted meanwhile, is not approved
  (`{:error, :changed}`). A site without a fediverse name approves
  nothing.
  """
  @spec approve(Scope.t(), Mention.t(), String.t()) ::
          {:ok, Mention.t()} | {:error, :not_approvable | :changed}
  def approve(
        %Scope{site: %Site{id: site_id} = site},
        %Mention{site_id: site_id} = mention,
        version
      ) do
    mention = Repo.preload(mention, [:remote_account, :post])

    cond do
      not (Fediverse.account?(site) and Mention.approvable?(mention)) ->
        {:error, :not_approvable}

      Mention.version(mention) != version ->
        {:error, :changed}

      true ->
        mention
        |> Map.update!(:remote_account, &author(site, &1))
        |> snapshot(site, version)
    end
  end

  defp snapshot(%Mention{remote_account: author} = mention, site, version) do
    if Mention.version(mention) == version do
      picture = Pictures.fetch(site, author)

      mention
      |> Mention.approval_changeset(:approved, %{
        approved_at: DateTime.utc_now(),
        approved_content: mention.content,
        approved_name: author.name,
        approved_handle: author.handle,
        approved_picture: picture
      })
      |> unless_changed(mention)
      |> Repo.update(stale_error_field: :approval)
      |> after_approval(site, mention, picture)
    else
      {:error, :changed}
    end
  end

  # Every change of a mention moves its updated_at, its approval and picture included.
  defp unless_changed(changeset, mention),
    do: %{changeset | filters: Map.put(changeset.filters, :updated_at, mention.updated_at)}

  defp after_approval({:ok, approved}, site, mention, _picture) do
    Pictures.mark_unused(site, [mention.approved_picture])
    Fediverse.deploy(site)
    {:ok, approved}
  end

  defp after_approval({:error, _stale}, _site, _mention, picture) do
    Pictures.delete(picture)
    {:error, :changed}
  end

  defp author(site, account) do
    case RemoteAccounts.get(site, account.uri) do
      {:ok, author} -> author
      {:error, _reason} -> account
    end
  end

  @doc """
  The picture of the author of the scope site's mention with `public_id`,
  fetched from its server (`Feather.Fediverse.Pictures.get/2`): the one
  approving the reply keeps. A site without a fediverse name has none.
  """
  @spec picture(Scope.t(), String.t()) :: {:ok, binary(), String.t()} | {:error, term()}
  def picture(%Scope{site: %Site{fediverse_name: nil}}, _public_id), do: {:error, :not_found}

  def picture(%Scope{site: %Site{id: site_id} = site}, public_id) do
    url =
      Repo.one(
        from m in Mention,
          join: a in assoc(m, :remote_account),
          where: m.site_id == ^site_id and m.public_id == ^public_id,
          select: a.picture_url
      )

    if url, do: Pictures.get(site, url), else: {:error, :not_found}
  end

  @doc """
  Hides a mention of the scope's site. A reply the site showed leaves it
  with a deploy.
  """
  @spec hide(Scope.t(), Mention.t()) :: {:ok, Mention.t()}
  def hide(%Scope{site: %Site{id: site_id} = site}, %Mention{site_id: site_id} = mention) do
    hidden = mention |> Mention.approval_changeset(:hidden) |> Repo.update!()

    Pictures.mark_unused(site, [mention.approved_picture])
    if mention.approval == :approved, do: Fediverse.deploy(site)
    {:ok, hidden}
  end

  @doc """
  The approved replies to `posts` of the site, by post id, oldest first,
  with their authors and the members' public replies to them, oldest
  first: what the site shows below each post.
  """
  @spec approved_replies(Site.t(), [Post.t()]) :: %{Ecto.UUID.t() => [Mention.t()]}
  def approved_replies(%Site{id: site_id}, posts) do
    post_ids = Enum.map(posts, & &1.id)

    from(m in Mention,
      where: m.site_id == ^site_id and m.post_id in ^post_ids,
      where: m.approval == :approved and m.visibility == :public,
      order_by: [asc: m.published_at, asc: m.inserted_at],
      preload: [
        :remote_account,
        member_replies: ^where(member_replies_query(), [r], r.visibility == :public)
      ]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.post_id)
  end

  @doc """
  The file names of the pictures the site keeps of the authors of its
  replies: those its approved replies show and those waiting for a deploy
  to be deleted.
  """
  @spec reply_pictures(Site.t()) :: [String.t()]
  def reply_pictures(%Site{id: site_id} = site) do
    shown =
      Repo.all(
        from m in Mention,
          where: m.site_id == ^site_id and not is_nil(m.approved_picture),
          select: m.approved_picture
      )

    shown ++ Pictures.unused(site)
  end
end
