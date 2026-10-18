defmodule Feather.Publishing.DeployTest do
  use Feather.DataCase

  alias Feather.{Media, Publishing}
  alias Feather.Publishing.Deploy

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup %{tmp_dir: tmp_dir} do
    scope = site_scope_fixture()
    post_fixture(scope, %{title: "Hello", slug: "/hello"})
    target = deployment_target_fixture(scope)
    :ok = Publishing.subscribe_notices(scope.site)
    synced = Path.join(tmp_dir, "synced")

    %{
      scope: scope,
      target: target,
      synced: synced,
      runner: &runner(synced, &1),
      opts: [runner: runner(synced), brotli: false]
    }
  end

  defp runner(synced, sync_result \\ {:ok, ""}) do
    test = self()

    fn
      ["obscure", "-"], opts ->
        {:ok, "obscured-#{String.trim_trailing(opts[:input], "\n")}"}

      ["sync", "--config", _config, source, remote], _opts ->
        File.rm_rf!(synced)
        File.cp_r!(source, synced)
        send(test, {:synced, source, remote})
        sync_result
    end
  end

  defp exports_left, do: Path.wildcard(Path.join([Media.storage_root(), "static_site", "*"]))

  test "exports and precompresses into a fresh directory, syncs and removes it", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    assert_received {:synced, source, "ftps:/site"}
    assert String.ends_with?(source, "/")
    refute File.exists?(source)
    assert exports_left() == []

    assert File.read!(Path.join(c.synced, "hello/index.html")) =~ "<h1>Hello</h1>"
    assert File.exists?(Path.join(c.synced, "index.html.gz"))

    host = c.scope.site.domain
    assert File.read!(Path.join(c.synced, "feed.xml")) =~ "https://#{host}/hello/"

    refute Publishing.deploying?(c.target)
    url = "https://" <> host

    assert_received {:site_notice,
                     %{kind: :success, title: title, message: message, url: ^url, external: true}}

    assert title == "#{c.scope.site.title} is live"
    assert message =~ ~r/^#{Regex.escape(host)} · deployed in (under a second|\d+ seconds?)$/
  end

  test "reports each step and forgets the progress at the end", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    id = c.target.public_id

    for step <- [:build, :compress, :upload] do
      assert_received {:deploy_progress, %{target_id: ^id, step: ^step, started_at: %DateTime{}}}
    end

    refute_received {:deploy_progress, %{step: :waiting}}
    assert Publishing.deploy_progress(c.target) == nil
  end

  test "a successful deploy records when its export started", c do
    before = DateTime.utc_now()
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    deployed_at = Repo.reload!(c.target).last_deployed_at
    assert DateTime.compare(deployed_at, before) != :lt
    assert DateTime.compare(deployed_at, DateTime.utc_now()) != :gt
  end

  test "a failed deploy records nothing", c do
    opts = Keyword.put(c.opts, :runner, c.runner.({:error, "rclone sync failed (exit 1): nope"}))

    assert {:error, _} = Deploy.run(c.target, opts)
    assert Repo.reload!(c.target).last_deployed_at == nil
  end

  test "a second deploy exports the site afresh", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    post = Feather.Content.get_post_by_slug(c.scope, "/hello")
    {:ok, post} = Feather.Content.update_post(c.scope, post, %{slug: "/moved"})
    {:ok, _post} = Feather.Content.publish(c.scope, post)

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    assert File.exists?(Path.join(c.synced, "moved/index.html"))
    refute File.exists?(Path.join(c.synced, "hello/index.html"))
    assert exports_left() == []
  end

  test "exports the published versions, not the unpublished changes", c do
    c.scope
    |> Feather.Content.get_post_by_slug("/hello")
    |> Ecto.Changeset.change(title: "Unpublished")
    |> Repo.update!()

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    html = File.read!(Path.join(c.synced, "hello/index.html"))
    assert html =~ "<h1>Hello</h1>"
    refute html =~ "Unpublished"
  end

  test "a failing rclone sync releases the lock and broadcasts the failure", c do
    opts = Keyword.put(c.opts, :runner, c.runner.({:error, "rclone sync failed (exit 1): nope"}))

    assert {:error, "rclone sync failed (exit 1): nope"} = Deploy.run(c.target, opts)
    refute Publishing.deploying?(c.target)
    assert exports_left() == []

    assert_received {:site_notice, %{kind: :error, title: title, message: message, retry: retry}}

    assert title == "Deploy to #{c.scope.site.domain} failed"
    assert message == "Uploading: rclone sync failed (exit 1): nope."
    assert retry == true
  end

  test "a failing export or precompression syncs nothing and removes the export", c do
    failing = Path.join(c.tmp_dir, "failing-brotli")
    File.write!(failing, "#!/bin/sh\nexit 1\n")
    File.chmod!(failing, 0o755)

    assert {:error, message} = Deploy.run(c.target, Keyword.put(c.opts, :brotli, failing))
    assert message =~ "brotli failed"
    refute_received {:synced, _, _}
    assert exports_left() == []
    refute Publishing.deploying?(c.target)
    assert_received {:site_notice, %{kind: :error, message: "Compressing: " <> message}}
    assert message =~ ~r/brotli failed.*\. The site online is unchanged\.$/s
  end

  test "gives up when the lock stays taken", c do
    assert Publishing.acquire_deploy_lock(c.target)
    opts = c.opts ++ [lock_retries: 2, lock_retry_interval: 1]

    assert {:error, "another deploy is still running"} = Deploy.run(c.target, opts)
    refute_received {:synced, _, _}
    assert_received {:deploy_progress, %{step: :waiting}}

    assert_received {:site_notice,
                     %{
                       kind: :error,
                       message:
                         "Waiting for the running deploy: another deploy is still running. " <>
                           "The site online is unchanged."
                     }}

    # The lock belongs to the other deploy and stays.
    assert Publishing.deploying?(c.target)
  end

  test "a waiting deploy leaves the progress of the running one alone", c do
    test = self()

    running =
      Task.async(fn ->
        assert Publishing.acquire_deploy_lock(c.target)
        :ok = Publishing.put_deploy_progress(c.target, :build, DateTime.utc_now())
        send(test, :running)
        receive do: (:done -> :ok)
      end)

    assert_receive :running
    assert_received {:deploy_progress, %{step: :build}}
    opts = c.opts ++ [lock_retries: 2, lock_retry_interval: 1]

    assert {:error, "another deploy is still running"} = Deploy.run(c.target, opts)
    refute_received {:deploy_progress, _progress}
    assert %{step: :build} = Publishing.deploy_progress(c.target)

    assert_received {:site_notice,
                     %{kind: :error, message: "Waiting for the running deploy: " <> _message}}

    send(running.pid, :done)
    Task.await(running)
  end

  test "waits for the lock and coalesces further requests", c do
    assert Publishing.acquire_deploy_lock(c.target)
    opts = c.opts ++ [lock_retries: 10_000, lock_retry_interval: 5]

    waiting = Task.async(fn -> Deploy.run(c.target, opts) end)

    wait_until(fn ->
      Registry.lookup(Feather.Publishing.Registry, {:waiting, c.target.id}) != []
    end)

    assert {:ok, :coalesced} = Deploy.run(c.target, opts)

    Publishing.release_deploy_lock(c.target)
    assert {:ok, :deployed} = Task.await(waiting, 10_000)
    assert_received {:synced, _, _}
    refute Publishing.deploying?(c.target)
  end

  defp wait_until(fun, attempts \\ 500) do
    cond do
      fun.() ->
        :ok

      attempts == 0 ->
        flunk("condition not reached")

      true ->
        receive do
        after
          5 -> wait_until(fun, attempts - 1)
        end
    end
  end

  test "remove_stale_exports/0 removes what interrupted deploys left" do
    leftover = Path.join([Media.storage_root(), "static_site", "export-leftover"])
    File.mkdir_p!(Path.join(leftover, "hello"))

    assert Deploy.remove_stale_exports() == :ok
    assert exports_left() == []
  end

  describe "Feather.Publishing entry points" do
    test "deploy_site/2 runs under the task supervisor and reports through a notice", c do
      assert :ok = Publishing.deploy_site(c.scope, Keyword.put(c.opts, :mode, :async))
      url = "https://" <> c.scope.site.domain
      assert_receive {:site_notice, %{kind: :success, url: ^url}}, 10_000
      wait_until(fn -> not Publishing.deploying?(c.target) end)
    end

    test "in tests deploys are only requested, with the target's config", c do
      assert :ok = Publishing.deploy_site(c.scope)
      assert_received {:deploy_requested, %{id: id, config: %{"host" => "ftp.example.com"}}}
      assert id == c.target.id
      refute_received {:synced, _, _}
    end

    test "deploy_site/2 deploys only the site's own target", c do
      deployment_target_fixture(site_scope_fixture())
      {:ok, _target} = Publishing.delete_target(c.scope, c.target)

      assert Publishing.deploy_site(c.scope) == {:error, :no_target}
      refute_received {:deploy_requested, _target}
    end

    test "notices go to the site's topic", c do
      assert Publishing.notices_topic(c.scope.site) == "site:#{c.scope.site.id}:notices"
      Publishing.broadcast_notice(c.scope.site, %{message: "Hello"})
      assert_received {:site_notice, %{message: "Hello"}}
    end
  end
end
