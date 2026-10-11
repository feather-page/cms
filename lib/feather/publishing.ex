defmodule Feather.Publishing do
  @moduledoc """
  Deployment targets, the deploy lock, deploying (static export,
  precompression and rclone sync, see `Feather.Publishing.Deploy`) and the
  notices a deploy broadcasts.
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Accounts.Scope
  alias Feather.Publishing.{Deploy, DeploymentTarget}
  alias Feather.Sites
  alias Feather.Sites.Site

  @registry Feather.Publishing.Registry

  @doc """
  Lists the deployment targets of the scope's site: staging first, then
  production, then backup, each type oldest first.

  Without the (encrypted) `config`, which stays at its default: listing
  works even when the credentials cannot be decrypted. Use `get_target!/2`
  for a target to edit or deploy.
  """
  @spec list_targets(Scope.t()) :: [DeploymentTarget.t()]
  def list_targets(%Scope{site: %Site{id: site_id}}) do
    from(t in DeploymentTarget,
      where: t.site_id == ^site_id,
      order_by: [asc: t.inserted_at],
      select: struct(t, ^metadata_fields())
    )
    |> Repo.all()
    |> Enum.sort_by(&Enum.find_index(DeploymentTarget.types(), fn type -> type == &1.type end))
  end

  @doc "Lists the deployment targets of the scope's site with the given type, oldest first."
  @spec list_targets(Scope.t(), String.t() | atom()) :: [DeploymentTarget.t()]
  def list_targets(%Scope{site: %Site{id: site_id}}, type) do
    type = to_string(type)

    Repo.all(
      from t in DeploymentTarget,
        where: t.site_id == ^site_id and t.type == ^type,
        order_by: [asc: t.inserted_at]
    )
  end

  @doc """
  Gets a deployment target of the scope's site by public id. Raises if not
  found.
  """
  @spec get_target!(Scope.t(), String.t()) :: DeploymentTarget.t()
  def get_target!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(
      from t in DeploymentTarget, where: t.site_id == ^site_id and t.public_id == ^public_id
    )
  end

  @doc "Gets a deployment target of the scope's site by public id, or nil."
  @spec get_target(Scope.t(), String.t()) :: DeploymentTarget.t() | nil
  def get_target(%Scope{site: %Site{id: site_id}}, public_id) when is_binary(public_id) do
    Repo.one(
      from t in DeploymentTarget, where: t.site_id == ^site_id and t.public_id == ^public_id
    )
  end

  @doc """
  The public id of the target the admin links as the site's preview (its
  internal target), or nil. Reads no credentials.
  """
  @spec preview_target_public_id(Scope.t()) :: String.t() | nil
  def preview_target_public_id(%Scope{} = scope) do
    scope
    |> list_targets()
    |> Enum.find_value(&(&1.provider == "internal" && &1.public_id))
  end

  @doc """
  Gets a deployment target by public id for the preview, with its site
  preloaded, if the scope's user may access that site. Returns nil
  otherwise. (The preview is addressed by target, not by site.) Without
  the `config`, which the preview does not need.
  """
  @spec get_preview_target(Scope.t(), String.t()) :: DeploymentTarget.t() | nil
  def get_preview_target(%Scope{} = scope, public_id) do
    target =
      Repo.one(
        from t in DeploymentTarget,
          where: t.public_id == ^public_id,
          select: struct(t, ^metadata_fields()),
          preload: :site
      )

    if target && Sites.can_access_site?(scope, target.site), do: target
  end

  # Every field but the encrypted config.
  defp metadata_fields, do: DeploymentTarget.__schema__(:fields) -- [:config]

  @doc "The staging target of the scope's site, or nil."
  @spec get_staging_target(Scope.t()) :: DeploymentTarget.t() | nil
  def get_staging_target(%Scope{} = scope) do
    scope |> list_targets(:staging) |> List.first()
  end

  @doc """
  Returns true if we serve the host name ourselves: a staging or
  production target with the `internal` provider has it as its public host
  name. Caddy asks this before obtaining a TLS certificate on demand.
  """
  @spec internally_hosted?(String.t()) :: boolean()
  def internally_hosted?(hostname) when is_binary(hostname) do
    hostname = hostname |> String.trim() |> String.downcase()

    Repo.exists?(
      from t in DeploymentTarget,
        where: t.public_hostname == ^hostname and t.provider == "internal" and t.type != "backup"
    )
  end

  @doc """
  The host name of a new site's staging target:
  `<site public_id>.stage.<staging_host>`, lowercased like every host name.
  """
  @spec staging_hostname(Site.t()) :: String.t()
  def staging_hostname(%Site{public_id: public_id}) do
    String.downcase("#{public_id}.stage.#{Application.fetch_env!(:feather, :staging_host)}")
  end

  @doc """
  Creates the internal staging target of a site (done when the site is
  created).
  """
  @spec create_staging_target(Site.t()) ::
          {:ok, DeploymentTarget.t()} | {:error, Ecto.Changeset.t()}
  def create_staging_target(%Site{} = site) do
    %DeploymentTarget{site_id: site.id}
    |> DeploymentTarget.create_changeset(%{
      type: "staging",
      provider: "internal",
      public_hostname: staging_hostname(site)
    })
    |> Repo.insert()
  end

  @doc """
  Creates a deployment target in the scope's site. Accepts `type`,
  `provider`, `public_hostname` and `config`.
  """
  @spec create_target(Scope.t(), map()) ::
          {:ok, DeploymentTarget.t()} | {:error, Ecto.Changeset.t()}
  def create_target(%Scope{site: %Site{id: site_id}}, attrs) do
    %DeploymentTarget{site_id: site_id}
    |> DeploymentTarget.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the host name and type of a deployment target.
  """
  @spec update_target(Scope.t(), DeploymentTarget.t(), map()) ::
          {:ok, DeploymentTarget.t()} | {:error, Ecto.Changeset.t()}
  def update_target(
        %Scope{site: %Site{id: site_id}},
        %DeploymentTarget{site_id: site_id} = t,
        attrs
      ) do
    t
    |> DeploymentTarget.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Replaces the provider config (credentials) of a deployment target.
  """
  @spec update_target_config(Scope.t(), DeploymentTarget.t(), map()) ::
          {:ok, DeploymentTarget.t()} | {:error, Ecto.Changeset.t()}
  def update_target_config(
        %Scope{site: %Site{id: site_id}},
        %DeploymentTarget{site_id: site_id} = target,
        config
      ) do
    target
    |> DeploymentTarget.config_changeset(config)
    |> Repo.update()
  end

  @doc "Deletes a deployment target."
  @spec delete_target(Scope.t(), DeploymentTarget.t()) :: {:ok, DeploymentTarget.t()}
  def delete_target(%Scope{site: %Site{id: site_id}}, %DeploymentTarget{site_id: site_id} = t) do
    Repo.delete(t)
  end

  @doc "Returns a changeset for the deployment target form (hostname, type)."
  @spec change_target(DeploymentTarget.t(), map()) :: Ecto.Changeset.t()
  def change_target(%DeploymentTarget{} = target, attrs \\ %{}) do
    DeploymentTarget.update_changeset(target, attrs)
  end

  ## Deploy lock

  @doc """
  Takes the deploy lock of a target. Atomic: returns true only for the one
  caller that flipped `deploying` from false to true.
  """
  @spec acquire_deploy_lock(DeploymentTarget.t()) :: boolean()
  def acquire_deploy_lock(%DeploymentTarget{id: id}) do
    {count, _} =
      Repo.update_all(
        from(t in DeploymentTarget, where: t.id == ^id and t.deploying == false),
        set: [deploying: true, updated_at: DateTime.utc_now()]
      )

    count == 1
  end

  @doc "Releases the deploy lock of a target."
  @spec release_deploy_lock(DeploymentTarget.t()) :: :ok
  def release_deploy_lock(%DeploymentTarget{id: id}) do
    Repo.update_all(
      from(t in DeploymentTarget, where: t.id == ^id),
      set: [deploying: false, updated_at: DateTime.utc_now()]
    )

    :ok
  end

  @doc """
  Releases all deploy locks. Meant to run on boot: no deploy survives a
  restart, so any lock still held is stale. Returns the number released.
  """
  @spec release_stale_locks() :: non_neg_integer()
  def release_stale_locks do
    {count, _} =
      Repo.update_all(
        from(t in DeploymentTarget, where: t.deploying == true),
        set: [deploying: false, updated_at: DateTime.utc_now()]
      )

    count
  end

  @doc "Records a successful deploy of a target whose export started at `deployed_at`."
  @spec record_deploy(DeploymentTarget.t(), DateTime.t()) :: :ok
  def record_deploy(%DeploymentTarget{id: id}, %DateTime{} = deployed_at) do
    Repo.update_all(from(t in DeploymentTarget, where: t.id == ^id),
      set: [last_deployed_at: deployed_at]
    )

    :ok
  end

  @doc "Returns true while a deploy of the target holds the lock."
  @spec deploying?(DeploymentTarget.t()) :: boolean()
  def deploying?(%DeploymentTarget{id: id}) do
    Repo.exists?(from t in DeploymentTarget, where: t.id == ^id and t.deploying == true)
  end

  ## Deploying

  @doc """
  Deploys a target of the scope's site in the background: static export,
  precompression, rclone sync (see `Feather.Publishing.Deploy`). Returns
  `:ok` at once; the outcome arrives as a notice (`subscribe_notices/1`).

  How the deploy runs is set by `config :feather, :deploy_mode` (or the
  `:mode` option):

    * `:async` (default) - under `Feather.TaskSupervisor`
    * `:inline` - in the calling process
    * `:manual` (tests) - not at all; the caller receives
      `{:deploy_requested, target}` instead

  Other options are passed to `Feather.Publishing.Deploy.run/2`.
  """
  @spec deploy(Scope.t(), DeploymentTarget.t(), keyword()) :: :ok
  def deploy(scope, target, opts \\ [])

  def deploy(%Scope{site: %Site{id: site_id}}, %DeploymentTarget{site_id: site_id} = target, opts) do
    start_deploy(target, opts)
  end

  @doc """
  Deploys all staging targets of a site (a scope with a site, or a site
  for trusted internal callers), like Rails did after changes to the
  site, its navigation or its social links. Returns `:ok` at once.
  """
  @spec publish_site(Scope.t() | Site.t(), keyword()) :: :ok
  def publish_site(scope_or_site, opts \\ [])

  def publish_site(%Scope{site: %Site{} = site}, opts), do: publish_site(site, opts)

  def publish_site(%Site{} = site, opts) do
    site
    |> Scope.for_site()
    |> list_targets(:staging)
    |> Enum.each(&start_deploy(&1, opts))
  end

  @doc """
  Deploys every production target of the scope's site, like `deploy/3`.
  Returns `:ok` at once.
  """
  @spec deploy_production(Scope.t(), keyword()) :: :ok
  def deploy_production(%Scope{} = scope, opts \\ []) do
    scope
    |> list_targets(:production)
    |> Enum.each(&start_deploy(&1, opts))
  end

  defp start_deploy(%DeploymentTarget{} = target, opts) do
    {mode, opts} =
      Keyword.pop_lazy(opts, :mode, fn -> Application.get_env(:feather, :deploy_mode, :async) end)

    case mode do
      :async ->
        {:ok, _pid} =
          Task.Supervisor.start_child(Feather.TaskSupervisor, fn -> Deploy.run(target, opts) end)

        :ok

      :inline ->
        Deploy.run(target, opts)
        :ok

      :manual ->
        send(self(), {:deploy_requested, target})
        :ok
    end
  end

  ## Undeployed changes

  @doc """
  The number of posts, pages and projects whose newest publish a production
  target does not show yet: published after the oldest production deploy,
  or every published one if a production target was never deployed. 0
  without a production target.

  Only production counts: staging shows the records as they are anyway, and
  a backup is not what visitors see. Unpublishing creates no version, so it
  does not count.
  """
  @spec undeployed_count(Scope.t()) :: non_neg_integer()
  def undeployed_count(%Scope{site: %Site{id: site_id}}) do
    deploys =
      Repo.all(
        from t in DeploymentTarget,
          where: t.site_id == ^site_id and t.type == "production",
          select: t.last_deployed_at
      )

    case deploys do
      [] ->
        0

      deploys ->
        since = if Enum.any?(deploys, &is_nil/1), do: nil, else: Enum.min(deploys, DateTime)
        count_published_since(site_id, since)
    end
  end

  defp count_published_since(site_id, since) do
    Feather.Content.versioned_schemas()
    |> Enum.map(fn {record, version, foreign_key} ->
      query =
        from v in version,
          join: r in ^record,
          on: r.id == field(v, ^foreign_key),
          where: r.site_id == ^site_id,
          select: count(field(v, ^foreign_key), :distinct)

      query = if since, do: where(query, [v], v.published_at > ^since), else: query
      Repo.one(query)
    end)
    |> Enum.sum()
  end

  @doc """
  Whether a published version is on the live site: every production
  target in `targets` deployed since it was published and, for a post,
  since its `publish_at` (the static export leaves out a post until then).
  A post whose `publish_at` is in the future is never live. True without a
  published version, and for a due one without a production target, where
  there is nothing to wait for.
  """
  @spec live?([DeploymentTarget.t()], map() | nil, DateTime.t()) :: boolean()
  def live?(targets, published_version, now \\ DateTime.utc_now())

  def live?(_targets, nil, _now), do: true

  def live?(targets, %{published_at: %DateTime{} = published_at} = version, now) do
    shown_from =
      case version do
        %{publish_at: %DateTime{} = publish_at} -> Enum.max([published_at, publish_at], DateTime)
        _version -> published_at
      end

    DateTime.compare(shown_from, now) != :gt and
      Enum.all?(targets, fn target ->
        target.last_deployed_at && DateTime.compare(shown_from, target.last_deployed_at) != :gt
      end)
  end

  ## Notices

  @doc """
  The PubSub topic of a site's notices. Messages are `{:site_notice,
  notice}` (see `broadcast_notice/2`) and `{:deploy_progress, progress}`
  (see `put_deploy_progress/3`).
  """
  @spec notices_topic(Site.t()) :: String.t()
  def notices_topic(%Site{id: id}), do: "site:#{id}:notices"

  @doc "Subscribes the caller to a site's notices."
  @spec subscribe_notices(Site.t()) :: :ok | {:error, term()}
  def subscribe_notices(%Site{} = site),
    do: Phoenix.PubSub.subscribe(Feather.PubSub, notices_topic(site))

  @doc """
  Broadcasts a notice to everyone watching the site: a map with `:message`
  and any of `:kind` (`:info`, `:success`, `:warning`, `:error`), `:title`,
  `:url`, `:link_label`, `:external` (the URL opens the site, shown as a
  button) and `:retry` (the public id of a target to deploy again).
  """
  @spec broadcast_notice(Site.t(), map()) :: :ok | {:error, term()}
  def broadcast_notice(%Site{} = site, %{message: _} = notice),
    do: Phoenix.PubSub.broadcast(Feather.PubSub, notices_topic(site), {:site_notice, notice})

  ## Deploy progress

  @deploy_steps [:waiting, :build, :compress, :upload]

  @doc """
  The steps a deploy reports, in order: `:waiting` (for a running deploy
  of the same target, only when there is one), `:build`, `:compress`,
  `:upload`.
  """
  @spec deploy_steps() :: [atom()]
  def deploy_steps, do: @deploy_steps

  @doc """
  Records the step a deploy is at, called by the deploying process, and
  broadcasts `{:deploy_progress, progress}` to the site's notices.
  `progress` is `%{target_id: public_id, step: step, started_at:
  started_at}`. The record lives in `Feather.Publishing.Registry` until
  `clear_deploy_progress/1` or the end of the process. Does nothing while
  another deploy of the target holds the record (a deploy waiting for the
  running one).
  """
  @spec put_deploy_progress(DeploymentTarget.t(), atom(), DateTime.t()) :: :ok
  def put_deploy_progress(%DeploymentTarget{} = target, step, %DateTime{} = started_at)
      when step in @deploy_steps do
    progress = %{target_id: target.public_id, step: step, started_at: started_at}
    key = {:progress, target.id}

    recorded =
      with {:error, {:already_registered, _owner}} <-
             Registry.register(@registry, key, progress) do
        Registry.update_value(@registry, key, fn _old -> progress end)
      end

    if recorded != :error do
      Phoenix.PubSub.broadcast(
        Feather.PubSub,
        notices_topic(%Site{id: target.site_id}),
        {:deploy_progress, progress}
      )
    end

    :ok
  end

  @doc """
  The label of a deploy step, e.g. "Exporting pages" while it runs
  (`:running`) or "Export pages" in a list of the steps (`:checklist`).
  """
  @spec deploy_step_label(atom(), :running | :checklist) :: String.t()
  def deploy_step_label(:waiting, :running), do: "Waiting for the running deploy"
  def deploy_step_label(:build, :running), do: "Exporting pages"
  def deploy_step_label(:compress, :running), do: "Compressing"
  def deploy_step_label(:upload, :running), do: "Uploading"
  def deploy_step_label(:waiting, :checklist), do: "Wait for the running deploy"
  def deploy_step_label(:build, :checklist), do: "Export pages"
  def deploy_step_label(:compress, :checklist), do: "Compress"
  def deploy_step_label(:upload, :checklist), do: "Upload"

  @doc "The progress of the target's running deploy, or nil."
  @spec deploy_progress(DeploymentTarget.t()) :: map() | nil
  def deploy_progress(%DeploymentTarget{id: id}) do
    case Registry.lookup(@registry, {:progress, id}) do
      [{_pid, progress}] -> progress
      [] -> nil
    end
  end

  @doc """
  The progress of the running deploys of `targets` (see
  `deploy_progress/1`), by target public id.
  """
  @spec deploy_progress_by_target([DeploymentTarget.t()]) :: %{String.t() => map()}
  def deploy_progress_by_target(targets) do
    for target <- targets,
        target.deploying,
        progress = deploy_progress(target),
        into: %{},
        do: {target.public_id, progress}
  end

  @doc "Removes the progress record of the calling process's deploy."
  @spec clear_deploy_progress(DeploymentTarget.t()) :: :ok
  def clear_deploy_progress(%DeploymentTarget{id: id}),
    do: Registry.unregister(@registry, {:progress, id})
end
