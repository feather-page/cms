defmodule Feather.Fediverse.Deliveries do
  @moduledoc """
  The queue of activities a site's account sends to other servers.

  `deliver/3` stores an activity as one delivery per inbox, using a
  remote server's shared inbox where it offers one, and tries each at
  once (`deliver_all/3` several activities in one go): in the background,
  or right away with
  `config :feather, :fediverse_deliveries, :inline` (as in tests).
  `deliver_due/0`, run every minute by
  `Feather.Fediverse.Scheduler`, sends what is due again.

    * **Claims.** A delivery is claimed for 2 minutes before it is sent, so
      overlapping runs never send it twice; the claim of a run that
      crashed lapses.
    * **Backoff.** A failed delivery is tried again after a minute, then
      after twice as long each time, at most 12 hours. It is dropped when
      its next try would come more than 7 days after it was queued.
    * **Dead hosts.** A failure pushes every other delivery to the same
      host to at least the same time, and a delivery queued for such a
      host waits for it instead of being tried at once. Of the deliveries
      due at the same time, those tried more often go first.
    * **Busy.** A delivery that the CMS's own cap on requests at once
      (`Feather.Fediverse.Limiter`) turned away was not tried: it goes
      again a minute later, neither counted as an attempt nor holding up
      its host.
    * **Refusals.** A delivery that will never succeed is dropped at once:
      its inbox is not a public https address, or the server answers with
      a 3xx status or a 4xx status other than 401, 408 and 429.
    * **Online.** Deliveries of a site wait until a deploy has put its
      account online (`Feather.Fediverse.online?/1`).
    * **Encryption.** Payloads are stored encrypted, the public ones too:
      the private ones must be, and telling them apart would gain nothing.
  """

  import Ecto.Query, warn: false

  alias Feather.Fediverse.{Client, Delivery, RemoteAccount, SigningKey}
  alias Feather.Repo
  alias Feather.Sites.Site

  require Logger

  @claim_seconds 120
  @first_backoff_seconds 60
  @max_backoff_seconds 12 * 3600
  @lifetime_seconds 7 * 86_400
  @busy_retry_seconds 60
  @workers 4

  @doc """
  Queues `activity` from the site's account to the inboxes of the
  recipients and tries to deliver it at once.
  """
  @spec deliver(Site.t(), [RemoteAccount.t()], map()) :: :ok
  def deliver(%Site{} = site, recipients, %{} = activity),
    do: deliver_all(site, recipients, [activity])

  @doc """
  Queues the activities like `deliver/3` and tries to deliver them all in
  one run.
  """
  @spec deliver_all(Site.t(), [RemoteAccount.t()], [map()]) :: :ok
  def deliver_all(%Site{} = site, recipients, activities) when is_list(activities) do
    now = DateTime.utc_now()

    site
    |> queue(inboxes(recipients), Enum.map(activities, &Jason.encode!/1), now)
    |> Enum.filter(&(DateTime.compare(&1.next_attempt_at, now) != :gt))
    |> Enum.map(& &1.id)
    |> start_attempts()
  end

  defp queue(site, inboxes, payloads, now) do
    {:ok, deliveries} =
      Repo.transact(fn ->
        {:ok, for(payload <- payloads, inbox <- inboxes, do: insert!(site, inbox, payload, now))}
      end)

    deliveries
  end

  defp inboxes(recipients),
    do: recipients |> Enum.map(&(&1.shared_inbox || &1.inbox)) |> Enum.uniq()

  defp insert!(site, inbox, payload, now) do
    host = RemoteAccount.host(inbox)

    Repo.insert!(%Delivery{
      site_id: site.id,
      inbox: inbox,
      host: host,
      payload: payload,
      next_attempt_at: backing_off_until(host, now) || now
    })
  end

  defp backing_off_until(host, now) do
    Repo.one(
      from d in Delivery,
        where: d.host == ^host and d.attempts > 0 and d.next_attempt_at > ^now,
        order_by: [desc: d.next_attempt_at],
        limit: 1,
        select: d.next_attempt_at
    )
  end

  defp start_attempts([]), do: :ok

  defp start_attempts(ids) do
    case Application.get_env(:feather, :fediverse_deliveries, :background) do
      :inline -> attempt_due(ids)
      :background -> start_in_background(ids)
    end
  end

  defp start_in_background(ids) do
    case Task.Supervisor.start_child(Feather.TaskSupervisor, fn -> attempt_due(ids) end) do
      {:ok, _pid} -> :ok
      {:error, reason} -> Logger.error("Deliveries not started: #{inspect(reason)}")
    end
  end

  @doc """
  Drops the deliveries queued more than 7 days ago and sends the due ones,
  #{@workers} at a time.
  """
  @spec deliver_due() :: :ok
  def deliver_due do
    drop_expired()

    Feather.TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(1..@workers, fn _worker -> attempt_due(nil) end,
      max_concurrency: @workers,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.each(fn
      {:ok, :ok} -> :ok
      {:exit, reason} -> Logger.error("A delivery run failed: #{inspect(reason)}")
    end)
  end

  defp drop_expired do
    cutoff = DateTime.add(DateTime.utc_now(), -@lifetime_seconds)

    case Repo.delete_all(from d in Delivery, where: d.inserted_at < ^cutoff) do
      {0, _} -> :ok
      {count, _} -> Logger.warning("Dropped #{count} fediverse deliveries older than a week")
    end
  end

  defp attempt_due(only_ids) do
    case claim(only_ids) do
      nil ->
        :ok

      delivery ->
        delivery |> send_delivery() |> finish(delivery)
        attempt_due(only_ids)
    end
  end

  defp claim(only_ids) do
    now = DateTime.utc_now()

    {:ok, delivery} =
      Repo.transact(fn ->
        case only_ids |> due(now) |> Repo.one() do
          nil ->
            {:ok, nil}

          id ->
            {1, [delivery]} =
              Repo.update_all(from(d in Delivery, where: d.id == ^id, select: d),
                set: [claimed_until: DateTime.add(now, @claim_seconds)]
              )

            {:ok, delivery}
        end
      end)

    delivery
  end

  defp due(only_ids, now) do
    query =
      from d in Delivery,
        join: s in Site,
        on: s.id == d.site_id,
        where: d.next_attempt_at <= ^now,
        where: is_nil(d.claimed_until) or d.claimed_until <= ^now,
        where: not is_nil(s.fediverse_name) and not is_nil(s.fediverse_online_at),
        order_by: [asc: d.next_attempt_at, desc: d.attempts, asc: d.inserted_at],
        limit: 1,
        select: d.id

    if only_ids, do: where(query, [d], d.id in ^only_ids), else: query
  end

  defp send_delivery(delivery) do
    site = Repo.get!(Site, delivery.site_id)
    payload = Repo.one!(from d in Delivery, where: d.id == ^delivery.id, select: d.payload)
    Client.post(delivery.inbox, payload, SigningKey.for_site(site))
  rescue
    exception -> {:error, exception}
  end

  defp finish(:ok, delivery), do: delete(delivery)

  defp finish({:error, :busy}, delivery) do
    Repo.update_all(from(d in Delivery, where: d.id == ^delivery.id),
      set: [
        next_attempt_at: DateTime.add(DateTime.utc_now(), @busy_retry_seconds),
        claimed_until: nil
      ]
    )
  end

  defp finish({:error, reason}, delivery) do
    if refused?(reason) do
      Logger.warning("Delivery to #{delivery.inbox} refused: #{inspect(reason)}")
      delete(delivery)
    else
      retry(delivery, reason)
    end
  end

  defp refused?({:invalid_url, _message}), do: true
  defp refused?(:forbidden_address), do: true
  defp refused?(:too_many_redirects), do: true
  defp refused?({:forbidden_redirect, _message}), do: true
  defp refused?({:status, status}) when status in 300..499, do: status not in [401, 408, 429]
  defp refused?(_reason), do: false

  defp retry(delivery, reason) do
    now = DateTime.utc_now()
    attempts = delivery.attempts + 1
    next_attempt_at = DateTime.add(now, backoff_seconds(attempts))

    if DateTime.diff(next_attempt_at, delivery.inserted_at) > @lifetime_seconds do
      Logger.warning(
        "Delivery to #{delivery.inbox} dropped after #{attempts} attempts: #{inspect(reason)}"
      )

      delete(delivery)
    else
      Logger.info(
        "Delivery to #{delivery.inbox} failed (attempt #{attempts}): #{inspect(reason)}"
      )

      back_off(delivery, attempts, next_attempt_at)
    end
  end

  defp backoff_seconds(attempts),
    do: min(@first_backoff_seconds * 2 ** (attempts - 1), @max_backoff_seconds)

  defp back_off(delivery, attempts, next_attempt_at) do
    Repo.transact(fn ->
      Repo.update_all(from(d in Delivery, where: d.id == ^delivery.id),
        set: [attempts: attempts, next_attempt_at: next_attempt_at, claimed_until: nil]
      )

      Repo.update_all(
        from(d in Delivery,
          where:
            d.host == ^delivery.host and d.id != ^delivery.id and
              d.next_attempt_at < ^next_attempt_at
        ),
        set: [next_attempt_at: next_attempt_at]
      )

      {:ok, :backed_off}
    end)
  end

  defp delete(delivery), do: Repo.delete_all(from d in Delivery, where: d.id == ^delivery.id)
end
