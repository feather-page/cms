defmodule Feather.Publishing.DeployTest do
  use Feather.DataCase

  alias Feather.Publishing
  alias Feather.Publishing.Deploy

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup %{tmp_dir: tmp} do
    scope = site_scope_fixture()
    post_fixture(scope, %{title: "Hello", slug: "/hello"})
    target = Publishing.get_staging_target(scope)
    :ok = Publishing.subscribe_notices(scope.site)
    on_exit(fn -> File.rm_rf!(Deploy.build_path(target)) end)

    %{
      scope: scope,
      target: target,
      opts: [runner: runner(), brotli: false, staging_sites_path: tmp]
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
    assert_received {:synced, source, remote, files}
    assert source == live <> "/"
    [host_without_port | _] = String.split(host, ":")
    assert remote == "internal:" <> Path.join(c.tmp_dir, host_without_port)
    assert "index.html" in files

    refute Publishing.deploying?(c.target)
    assert_received {:site_notice, %{message: "Site built.", url: "https://" <> ^host}}
  end

  test "a second deploy replaces the live directory", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    {:ok, _} =
      Feather.Content.update_post(c.scope, Feather.Content.get_post_by_slug(c.scope, "/hello"), %{
        slug: "/moved"
      })

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    live = Deploy.live_dir(c.target)
    assert File.exists?(Path.join(live, "moved/index.html"))
    refute File.exists?(Path.join(live, "hello/index.html"))
    assert File.ls!(Deploy.build_path(c.target)) == ["public"]
  end

  test "a failing rclone sync releases the lock and broadcasts the failure", c do
    opts = Keyword.put(c.opts, :runner, runner({:error, "rclone sync failed (exit 1): nope"}))

    assert {:error, "rclone sync failed (exit 1): nope"} = Deploy.run(c.target, opts)
    refute Publishing.deploying?(c.target)
    assert_received {:site_notice, %{message: "Deploying to " <> message, url: nil}}
    assert message =~ "nope"
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
    assert_received {:site_notice, %{message: "Deploying to " <> _, url: nil}}
  end

  test "gives up when the lock stays taken", c do
    assert Publishing.acquire_deploy_lock(c.target)
    opts = c.opts ++ [lock_retries: 2, lock_retry_interval: 1]

    assert {:error, "another deploy is still running"} = Deploy.run(c.target, opts)
    refute_received {:synced, _, _, _}
    # The lock belongs to the other deploy and stays.
    assert Publishing.deploying?(c.target)
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
      assert_receive {:site_notice, %{message: "Site built.", url: "https://" <> ^host}}, 10_000
      wait_until(fn -> not Publishing.deploying?(c.target) end)
    end

    test "in tests deploys are only requested", c do
      assert :ok = Publishing.deploy(c.scope, c.target)
      assert_received {:deploy_requested, %{id: id}}
      assert id == c.target.id
      refute_received {:synced, _, _, _}
    end

    test "deploy/3 refuses targets of other sites", c do
      other = Publishing.get_staging_target(site_scope_fixture())
      assert_raise FunctionClauseError, fn -> Publishing.deploy(c.scope, other) end
    end

    test "publish_site/1 deploys the staging targets only", c do
      deployment_target_fixture(c.scope, type: "production")

      assert :ok = Publishing.publish_site(c.scope)
      assert_received {:deploy_requested, %{type: "staging"}}
      refute_received {:deploy_requested, %{type: "production"}}

      assert :ok = Publishing.publish_site(c.scope.site)
      assert_received {:deploy_requested, %{type: "staging"}}
    end

    test "notices go to the site's topic", c do
      assert Publishing.notices_topic(c.scope.site) == "site:#{c.scope.site.id}:notices"
      Publishing.broadcast_notice(c.scope.site, "Hello")
      assert_received {:site_notice, %{message: "Hello", url: nil}}
    end
  end
end
