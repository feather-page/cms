defmodule Feather.Fediverse.Following do
  @moduledoc """
  The accounts a site follows (`Feather.Fediverse.FollowedAccount`), whose
  posts make up its Timeline (`Feather.Fediverse.Timeline`).

    * **Following.** `follow/2` takes one or more handles at once, as a
      list pasted from elsewhere: words that are no handles are skipped, a
      handle without a server (`@ana`) is reported. Each handle is
      resolved through WebFinger (`Feather.Fediverse.RemoteAccounts.resolve/2`)
      and its account gets a `Follow` through the delivery queue, which
      holds it until the site's account is online. An account the site
      follows already is not followed again, nor is the site's own or one
      the site blocked (`Feather.Fediverse.Blocks`).
    * **Accept and Reject.** The inbox records the `Accept` of a follow
      (`accept/2`); a `Reject` ends it (`reject/2`). Only an accepted
      follow brings the account's posts to its followers.
    * **Unfollowing.** `unfollow/2` sends the `Undo` of the follow. Ending a
      follow either way takes the account's posts out of the Timeline.
  """

  import Ecto.Changeset, only: [change: 1, unique_constraint: 2]
  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Fediverse
  alias Feather.Fediverse.{Blocks, Deliveries, FollowedAccount, RemoteAccount, RemoteAccounts}
  alias Feather.{Pagination, PublicId, Repo}
  alias Feather.Sites.Site

  @activity_streams "https://www.w3.org/ns/activitystreams"
  @max_handles 200
  @concurrency 4
  @separators ~r/[\s,;]+/u
  @punctuation "()<>[]{}\"'."

  @type result ::
          {:ok, FollowedAccount.t()}
          | {:error, :invalid_handle | :not_found | :own_account | :blocked}

  @doc """
  Follows the accounts of the handles in `text` (see the module doc) and
  returns each handle with its result, in the order given. At most
  #{@max_handles} handles at once.
  """
  @spec follow(Scope.t(), String.t()) ::
          {:ok, [{String.t(), result()}]}
          | {:error, :not_an_account | :no_handles | :too_many_handles}
  def follow(%Scope{site: %Site{} = site}, text) when is_binary(text) do
    handles = handles(text)

    cond do
      not Fediverse.account?(site) -> {:error, :not_an_account}
      handles == [] -> {:error, :no_handles}
      length(handles) > @max_handles -> {:error, :too_many_handles}
      true -> {:ok, follow_all(site, handles)}
    end
  end

  defp handles(text) do
    text
    |> String.split(@separators, trim: true)
    |> Enum.map(&String.trim(&1, @punctuation))
    |> Enum.flat_map(&handle/1)
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp handle(word) do
    bare = word |> String.replace_prefix("acct:", "") |> String.trim_leading("@")

    cond do
      String.contains?(bare, "@") -> ["@" <> bare]
      String.starts_with?(word, "@") and bare != "" -> [word]
      true -> []
    end
  end

  defp follow_all(site, handles) do
    handles
    |> Task.async_stream(&follow_handle(site, &1),
      max_concurrency: @concurrency,
      timeout: :infinity
    )
    |> Enum.zip_with(handles, fn {:ok, result}, handle -> {handle, result} end)
  end

  defp follow_handle(site, handle) do
    with {:ok, account} <- RemoteAccounts.resolve(site, handle) do
      cond do
        account.uri == Fediverse.account_url(site) -> {:error, :own_account}
        Blocks.blocked?(site, account.uri) -> {:error, :blocked}
        true -> {:ok, follow_account(site, account)}
      end
    end
  end

  defp follow_account(site, account) do
    followed = %FollowedAccount{
      site_id: site.id,
      remote_account_id: account.id,
      follow_id: Fediverse.account_url(site) <> "#follows/" <> PublicId.generate()
    }

    insert =
      followed
      |> change()
      |> PublicId.put()
      |> unique_constraint([:site_id, :remote_account_id])
      |> Repo.insert()

    case insert do
      {:ok, followed} ->
        :ok = Deliveries.deliver(site, [account], follow_activity(site, followed, account))
        %{followed | remote_account: account}

      {:error, _taken} ->
        get_by_account(site, account)
    end
  end

  defp follow_activity(site, followed, account) do
    %{
      "@context" => @activity_streams,
      "id" => followed.follow_id,
      "type" => "Follow",
      "actor" => Fediverse.account_url(site),
      "object" => account.uri
    }
  end

  defp get_by_account(site, account) do
    FollowedAccount
    |> Repo.get_by!(site_id: site.id, remote_account_id: account.id)
    |> Map.put(:remote_account, account)
  end

  @doc "The site's follow of the account at `uri`, with its account, or nil."
  @spec get_by_uri(Site.t(), String.t()) :: FollowedAccount.t() | nil
  def get_by_uri(%Site{id: site_id}, uri) when is_binary(uri) do
    Repo.one(
      from f in FollowedAccount,
        join: a in assoc(f, :remote_account),
        where: f.site_id == ^site_id and a.uri == ^uri,
        preload: [remote_account: a]
    )
  end

  def get_by_uri(%Site{}, _uri), do: nil

  @doc "Records that `account` accepted the site's follow."
  @spec accept(Site.t(), RemoteAccount.t()) :: :ok
  def accept(%Site{id: site_id}, %RemoteAccount{id: account_id}) do
    Repo.update_all(
      from(f in FollowedAccount,
        where:
          f.site_id == ^site_id and f.remote_account_id == ^account_id and
            is_nil(f.accepted_at)
      ),
      set: [accepted_at: DateTime.utc_now()]
    )

    :ok
  end

  @doc "Ends the site's follow of `account`, which refused it, with its posts."
  @spec reject(Site.t(), RemoteAccount.t()) :: :ok
  def reject(%Site{id: site_id}, %RemoteAccount{id: account_id}) do
    Repo.delete_all(
      from f in FollowedAccount,
        where: f.site_id == ^site_id and f.remote_account_id == ^account_id
    )

    :ok
  end

  @doc """
  Unfollows an account the scope's site follows: sends the `Undo` of the
  follow and takes the account's posts out of the Timeline.
  """
  @spec unfollow(Scope.t(), FollowedAccount.t()) :: :ok
  def unfollow(
        %Scope{site: %Site{id: site_id} = site},
        %FollowedAccount{site_id: site_id} = followed
      ) do
    followed = Repo.preload(followed, :remote_account)
    Repo.delete!(followed, allow_stale: true)
    Deliveries.deliver(site, [followed.remote_account], undo_activity(site, followed))
  end

  defp undo_activity(site, followed) do
    follow = site |> follow_activity(followed, followed.remote_account) |> Map.delete("@context")

    %{
      "@context" => @activity_streams,
      "id" => followed.follow_id <> "/undo",
      "type" => "Undo",
      "actor" => Fediverse.account_url(site),
      "object" => follow
    }
  end

  @doc "The scope site's follow with `id`, with its account."
  @spec get!(Scope.t(), Ecto.UUID.t()) :: FollowedAccount.t()
  def get!(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one!(
      from f in FollowedAccount,
        where: f.site_id == ^site_id and f.id == ^id,
        preload: :remote_account
    )
  end

  @doc "One page of the accounts the scope's site follows, newest first."
  @spec paginate(Scope.t(), pos_integer() | String.t() | nil) :: Pagination.t()
  def paginate(%Scope{site: %Site{id: site_id}}, page) do
    query =
      from f in FollowedAccount,
        where: f.site_id == ^site_id,
        order_by: [desc: f.inserted_at],
        preload: :remote_account

    Pagination.paginate(query, page)
  end

  @doc "The number of accounts that accepted the follow of the scope's site."
  @spec count(Scope.t()) :: non_neg_integer()
  def count(%Scope{site: %Site{id: site_id}}) do
    Repo.aggregate(
      from(f in FollowedAccount, where: f.site_id == ^site_id and not is_nil(f.accepted_at)),
      :count
    )
  end
end
