defmodule Feather.Fediverse.Inbox do
  @moduledoc """
  The inbox of a site's account (ADR 0033), where fediverse servers post
  activities (`Feather.Fediverse.inbox_url/1`). `receive_activity/3` takes
  an activity that `FeatherWeb.FediverseInboxController` admitted and
  decides, in this order:

    1. The site must be an account (else `:not_found`).
    2. The activity needs an id, a type and an actor, the id on the
       actor's origin (else `:invalid`).
    3. The request must carry a signature (`Feather.Fediverse.Signature`)
       with its keyId on the actor's origin (else `:unauthorized`);
       checking that fetches nothing.
    4. An actor the CMS knows must have signed it (else `:unauthorized`)
       before the inbox decides whether it handles the activity, so that
       its answer tells nobody whom the site follows, who follows it, whom
       it blocked or what its Mentions hold. The actor's cached key is
       tried first; else the actor is fetched again, at most once per 10
       minutes, so a failing key is not fetched again meanwhile; a fetch
       the limiter turned away (`:busy`) does not count.
    5. `Create`, `Update` and `Delete` must concern the actor's own
       objects: on its origin, attributed to it, and of all accounts only
       its own (else `:forbidden`).
    6. What the inbox does not handle is accepted at once, from an actor
       the CMS does not know without fetching anything: everything from
       an account the site blocked or from its server
       (`Feather.Fediverse.Blocks`) but a follow of the site's account,
       likes, boosts and other types, follows of other accounts, `Undo` of
       anything but a follower's follow, `Accept` and `Reject` of anything
       but the site's follow of the actor, `Create` of anything neither
       addressed to the site's account nor by an account it follows,
       `Update` of unknown accounts and objects and of mentions and
       Timeline posts by someone else, and every `Delete` of an actor the
       CMS does not know.
    7. An actor the CMS does not know is fetched to check that it signed
       the activity, as in 4. Whatever a fetch found, a failure is
       `:unauthorized`. The fetches of 4 and 7 have a pool of their own in
       `Feather.Fediverse.Limiter`.
    8. At most 300 signed activities per remote host within 5 minutes go
       on (else `:rate_limited`); forged ones do not count against it.

  An accepted activity is stored before the answer, its JSON encrypted
  (`Feather.Fediverse.ReceivedActivity`), and processed right away: in the
  background, at once with `config :feather, :fediverse_inbox, :inline`
  (as in tests), or only by the scheduler with `:scheduler`.
  `process_due/0`, run every minute by `Feather.Fediverse.Scheduler`,
  processes what was left: an activity whose processing failed goes again
  after a minute, then after twice as long each time, one that a crash or
  restart interrupted once its claim of 2 minutes lapsed, and one not
  processed within a day is given up. Processing decides afresh what the
  activity asks for; doing it twice does no harm. Only a processed
  activity counts as received: its JSON is deleted, its id kept for 30
  days (`purge_received/0`), and the same activity of the same actor is
  then accepted without being processed again; one not processed yet is
  processed when it comes again.

  A `Follow` of the site's account makes the actor a follower and
  is answered with `Accept` through the delivery queue, which holds it
  until the account is online; a blocked actor's is answered with
  `Reject`, and so is a new follower's once 100 accounts of its server
  became followers within the hour, so that no server floods the site
  with followers; they may follow again later. Its `Undo` removes the
  follower. `Accept` and `Reject` of the site's own follow accept or end
  it (`Feather.Fediverse.Following`). A note or article addressed to the
  account goes into its Mentions (`Feather.Fediverse.Mentions`), one by an
  account it follows into its Timeline (`Feather.Fediverse.Timeline`),
  possibly both; its `Update` changes them and its `Delete` removes them,
  leaving a tombstone (`Feather.Fediverse.Tombstone`). The `Delete` of
  anything else by an actor the CMS knows leaves a tombstone too, without
  fetching it, so that a `Create` of it that comes later or again is not
  filed. The `Delete` of an account removes its follows both ways, its
  mentions with the pictures of its approved replies, its Timeline posts,
  the site's pending deliveries to its own inbox and its cached copy.
  Deliveries to a shared inbox stay: they carry activities for other
  accounts too.

  A rejection with `:invalid`, `:unauthorized` or `:forbidden` is logged
  at info with its cause (for `:unauthorized` the failed check of
  `Feather.Fediverse.Signature.check/3`, `:key_origin`, `:key_fetch_limited`,
  `{:key_fetch_failed, reason}` or `:not_verified`), the activity's type,
  the hosts of its actor and keyId and the names of the signed headers
  (`invalid` for a malformed list or more than 16),
  for a wrong host or a stale date also the header received; never the
  body or the signature. The answer stays as it was.

  `check_client/1` limits the requests per client: at most 300 within 5
  minutes, from an IPv6 client per /64 network, which a client usually
  has whole.
  """

  import Ecto.Query, warn: false
  import Feather.Fediverse.RemoteAccount, only: [same_origin?: 2]
  import Feather.Fediverse.RemoteObject, only: [id_of: 1]

  alias Feather.Fediverse

  alias Feather.Fediverse.{
    Blocks,
    Deliveries,
    Delivery,
    FollowedAccount,
    Follower,
    Following,
    Mentions,
    RateLimit,
    ReceivedActivity,
    RemoteAccount,
    RemoteAccounts,
    Signature,
    Timeline,
    Tombstone
  }

  alias Feather.{PublicId, Repo}
  alias Feather.Sites.Site

  require Logger

  @activity_streams "https://www.w3.org/ns/activitystreams"
  @window_ms :timer.minutes(5)
  @client_limit 300
  @host_limit 300
  @key_fetch_interval_ms :timer.minutes(10)
  @new_followers_per_hour 100
  @received_days 30
  @claim_seconds 120
  @first_retry_seconds 60
  @lifetime_seconds 86_400
  @authored_types ~w(Create Update Delete)

  @type error :: :not_found | :invalid | :forbidden | :rate_limited | :unauthorized

  @doc "Counts a request to an inbox from the client at `ip`."
  @spec check_client(:inet.ip_address()) :: :ok | {:error, :rate_limited}
  def check_client(ip),
    do: RateLimit.hit({:inbox_client, client_network(ip)}, @client_limit, @window_ms)

  defp client_network({a, b, c, d, _e, _f, _g, _h}) when a in 0x2000..0x3FFF, do: {a, b, c, d}
  defp client_network(ip), do: ip

  @doc "Forgets the activities the inboxes took in more than #{@received_days} days ago."
  @spec purge_received() :: :ok
  def purge_received do
    cutoff = DateTime.add(DateTime.utc_now(), -@received_days, :day)
    Repo.delete_all(from r in ReceivedActivity, where: r.inserted_at < ^cutoff)
    :ok
  end

  @doc """
  Takes in `activity`, posted in `request` (with its raw body) to the
  inbox of the site with `site_public_id` (see the module doc). `:ok`
  means accepted.
  """
  @spec receive_activity(String.t(), Signature.request(), map()) :: :ok | {:error, error()}
  def receive_activity(site_public_id, request, activity) do
    with {:ok, site} <- fetch_site(site_public_id),
         {:ok, activity} <- validate(activity),
         {:ok, account} <- admit(site, request, activity) do
      store(site, account, activity)
    else
      :ignore ->
        :ok

      {:error, {:unauthorized, cause}} ->
        reject(:unauthorized, cause, request, activity)

      {:error, reason} when reason in [:invalid, :forbidden] ->
        reject(reason, nil, request, activity)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reject(reason, cause, request, activity) do
    signature = Signature.summary(request)

    [
      "Inbox rejected #{log_type(activity["type"])} from #{log_host(id_of(activity["actor"]))}:",
      reason,
      cause && log_cause(cause),
      "key_host=#{log_host(signature.key_id)}",
      "signed=#{log_signed(signature.headers)}",
      received(cause, request)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> Logger.info()

    {:error, reason}
  end

  defp log_type(type) when is_binary(type),
    do: if(type =~ ~r/\A\w{1,64}\z/, do: type, else: "activity")

  defp log_type(_type), do: "activity"

  defp log_signed(nil), do: "none"

  defp log_signed(names) do
    {shown, rest} = Enum.split(names, 16)

    if rest == [] and Enum.all?(shown, &(&1 =~ ~r/\A[a-z0-9()_-]{1,64}\z/)),
      do: Enum.join(shown, ","),
      else: "invalid"
  end

  defp log_host(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{host: host}} when is_binary(host) and host != "" -> host
      _other -> "none"
    end
  end

  defp log_host(_url), do: "none"

  defp log_cause({stage, reason}), do: "#{stage}:#{inspect(reason, printable_limit: 300)}"
  defp log_cause(cause), do: to_string(cause)

  defp received(:wrong_host, request), do: "host=" <> received_header(request, "host")
  defp received(:stale, request), do: "date=" <> received_header(request, "date")
  defp received(_cause, _request), do: nil

  defp received_header(request, name) do
    values = for {^name, value} <- request.headers, do: value
    inspect(Enum.join(values, ", "), printable_limit: 100)
  end

  defp admit(site, request, %{"actor" => actor} = activity) do
    with {:ok, signature} <- check_signature(request, actor),
         {:ok, known} <- known_signer(site, signature, actor),
         :ok <- check_authorship(activity),
         {:handle, _action} <- action(site, activity, known),
         {:ok, account} <- signer(site, signature, actor, known),
         :ok <- check_host(actor),
         do: {:ok, account}
  end

  defp fetch_site(public_id) do
    query = from s in Site, where: s.public_id == ^public_id and not is_nil(s.fediverse_name)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      site -> {:ok, site}
    end
  end

  defp validate(%{"id" => id, "type" => type, "actor" => actor} = activity)
       when is_binary(id) and is_binary(type) do
    actor = id_of(actor)

    if RemoteAccount.https_url?(id) and RemoteAccount.https_url?(actor) and
         same_origin?(id, actor),
       do: {:ok, %{activity | "actor" => actor}},
       else: {:error, :invalid}
  end

  defp validate(_activity), do: {:error, :invalid}

  defp check_authorship(%{"type" => type, "actor" => actor} = activity)
       when type in @authored_types do
    object = activity["object"]
    object_id = id_of(object)

    cond do
      not (is_binary(object_id) and same_origin?(object_id, actor)) -> {:error, :forbidden}
      object_id == actor -> :ok
      not authored?(type, object, actor) -> {:error, :forbidden}
      known_account?(object_id) -> {:error, :forbidden}
      true -> :ok
    end
  end

  defp check_authorship(_activity), do: :ok

  defp authored?("Create", object, actor), do: attributed_to(object) == [actor]
  defp authored?(_update_or_delete, object, actor), do: attributed_to(object) in [[], [actor]]

  defp attributed_to(%{"attributedTo" => attributed_to}),
    do: attributed_to |> List.wrap() |> Enum.map(&id_of/1)

  defp attributed_to(_object), do: []

  defp action(site, %{"actor" => actor} = activity, signer) do
    cond do
      Blocks.blocked?(site, actor) -> refusal(site, activity)
      activity["type"] == "Delete" -> deletion(site, activity, signer)
      true -> handling(site, activity)
    end
  end

  defp refusal(site, %{"type" => "Follow"} = activity) do
    if follows_site?(site, activity), do: {:handle, :refuse_follow}, else: :ignore
  end

  defp refusal(_site, _activity), do: :ignore

  defp handling(site, %{"type" => "Follow"} = activity) do
    if follows_site?(site, activity), do: {:handle, :follow}, else: :ignore
  end

  defp handling(site, %{"type" => "Undo", "actor" => actor} = activity) do
    case follower(site, actor) do
      %Follower{} = follower ->
        if undoes_follow?(activity["object"], follower, site),
          do: {:handle, :unfollow},
          else: :ignore

      nil ->
        :ignore
    end
  end

  defp handling(site, %{"type" => type, "actor" => actor} = activity)
       when type in ["Accept", "Reject"] do
    with %FollowedAccount{} = followed <- Following.get_by_uri(site, actor),
         true <- answers_follow?(activity["object"], followed, site) do
      {:handle, if(type == "Accept", do: :accept_follow, else: :reject_follow)}
    else
      _other -> :ignore
    end
  end

  defp handling(site, %{"type" => "Create", "actor" => actor, "object" => object}) do
    handle([
      Mentions.addresses?(site, object) && :file_mention,
      Timeline.files?(site, actor, object) && :file_timeline_post
    ])
  end

  defp handling(site, %{"type" => "Update", "actor" => actor, "object" => %{} = object}) do
    object_id = id_of(object)

    handle([
      Mentions.filed?(site, object_id, actor) && :update_mention,
      Timeline.filed?(site, object_id, actor) && :update_timeline_post
    ])
  end

  defp handling(_site, _activity), do: :ignore

  defp deletion(_site, _delete, nil), do: :ignore

  defp deletion(site, %{"actor" => actor} = delete, %RemoteAccount{}) do
    object_id = id_of(delete["object"])

    if object_id == actor do
      {:handle, :delete_account}
    else
      handled =
        handle([
          Mentions.filed?(site, object_id, actor) && :delete_mention,
          Timeline.filed?(site, object_id, actor) && :delete_timeline_post
        ])

      if handled == :ignore, do: {:handle, :tombstone}, else: handled
    end
  end

  defp follows_site?(site, follow), do: id_of(follow["object"]) == Fediverse.account_url(site)

  defp handle(actions) do
    case Enum.filter(actions, & &1) do
      [] -> :ignore
      [action] -> {:handle, action}
      actions -> {:handle, actions}
    end
  end

  defp follower(site, actor) do
    Repo.one(
      from f in Follower,
        join: a in assoc(f, :remote_account),
        where: f.site_id == ^site.id and a.uri == ^actor
    )
  end

  # Matched by id where the Undo names one: a follow sent again must not be undone by an older Undo.
  defp undoes_follow?(object, follower, site) do
    case id_of(object) do
      nil ->
        is_map(object) and object["type"] == "Follow" and
          id_of(object["object"]) == Fediverse.account_url(site)

      id ->
        id == follower.follow_id
    end
  end

  defp answers_follow?(object, followed, site) do
    case id_of(object) do
      nil ->
        is_map(object) and object["type"] == "Follow" and
          id_of(object["actor"]) == Fediverse.account_url(site) and
          id_of(object["object"]) == followed.remote_account.uri

      id ->
        id == followed.follow_id
    end
  end

  defp known_account?(uri), do: Repo.exists?(from a in RemoteAccount, where: a.uri == ^uri)

  defp check_signature(request, actor) do
    with {:ok, signature} <- Signature.check(request, public_host()),
         true <- same_origin?(signature.key_id, actor) do
      {:ok, signature}
    else
      {:error, reason} -> {:error, {:unauthorized, reason}}
      false -> {:error, {:unauthorized, :key_origin}}
    end
  end

  defp known_signer(site, signature, actor) do
    case Repo.get_by(RemoteAccount, uri: actor) do
      %RemoteAccount{} = account ->
        if signed_by?(signature, account),
          do: {:ok, account},
          else: fetch_signer(site, signature, actor)

      nil ->
        {:ok, nil}
    end
  end

  defp signer(_site, _signature, _actor, %RemoteAccount{} = known), do: {:ok, known}
  defp signer(site, signature, actor, nil), do: fetch_signer(site, signature, actor)

  defp fetch_signer(site, signature, actor) do
    with :ok <- allow_key_fetch(actor),
         {:ok, account} <- fetch_account(site, actor),
         true <- signed_by?(signature, account) do
      {:ok, account}
    else
      {:error, :key_fetch_limited} -> {:error, {:unauthorized, :key_fetch_limited}}
      {:error, reason} -> {:error, {:unauthorized, {:key_fetch_failed, reason}}}
      false -> {:error, {:unauthorized, :not_verified}}
    end
  end

  defp allow_key_fetch(actor) do
    case RateLimit.hit({:inbox_key_fetch, actor}, 1, @key_fetch_interval_ms) do
      :ok -> :ok
      {:error, :rate_limited} -> {:error, :key_fetch_limited}
    end
  end

  defp fetch_account(site, actor) do
    case RemoteAccounts.fetch(site, actor, pool: :inbox) do
      {:error, :busy} ->
        RateLimit.refund({:inbox_key_fetch, actor}, @key_fetch_interval_ms)
        {:error, :busy}

      result ->
        result
    end
  end

  defp signed_by?(signature, account),
    do: account.key_id == signature.key_id and Signature.verified?(signature, account.public_key)

  defp public_host do
    %URI{scheme: scheme, host: host, port: port} =
      URI.parse(Application.fetch_env!(:feather, :base_url))

    if port == URI.default_port(scheme), do: host, else: "#{host}:#{port}"
  end

  defp check_host(actor),
    do: RateLimit.hit({:inbox_host, RemoteAccount.host(actor)}, @host_limit, @window_ms)

  defp store(site, account, activity) do
    Repo.insert!(
      %ReceivedActivity{
        site_id: site.id,
        remote_account_id: account.id,
        activity_id: activity["id"],
        payload: Jason.encode!(activity),
        next_attempt_at: DateTime.utc_now()
      },
      on_conflict: :nothing,
      conflict_target: [:site_id, :remote_account_id, :activity_id]
    )

    pending =
      Repo.one(
        from r in ReceivedActivity,
          where: r.site_id == ^site.id and r.remote_account_id == ^account.id,
          where: r.activity_id == ^activity["id"] and is_nil(r.processed_at),
          select: r.id
      )

    if pending, do: process_soon(pending), else: :ok
  end

  defp process_soon(id) do
    case Application.get_env(:feather, :fediverse_inbox, :background) do
      :inline -> attempt(id)
      :background -> start_in_background(fn -> attempt(id) end)
      :scheduler -> :ok
    end
  end

  defp start_in_background(fun) do
    case Task.Supervisor.start_child(Feather.TaskSupervisor, fun) do
      {:ok, _pid} -> :ok
      {:error, reason} -> Logger.error("An inbox activity was not processed: #{inspect(reason)}")
    end
  end

  @doc """
  Processes the activities the inboxes took in and did not process yet
  (see the module doc), and gives up those that came more than a day ago.
  """
  @spec process_due() :: :ok
  def process_due do
    give_up_expired()
    process_next()
  end

  defp give_up_expired do
    cutoff = DateTime.add(DateTime.utc_now(), -@lifetime_seconds)

    expired =
      from r in ReceivedActivity, where: is_nil(r.processed_at) and r.inserted_at < ^cutoff

    case Repo.delete_all(expired) do
      {0, _} -> :ok
      {count, _} -> Logger.error("Gave up #{count} inbox activities not processed within a day")
    end
  end

  defp process_next do
    case claim(:due) do
      nil ->
        :ok

      received ->
        received |> run() |> finish(received)
        process_next()
    end
  end

  defp attempt(id) do
    case claim(id) do
      nil -> :ok
      received -> received |> run() |> finish(received)
    end

    :ok
  end

  defp claim(which) do
    now = DateTime.utc_now()

    {:ok, received} =
      Repo.transact(fn ->
        case which |> claimable(now) |> Repo.one() do
          nil ->
            {:ok, nil}

          id ->
            {1, [received]} =
              Repo.update_all(from(r in ReceivedActivity, where: r.id == ^id, select: r),
                set: [claimed_until: DateTime.add(now, @claim_seconds)]
              )

            {:ok, received}
        end
      end)

    received
  end

  defp claimable(which, now) do
    query =
      from r in ReceivedActivity,
        where: is_nil(r.processed_at),
        where: is_nil(r.claimed_until) or r.claimed_until <= ^now,
        limit: 1,
        select: r.id

    case which do
      :due -> from r in query, where: r.next_attempt_at <= ^now, order_by: r.next_attempt_at
      id -> where(query, [r], r.id == ^id)
    end
  end

  defp run(received) do
    with %Site{} = site <- Repo.get(Site, received.site_id),
         %RemoteAccount{} = account <- Repo.get(RemoteAccount, received.remote_account_id),
         true <- Fediverse.account?(site),
         activity = Jason.decode!(received.payload),
         {:handle, action} <- action(site, activity, account) do
      process(site, action, activity, account)
    end

    :ok
  catch
    :error, reason -> {:error, Exception.normalize(:error, reason, __STACKTRACE__).__struct__}
    kind, _reason -> {:error, kind}
  end

  defp finish(:ok, received) do
    Repo.update_all(from(r in ReceivedActivity, where: r.id == ^received.id),
      set: [
        processed_at: DateTime.utc_now(),
        payload: nil,
        next_attempt_at: nil,
        claimed_until: nil
      ]
    )
  end

  # The cause is only named: what failed may hold the activity's content.
  defp finish({:error, cause}, received) do
    attempts = received.attempts + 1

    Logger.warning(
      "Processing the inbox activity #{received.activity_id} failed " <>
        "(attempt #{attempts}): #{inspect(cause)}"
    )

    Repo.update_all(from(r in ReceivedActivity, where: r.id == ^received.id),
      set: [
        attempts: attempts,
        next_attempt_at:
          DateTime.add(DateTime.utc_now(), @first_retry_seconds * 2 ** (attempts - 1)),
        claimed_until: nil
      ]
    )
  end

  defp process(site, :follow, follow, account) do
    if follower(site, account.uri) || new_followers(site, account) < @new_followers_per_hour do
      Repo.insert!(
        %Follower{site_id: site.id, remote_account_id: account.id, follow_id: follow["id"]},
        on_conflict: {:replace, [:follow_id, :updated_at]},
        conflict_target: [:site_id, :remote_account_id]
      )

      Deliveries.deliver(site, [account], accept(site, follow))
    else
      Blocks.refuse_follow(site, account, follow["id"])
    end
  end

  defp process(site, :refuse_follow, follow, account),
    do: Blocks.refuse_follow(site, account, follow["id"])

  defp process(site, :unfollow, _undo, account) do
    Repo.delete_all(
      from f in Follower, where: f.site_id == ^site.id and f.remote_account_id == ^account.id
    )

    :ok
  end

  defp process(site, actions, activity, account) when is_list(actions),
    do: Enum.each(actions, &process(site, &1, activity, account))

  defp process(site, :accept_follow, _accept, account), do: Following.accept(site, account)
  defp process(site, :reject_follow, _reject, account), do: Following.reject(site, account)

  defp process(site, :file_mention, create, account),
    do: Mentions.file(site, account, create["object"])

  defp process(site, :file_timeline_post, create, account),
    do: Timeline.file(site, account, create["object"])

  defp process(site, :update_timeline_post, update, account),
    do: Timeline.update(site, account, update["object"])

  defp process(site, :delete_timeline_post, delete, account),
    do: Timeline.delete(site, account, id_of(delete["object"]))

  defp process(site, :update_mention, update, account),
    do: Mentions.update(site, account, update["object"])

  defp process(site, :delete_mention, delete, account),
    do: Mentions.delete(site, account, id_of(delete["object"]))

  defp process(site, :tombstone, delete, account),
    do: Tombstone.insert!(site, id_of(delete["object"]), account.uri)

  # Its follows and its posts in Timelines go with it (foreign keys).
  defp process(site, :delete_account, _delete, account) do
    :ok = Mentions.delete_by_author(account)

    {:ok, :purged} =
      Repo.transact(fn ->
        Repo.delete_all(
          from d in Delivery, where: d.site_id == ^site.id and d.inbox == ^account.inbox
        )

        Repo.delete_all(from a in RemoteAccount, where: a.id == ^account.id)
        {:ok, :purged}
      end)

    :ok
  end

  defp new_followers(site, account) do
    since = DateTime.add(DateTime.utc_now(), -1, :hour)

    Repo.aggregate(
      from(f in Follower,
        join: a in assoc(f, :remote_account),
        where: f.site_id == ^site.id and a.host == ^account.host and f.inserted_at > ^since
      ),
      :count
    )
  end

  defp accept(site, follow) do
    account_url = Fediverse.account_url(site)

    %{
      "@context" => @activity_streams,
      "id" => account_url <> "#accepts/follows/" <> PublicId.generate(),
      "type" => "Accept",
      "actor" => account_url,
      "object" => %{
        "id" => follow["id"],
        "type" => "Follow",
        "actor" => follow["actor"],
        "object" => account_url
      }
    }
  end
end
