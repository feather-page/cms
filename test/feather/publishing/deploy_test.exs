defmodule Feather.Publishing.DeployTest do
  use Feather.DataCase

  alias Feather.Publishing
  alias Feather.Publishing.Deploy

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup do
    scope = site_scope_fixture()
    post_fixture(scope, %{title: "Hello", slug: "/hello"})
    target = deployment_target_fixture(scope)
    :ok = Publishing.subscribe_notices(scope.site)
    on_exit(fn -> File.rm_rf!(Deploy.build_path(target)) end)

    %{
      scope: scope,
      target: target,
      opts: [runner: runner(), brotli: false]
    }
  end

  defp runner(sync_result \\ {:ok, ""}) do
    test = self()

    fn
      ["obscure", "-"], opts ->
        {:ok, "obscured-#{String.trim_trailing(opts[:input], "\n")}"}

      ["sync", "--config", _config, source, remote], _opts ->
        send(test, {:synced, source, remote, File.ls!(source)})
        sync_result
    end
  end

  test "exports, precompresses, publishes the live directory and syncs it", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    live = Deploy.live_dir(c.target)
    assert File.read!(Path.join(live, "hello/index.html")) =~ "<h1>Hello</h1>"
    assert File.exists?(Path.join(live, "index.html.gz"))
    assert File.ls!(Deploy.build_path(c.target)) == ["public"]

    host = c.target.public_hostname
    assert_received {:synced, source, "hetzner-ftps:/site", files}
    assert source == live <> "/"
    assert "index.html" in files

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
    opts = Keyword.put(c.opts, :runner, runner({:error, "rclone sync failed (exit 1): nope"}))

    assert {:error, _} = Deploy.run(c.target, opts)
    assert Repo.reload!(c.target).last_deployed_at == nil
  end

  test "a second deploy replaces the live directory", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    post = Feather.Content.get_post_by_slug(c.scope, "/hello")
    {:ok, post} = Feather.Content.update_post(c.scope, post, %{slug: "/moved"})
    {:ok, _post} = Feather.Content.publish(c.scope, post)

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    live = Deploy.live_dir(c.target)
    assert File.exists?(Path.join(live, "moved/index.html"))
    refute File.exists?(Path.join(live, "hello/index.html"))
    assert File.ls!(Deploy.build_path(c.target)) == ["public"]
  end

  test "exports the published versions, not the unpublished changes", c do
    c.scope
    |> Feather.Content.get_post_by_slug("/hello")
    |> Ecto.Changeset.change(title: "Unpublished")
    |> Repo.update!()

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    html = File.read!(Path.join(Deploy.live_dir(c.target), "hello/index.html"))
    assert html =~ "<h1>Hello</h1>"
    refute html =~ "Unpublished"
  end

  test "a failing rclone sync releases the lock and broadcasts the failure", c do
    opts = Keyword.put(c.opts, :runner, runner({:error, "rclone sync failed (exit 1): nope"}))

    assert {:error, "rclone sync failed (exit 1): nope"} = Deploy.run(c.target, opts)
    refute Publishing.deploying?(c.target)

    assert_received {:site_notice, %{kind: :error, title: title, message: message, retry: retry}}

    assert title == "Deploy to #{c.target.public_hostname} failed"
    # The live directory was already swapped in: no claim the site is unchanged.
    assert message == "Uploading: rclone sync failed (exit 1): nope."
    assert retry == c.target.public_id
  end

  test "a failing export or precompression leaves the live directory alone", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    live_index = Path.join(Deploy.live_dir(c.target), "index.html")
    before = File.read!(live_index)

    failing = Path.join(c.tmp_dir, "failing-brotli")
    File.write!(failing, "#!/bin/sh\nexit 1\n")
    File.chmod!(failing, 0o755)

    assert {:error, message} = Deploy.run(c.target, Keyword.put(c.opts, :brotli, failing))
    assert message =~ "brotli failed"
    assert File.read!(live_index) == before
    assert File.ls!(Deploy.build_path(c.target)) == ["public"]
    refute Publishing.deploying?(c.target)
    assert_received {:site_notice, %{kind: :error, message: "Compressing: " <> message}}
    assert message =~ ~r/brotli failed.*\. The site online is unchanged\.$/s
  end

  test "gives up when the lock stays taken", c do
    assert Publishing.acquire_deploy_lock(c.target)
    opts = c.opts ++ [lock_retries: 2, lock_retry_interval: 1]

    assert {:error, "another deploy is still running"} = Deploy.run(c.target, opts)
    refute_received {:synced, _, _, _}
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
    assert_received {:synced, _, _, _}
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

  describe "Feather.Publishing entry points" do
    test "deploy/3 runs under the task supervisor and reports through a notice", c do
      assert :ok = Publishing.deploy(c.scope, c.target, Keyword.put(c.opts, :mode, :async))
      host = c.target.public_hostname
      url = "https://" <> host
      assert_receive {:site_notice, %{kind: :success, url: ^url}}, 10_000
      wait_until(fn -> not Publishing.deploying?(c.target) end)
    end

    test "in tests deploys are only requested", c do
      assert :ok = Publishing.deploy(c.scope, c.target)
      assert_received {:deploy_requested, %{id: id}}
      assert id == c.target.id
      refute_received {:synced, _, _, _}
    end

    test "deploy/3 refuses targets of other sites", c do
      other = deployment_target_fixture(site_scope_fixture())
      assert_raise FunctionClauseError, fn -> Publishing.deploy(c.scope, other) end
    end

    test "deploy_site/1 deploys every target of the site", c do
      %{id: first} = c.target
      %{id: second} = deployment_target_fixture(c.scope)
      %{id: other} = deployment_target_fixture(site_scope_fixture())

      assert :ok = Publishing.deploy_site(c.scope)
      assert_received {:deploy_requested, %{id: ^first}}
      assert_received {:deploy_requested, %{id: ^second}}
      refute_received {:deploy_requested, %{id: ^other}}
    end

    test "deploy_site/1 deploys targets with their config", c do
      assert :ok = Publishing.deploy_site(c.scope)
      assert_received {:deploy_requested, %{config: %{"host" => "ftp.example.com"}}}
    end

    test "notices go to the site's topic", c do
      assert Publishing.notices_topic(c.scope.site) == "site:#{c.scope.site.id}:notices"
      Publishing.broadcast_notice(c.scope.site, %{message: "Hello"})
      assert_received {:site_notice, %{message: "Hello"}}
    end
  end
end
