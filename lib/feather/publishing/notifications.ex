defmodule Feather.Publishing.Notifications do
  @moduledoc """
  Tells search engines and archive.org what a deploy changed (ADR 0027):
  the home page and every post, page and project that changed on the site
  since the previous deploy (`Feather.Content.last_changed_at/1`, as the
  sitemap dates them), addressed by the site's canonical URL.

  All of them go to IndexNow (`Feather.IndexNow`) for every site, and one
  after another to archive.org (`Feather.ArchiveOrg`) for a site with
  archive.org keys. Failures are only logged: the deploy has succeeded.
  """

  alias Feather.Accounts.Scope
  alias Feather.{ArchiveOrg, Content, IndexNow, Sites}
  alias Feather.Content.Page
  alias Feather.Sites.Site
  alias Feather.StaticSite.Routes

  require Logger

  @archive_org_interval 5_000

  @doc """
  Runs `run/4` under `Feather.TaskSupervisor` (`mode` `:background`), right
  away (`:inline`) or not at all (`false`, as in tests that do not stub
  the services). The mode defaults to `config :feather,
  :deploy_notifications`.
  """
  @spec start(Site.t(), DateTime.t() | nil, DateTime.t(), keyword()) :: :ok
  def start(%Site{} = site, since, %DateTime{} = now, opts \\ []) do
    {mode, opts} =
      Keyword.pop_lazy(opts, :mode, fn ->
        Application.get_env(:feather, :deploy_notifications, :background)
      end)

    case mode do
      :background ->
        Feather.TaskSupervisor
        |> Task.Supervisor.start_child(fn -> run(site, since, now, opts) end)
        |> log_start_failure(site)

      :inline ->
        run(site, since, now, opts)

      false ->
        :ok
    end
  end

  defp log_start_failure({:ok, _pid}, _site), do: :ok

  defp log_start_failure({:error, reason}, site),
    do: Logger.error("Not notifying about the deploy of #{site.domain}: #{inspect(reason)}")

  @doc """
  Sends the URLs that changed after `since` up to `now` (`changed_urls/3`)
  to IndexNow and, with the site's archive.org keys, to archive.org.

  ## Options

    * `:archive_org_interval` - the pause between two archive.org requests
      in ms (default 5000), which keeps the captures within archive.org's
      limits
  """
  @spec run(Site.t(), DateTime.t() | nil, DateTime.t(), keyword()) :: :ok
  def run(%Site{} = site, since, %DateTime{} = now, opts \\ []) do
    case changed_urls(site, since, now) do
      [] ->
        :ok

      urls ->
        notify_indexnow(site, urls)
        interval = Keyword.get(opts, :archive_org_interval, @archive_org_interval)
        notify_archive_org(site, urls, interval)
    end
  rescue
    exception ->
      Logger.error(
        "Notifying about the deploy of #{site.domain} failed: #{Exception.message(exception)}"
      )
  end

  @doc """
  The canonical URLs of what changed on the site after `since` up to
  `now`. A post counts when it is due and its published version changed
  in that time, a page or project when its published version changed.

  When anything changed, the home page comes first, since it lists the
  posts and shows the homepage; it also stands for changes to the
  homepage and to the site's settings. The URLs of the changed records
  follow. When nothing changed, the list is empty.

  With `since` nil (the first deploy) everything published up to `now`
  counts as changed.
  """
  @spec changed_urls(Site.t(), DateTime.t() | nil, DateTime.t()) :: [String.t()]
  def changed_urls(%Site{} = site, since, %DateTime{} = now) do
    routes = site |> Routes.public() |> Routes.canonical()
    changed = site |> published_records(now) |> Enum.filter(&changed_between?(&1, since, now))

    if changed == [] and not changed_between?(site, since, now) do
      []
    else
      records = Enum.reject(changed, &homepage?/1)
      [Routes.home_url(routes) | Enum.map(records, &Routes.record_url(routes, &1))]
    end
  end

  defp homepage?(%Page{} = page), do: Page.homepage?(page)
  defp homepage?(_record), do: false

  defp published_records(site, now) do
    scope = Scope.for_site(site)

    posts = scope |> Content.list_posts() |> Content.as_published()
    pages = scope |> Content.list_pages() |> Content.as_published()
    projects = scope |> Content.list_projects() |> Content.as_published()

    Enum.filter(posts, &Content.due?(&1, now)) ++ pages ++ projects
  end

  defp changed_between?(%Site{updated_at: updated_at}, since, now),
    do: between?(updated_at, since, now)

  defp changed_between?(record, since, now),
    do: between?(Content.last_changed_at(record), since, now)

  defp between?(at, since, now),
    do: (since == nil or DateTime.after?(at, since)) and not DateTime.after?(at, now)

  defp notify_indexnow(%Site{indexnow_key: nil}, _urls), do: :ok

  defp notify_indexnow(site, urls) do
    case IndexNow.submit(site.domain, site.indexnow_key, urls) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("IndexNow refused #{site.domain}: #{inspect(reason)}")
    end
  end

  defp notify_archive_org(site, urls, interval) do
    case archive_org_keys(site) do
      nil -> :ok
      keys -> save_one_after_another(urls, keys, interval)
    end
  end

  defp archive_org_keys(site) do
    Sites.archive_org_keys(Scope.for_site(site))
  rescue
    ArgumentError ->
      Logger.error("Not asking archive.org to save #{site.domain}: its keys could not be loaded")
      nil
  end

  defp save_one_after_another(urls, keys, interval) do
    urls
    |> Enum.with_index()
    |> Enum.each(fn {url, index} ->
      if index > 0, do: Process.sleep(interval)

      case ArchiveOrg.save(url, keys) do
        :ok -> :ok
        {:error, reason} -> Logger.warning("archive.org did not save #{url}: #{inspect(reason)}")
      end
    end)
  end
end
