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

  @doc """
  Lists the deployment targets of the scope's site: staging first, then
  production, then backup.
  """
  @spec list_targets(Scope.t()) :: [DeploymentTarget.t()]
  def list_targets(%Scope{site: %Site{id: site_id}}) do
    from(t in DeploymentTarget, where: t.site_id == ^site_id, order_by: [asc: t.inserted_at])
    |> Repo.all()
    |> Enum.sort_by(&Enum.find_index(DeploymentTarget.types(), fn type -> type == &1.type end))
  end

  @doc "Lists the deployment targets of the scope's site with the given type."
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

  @doc """
  Gets a deployment target by public id for the preview, with its site
  preloaded, if the scope's user may access that site. Returns nil
  otherwise. (The preview is addressed by target, not by site.)
  """
  @spec get_preview_target(Scope.t(), String.t()) :: DeploymentTarget.t() | nil
  def get_preview_target(%Scope{} = scope, public_id) do
    target =
      Repo.one(from t in DeploymentTarget, where: t.public_id == ^public_id, preload: :site)

    if target && Sites.can_access_site?(scope, target.site), do: target
  end

  @doc "The staging target of the scope's site, or nil."
  @spec get_staging_target(Scope.t()) :: DeploymentTarget.t() | nil
  def get_staging_target(%Scope{} = scope) do
    scope |> list_targets(:staging) |> List.first()
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

  ## Notices

  @doc """
  The PubSub topic of a site's notices. Messages are
  `{:site_notice, %{message: String.t(), url: String.t() | nil}}`.
  """
  @spec notices_topic(Site.t()) :: String.t()
  def notices_topic(%Site{id: id}), do: "site:#{id}:notices"

  @doc "Subscribes the caller to a site's notices."
  @spec subscribe_notices(Site.t()) :: :ok | {:error, term()}
  def subscribe_notices(%Site{} = site),
    do: Phoenix.PubSub.subscribe(Feather.PubSub, notices_topic(site))

  @doc "Broadcasts a notice to everyone watching the site."
  @spec broadcast_notice(Site.t(), String.t(), String.t() | nil) :: :ok | {:error, term()}
  def broadcast_notice(%Site{} = site, message, url \\ nil) do
    Phoenix.PubSub.broadcast(
      Feather.PubSub,
      notices_topic(site),
      {:site_notice, %{message: message, url: url}}
    )
  end
end
