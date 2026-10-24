defmodule Feather.Fediverse.FederatedObjects do
  @moduledoc """
  Sends a site's followers what each deploy changed (ADR 0033).

  After a successful deploy, `sync/2` compares the fediverse documents of
  the export, as the deploy put them online, with the federated objects
  (`Feather.Fediverse.FederatedObject`), which record a hash of each
  document last sent:

    * a post document that is new goes out in a `Create`, one whose hash
      changed in an `Update` that gives the time it goes out as `updated`,
      later than any `updated` sent of it before: Mastodon applies an
      `Update` of a post only then;
    * a post the export no longer has goes out in a `Delete`, once, and
      moves on to its next `fediverse_generation`: back on the site, it is
      a new document at a new address, since servers keep the old one
      deleted (`Feather.Content.Post`);
    * a changed account document goes out in an `Update` of the account.

  The activities go to every follower, once per remote shared inbox,
  through the delivery queue (`Feather.Fediverse.Deliveries`). The objects
  are recorded after their activities are queued, so a crash in between
  sends them again with the next deploy rather than never.

  Only the documents count: a scheduled post goes out with the first
  deploy after it became due, and a change that leaves the documents as
  they were, such as a new theme, sends nothing. The first comparison of
  an account, after the deploy that put it online, only records the
  documents: posts published before the site joined are not sent.
  """

  import Ecto.Query, warn: false

  alias Feather.Content.Post
  alias Feather.Fediverse
  alias Feather.Fediverse.{Deliveries, FederatedObject}
  alias Feather.{PublicId, Repo}
  alias Feather.Sites.Site
  alias Feather.StaticSite.{ActivityStreams, Routes}

  require Logger

  @activity_streams "https://www.w3.org/ns/activitystreams"
  @public "https://www.w3.org/ns/activitystreams#Public"

  @doc """
  Compares the fediverse documents that the export of `site` wrote below
  `dir` with the federated objects and sends the followers what changed
  (see the module doc). Does nothing unless the site's account is online.
  Failures are only logged: the deploy has succeeded.
  """
  @spec sync(Site.t(), Path.t()) :: :ok
  def sync(%Site{} = site, dir) do
    if Fediverse.account?(site) and online?(site) do
      routes = Routes.new(site)
      account = dir |> Path.join(Routes.activitypub_path(routes, :account)) |> read!(nil)
      compare(site, account, read_posts(site, dir, routes))
    end

    :ok
  rescue
    exception ->
      Logger.error(
        "Sending the followers of #{site.domain} what the deploy changed failed: " <>
          Exception.message(exception)
      )
  end

  defp online?(%Site{id: site_id}) do
    Repo.exists?(from s in Site, where: s.id == ^site_id and not is_nil(s.fediverse_online_at))
  end

  defp read_posts(site, dir, routes) do
    from(p in Post,
      where: p.site_id == ^site.id,
      select: struct(p, [:id, :public_id, :fediverse_generation])
    )
    |> Repo.all()
    |> Enum.flat_map(fn post ->
      path = Path.join(dir, Routes.activitypub_path(routes, post))
      if File.exists?(path), do: [read!(path, post.id)], else: []
    end)
  end

  defp read!(path, post_id) do
    json = File.read!(path)
    document = Jason.decode!(json)

    %{
      uri: Map.fetch!(document, "id"),
      post_id: post_id,
      document: document,
      hash: :sha256 |> :crypto.hash(json) |> Base.encode16(case: :lower),
      updated_at: updated_at(document)
    }
  end

  defp updated_at(document) do
    case document["updated"] || document["published"] do
      nil ->
        nil

      time ->
        {:ok, datetime, 0} = DateTime.from_iso8601(time)
        datetime
    end
  end

  defp compare(site, account, posts) do
    objects = Repo.all(from o in FederatedObject, where: o.site_id == ^site.id)

    if Enum.any?(objects, &(&1.uri == account.uri)),
      do: send_changes(site, account, posts, objects),
      else: record_first(site, [account | posts])
  end

  # Objects of an account at another address (an earlier domain) are not this account's.
  defp record_first(site, documents) do
    {:ok, :recorded} =
      Repo.transact(fn ->
        Repo.delete_all(from o in FederatedObject, where: o.site_id == ^site.id)
        Enum.each(documents, &insert!(site, &1))
        {:ok, :recorded}
      end)
  end

  defp send_changes(site, account, posts, objects) do
    now = DateTime.utc_now(:second)

    case changes([account | posts], objects, now) ++ removals(account, posts, objects) do
      [] ->
        :ok

      changes ->
        activities = Enum.map(changes, &activity(&1, account.uri))
        :ok = Deliveries.deliver_all(site, Fediverse.followers(site), activities)
        record!(site, changes)
    end
  end

  defp changes(documents, objects, now) do
    objects_by_uri = Map.new(objects, &{&1.uri, &1})
    Enum.flat_map(documents, &change(&1, Map.get(objects_by_uri, &1.uri), now))
  end

  defp removals(account, posts, objects) do
    exported = MapSet.new([account | posts], & &1.uri)

    for object <- objects,
        not object.deleted and object.uri != account.uri,
        not MapSet.member?(exported, object.uri),
        do: {:delete, nil, object}
  end

  defp change(document, nil, _now), do: [{:create, document, nil}]
  defp change(%{hash: hash}, %FederatedObject{document_hash: hash}, _now), do: []
  defp change(%{post_id: nil} = account, object, _now), do: [{:update, account, object}]
  defp change(post, object, now), do: [{:update, stamp(post, object, now), object}]

  defp stamp(post, object, now) do
    updated_at = later(now, object.document_updated_at)

    %{
      post
      | updated_at: updated_at,
        document: Map.put(post.document, "updated", DateTime.to_iso8601(updated_at))
    }
  end

  defp later(now, nil), do: now
  defp later(now, last), do: Enum.max([now, DateTime.add(last, 1)], DateTime)

  defp activity({:create, %{document: document}, _object}, _actor),
    do: ActivityStreams.create_activity(document)

  defp activity({:update, %{uri: uri, document: document}, _object}, actor) do
    {context, object} = Map.pop(document, "@context")

    %{
      "@context" => context,
      "id" => uri <> "#updates/" <> PublicId.generate(),
      "type" => "Update",
      "actor" => actor,
      "to" => [@public],
      "object" => object
    }
  end

  defp activity({:delete, nil, %FederatedObject{uri: uri}}, actor) do
    %{
      "@context" => @activity_streams,
      "id" => uri <> "#delete",
      "type" => "Delete",
      "actor" => actor,
      "to" => [@public],
      "object" => %{"id" => uri, "type" => "Tombstone"}
    }
  end

  defp record!(site, changes) do
    {:ok, :recorded} =
      Repo.transact(fn ->
        Enum.each(changes, &record_change!(site, &1))
        {:ok, :recorded}
      end)
  end

  defp record_change!(site, {:create, document, nil}), do: insert!(site, document)

  defp record_change!(_site, {:delete, nil, object}) do
    object |> Ecto.Changeset.change(deleted: true) |> Repo.update!()
    next_generation!(object.post_id)
  end

  defp record_change!(_site, {:update, document, object}) do
    object
    |> Ecto.Changeset.change(
      document_hash: document.hash,
      document_updated_at: document.updated_at
    )
    |> Repo.update!()
  end

  defp next_generation!(nil), do: :ok

  defp next_generation!(post_id) do
    Repo.update_all(from(p in Post, where: p.id == ^post_id), inc: [fediverse_generation: 1])
    :ok
  end

  defp insert!(site, document) do
    Repo.insert!(%FederatedObject{
      site_id: site.id,
      post_id: document.post_id,
      uri: document.uri,
      document_hash: document.hash,
      document_updated_at: document.updated_at
    })
  end
end
