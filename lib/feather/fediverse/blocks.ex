defmodule Feather.Fediverse.Blocks do
  @moduledoc """
  The accounts and servers a site's members blocked
  (`Feather.Fediverse.Block`). Blocking a server blocks every account on
  it and on its subdomains.

    * **Blocking.** `block/3` ends the follows between the site and the
      blocked accounts both ways, with the `Undo` of the site's follow and
      a `Reject` of theirs, and deletes their mentions; their approved
      replies leave the site with a deploy. A blocked account also gets a
      `Block`, which its server takes as the end of both follows too.
    * **Afterwards.** The inbox drops what blocked accounts send
      (`blocked?/2`) and refuses their follows with `Reject`
      (`refuse_follow/3`, see `Feather.Fediverse.Inbox`); members cannot
      follow them (`Feather.Fediverse.Following`).
    * **Unblocking.** `unblock/2` sends the `Undo` of an account's `Block`.
      The follows it ended stay ended.
  """

  import Ecto.Changeset, only: [change: 2, unique_constraint: 2]
  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Fediverse

  alias Feather.Fediverse.{
    Block,
    Deliveries,
    FollowedAccount,
    Follower,
    Following,
    Mentions,
    RemoteAccount,
    RemoteAccounts
  }

  alias Feather.{PublicId, Repo}
  alias Feather.Sites.Site

  @activity_streams "https://www.w3.org/ns/activitystreams"

  @doc "Returns true if the site blocked the account at `uri`, its server or a parent domain."
  @spec blocked?(Site.t(), String.t()) :: boolean()
  def blocked?(%Site{id: site_id}, uri) when is_binary(uri) do
    domains = domains(RemoteAccount.host(uri))

    Repo.exists?(
      from b in Block,
        where: b.site_id == ^site_id and (b.account_uri == ^uri or b.host in ^domains)
    )
  end

  defp domains(host) do
    labels = String.split(host, ".")
    for n <- 0..(length(labels) - 1), do: labels |> Enum.drop(n) |> Enum.join(".")
  end

  @doc """
  Blocks `account` (`:account`) or every account on its server
  (`:server`) for the scope's site, an account in the fediverse (see the
  module doc). Blocking again changes nothing.
  """
  @spec block(Scope.t(), RemoteAccount.t(), :account | :server) :: {:ok, Block.t()}
  def block(%Scope{site: %Site{fediverse_name: name} = site} = scope, account, what)
      when is_binary(name) and what in [:account, :server] do
    insert =
      %Block{site_id: site.id}
      |> change(target(account, what))
      |> unique_constraint([:site_id, :account_uri])
      |> unique_constraint([:site_id, :host])
      |> Repo.insert()

    case insert do
      {:ok, block} ->
        :ok = end_relations(scope, block, account)
        {:ok, block}

      {:error, _taken} ->
        {:ok, find!(site, account, what)}
    end
  end

  defp target(%RemoteAccount{} = account, :account),
    do: %{account_uri: account.uri, handle: account.handle}

  defp target(%RemoteAccount{} = account, :server), do: %{host: RemoteAccount.host(account.uri)}

  defp find!(site, account, :account),
    do: Repo.get_by!(Block, site_id: site.id, account_uri: account.uri)

  defp find!(site, account, :server),
    do: Repo.get_by!(Block, site_id: site.id, host: RemoteAccount.host(account.uri))

  defp end_relations(%Scope{site: site} = scope, block, account) do
    accounts = blocked_accounts(block, account)

    unfollow(scope, accounts)
    remove_followers(site, accounts)
    :ok = Mentions.delete_by_authors(site, accounts)

    if Block.server?(block),
      do: :ok,
      else: Deliveries.deliver(site, [account], block_activity(site, block))
  end

  defp blocked_accounts(%Block{account_uri: nil, host: host}, _account) do
    # LIKE only narrows the search: it ignores case, and the host may go on.
    from(a in RemoteAccount,
      where: like(a.uri, ^"https://#{host}%") or like(a.uri, ^"https://%.#{host}%")
    )
    |> Repo.all()
    |> Enum.filter(&(host in domains(RemoteAccount.host(&1.uri))))
  end

  defp blocked_accounts(%Block{}, account), do: [account]

  defp unfollow(%Scope{site: site} = scope, accounts) do
    account_ids = Enum.map(accounts, & &1.id)

    from(f in FollowedAccount,
      where: f.site_id == ^site.id and f.remote_account_id in ^account_ids
    )
    |> Repo.all()
    |> Enum.each(&Following.unfollow(scope, &1))
  end

  defp remove_followers(site, accounts) do
    account_ids = Enum.map(accounts, & &1.id)

    followers =
      Repo.all(
        from f in Follower,
          where: f.site_id == ^site.id and f.remote_account_id in ^account_ids,
          preload: :remote_account
      )

    Repo.delete_all(from f in Follower, where: f.id in ^Enum.map(followers, & &1.id))
    Enum.each(followers, &refuse_follow(site, &1.remote_account, &1.follow_id))
  end

  @doc "Refuses the `Follow` with `follow_id` of `account` with a `Reject`."
  @spec refuse_follow(Site.t(), RemoteAccount.t(), String.t()) :: :ok
  def refuse_follow(%Site{} = site, %RemoteAccount{} = account, follow_id) do
    account_url = Fediverse.account_url(site)

    Deliveries.deliver(site, [account], %{
      "@context" => @activity_streams,
      "id" => account_url <> "#rejects/follows/" <> PublicId.generate(),
      "type" => "Reject",
      "actor" => account_url,
      "object" => %{
        "id" => follow_id,
        "type" => "Follow",
        "actor" => account.uri,
        "object" => account_url
      }
    })
  end

  defp block_activity(site, block) do
    account_url = Fediverse.account_url(site)

    %{
      "@context" => @activity_streams,
      "id" => account_url <> "#blocks/" <> block.id,
      "type" => "Block",
      "actor" => account_url,
      "object" => block.account_uri
    }
  end

  @doc """
  Lifts a block of the scope's site. An account's server gets the `Undo`
  of its `Block`.
  """
  @spec unblock(Scope.t(), Block.t()) :: :ok
  def unblock(%Scope{site: %Site{id: site_id} = site}, %Block{site_id: site_id} = block) do
    Repo.delete!(block, allow_stale: true)

    if Block.server?(block) or not Fediverse.account?(site),
      do: :ok,
      else: send_undo(site, block)
  end

  defp send_undo(site, block) do
    case RemoteAccounts.get(site, block.account_uri) do
      {:ok, account} -> Deliveries.deliver(site, [account], undo_activity(site, block))
      {:error, _reason} -> :ok
    end
  end

  defp undo_activity(site, block) do
    sent = block_activity(site, block)

    %{
      "@context" => @activity_streams,
      "id" => sent["id"] <> "/undo",
      "type" => "Undo",
      "actor" => sent["actor"],
      "object" => Map.delete(sent, "@context")
    }
  end

  @doc "The blocks of the scope's site, newest first."
  @spec list(Scope.t()) :: [Block.t()]
  def list(%Scope{site: %Site{id: site_id}}),
    do: Repo.all(from b in Block, where: b.site_id == ^site_id, order_by: [desc: b.inserted_at])

  @doc "The scope site's block with `id`."
  @spec get!(Scope.t(), Ecto.UUID.t()) :: Block.t()
  def get!(%Scope{site: %Site{id: site_id}}, id),
    do: Repo.get_by!(Block, id: id, site_id: site_id)
end
