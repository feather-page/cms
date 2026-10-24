defmodule Feather.Publishing.DeployFediverseTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Accounts.Scope
  alias Feather.{Fediverse, Sites}
  alias Feather.Fediverse.{FederatedObject, SigningKey}
  alias Feather.Publishing.Deploy

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup %{tmp_dir: tmp_dir} do
    scope =
      site_scope_fixture(%{domain: "timon.blog", title: "Timon's Blog", bio: "Hakuna matata."})

    portrait = test_image_path(600, 600)
    {:ok, site} = Sites.put_portrait(scope, portrait, "me.png")
    File.rm(portrait)
    scope = Scope.put_site(scope, site)
    post_fixture(scope, %{title: "", slug: nil, content: [paragraph("No worries.")]})
    synced = Path.join(tmp_dir, "synced")

    %{
      scope: scope,
      target: deployment_target_fixture(scope),
      synced: synced,
      opts: [runner: runner(synced, {:ok, ""}), brotli: false]
    }
  end

  defp runner(synced, sync_result) do
    fn
      ["obscure", "-"], opts ->
        {:ok, "obscured-#{String.trim_trailing(opts[:input], "\n")}"}

      ["sync", "--config", _config, source, _remote], _opts ->
        File.rm_rf!(synced)
        File.cp_r!(source, synced)
        sync_result
    end
  end

  # As a Mastodon server does: the WebFinger answer links the account it then fetches.
  defp look_up(synced, "@" <> acct) do
    [_name, domain] = String.split(acct, "@")
    webfinger = read_json(synced, ".well-known/webfinger")
    assert webfinger["subject"] == "acct:" <> acct

    %{"href" => url} =
      Enum.find(
        webfinger["links"],
        &(&1["rel"] == "self" and &1["type"] == "application/activity+json")
      )

    {url, read_json(synced, String.replace_prefix(url, "https://#{domain}/", ""))}
  end

  defp read_json(synced, path), do: synced |> Path.join(path) |> File.read!() |> Jason.decode!()

  test "the handle resolves to the site's account, with its inbox on the CMS", c do
    {:ok, _site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    {url, account} = look_up(c.synced, "@timon@timon.blog")

    assert url == "https://timon.blog/activitypub/timon"
    assert account["id"] == url
    assert account["name"] == "Timon's Blog"
    assert account["summary"] == "<p>Hakuna matata.</p>"

    assert File.exists?(
             Path.join(
               c.synced,
               String.replace_prefix(account["icon"]["url"], "https://timon.blog/", "")
             )
           )

    assert account["inbox"] == Fediverse.inbox_url(c.scope.site)

    assert String.starts_with?(
             account["inbox"],
             Application.fetch_env!(:feather, :base_url) <> "/"
           )
  end

  test "uploads the documents with precompressed copies", c do
    {:ok, _site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    for path <- [".well-known/webfinger", "activitypub/timon", "activitypub/outbox"] do
      full = Path.join(c.synced, path)
      assert :zlib.gunzip(File.read!(full <> ".gz")) == File.read!(full), path
    end
  end

  test "records when the account first went online: the start of the deploy's export", c do
    {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})
    refute Fediverse.online?(site)

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    site = Repo.reload!(site)
    assert Fediverse.online?(site)
    assert site.fediverse_online_at == Repo.reload!(c.target).last_deployed_at
  end

  test "a deploy that went live stays successful when recording the account online fails", c do
    {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})

    Repo.query!("""
    CREATE TRIGGER sites_online_fails BEFORE UPDATE OF fediverse_online_at ON sites
    BEGIN SELECT RAISE(ABORT, 'database is locked'); END
    """)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
      end)

    assert log =~ "database is locked"
    assert Repo.reload!(c.target).last_deployed_at
    refute Fediverse.online?(Repo.reload!(site))
  end

  test "a failed deploy leaves the account offline", c do
    {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})
    opts = Keyword.put(c.opts, :runner, runner(c.synced, {:error, "rclone sync failed"}))

    assert {:error, _message} = Deploy.run(c.target, opts)

    refute Fediverse.online?(Repo.reload!(site))
  end

  test "a post goes out with the deploy, not with the publish", c do
    {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})
    scope = Scope.put_site(c.scope, site)
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    for name <- ["ana", "bob"] do
      uri = "https://mastodon.example/users/" <> name

      account =
        remote_account_fixture(%{
          uri: uri,
          key_id: uri <> "#main-key",
          inbox: uri <> "/inbox",
          shared_inbox: "https://mastodon.example/inbox"
        })

      follower_fixture(site, account)
    end

    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      send(test_pid, {:delivered, conn.host <> conn.request_path, Jason.decode!(body)})
      send_resp(conn, 202, "")
    end)

    post = post_fixture(scope, %{title: "", slug: nil, content: [paragraph("Hakuna matata.")]})
    refute_received {:delivered, _inbox, _activity}

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    note = read_json(c.synced, "activitypub/posts/#{post.public_id}")
    assert_received {:delivered, "mastodon.example/inbox", %{"type" => "Create"} = create}
    assert create["object"] == Map.delete(note, "@context")
    refute_received {:delivered, _inbox, _activity}

    {:ok, _site} = Sites.update_site(scope, Repo.reload!(site), %{theme: "simple_sidebar"})
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    refute_received {:delivered, _inbox, _activity}
  end

  test "a rotated key signs only after the deploy that published it", c do
    {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    old_public_key = Repo.reload!(site).fediverse_public_key

    signs_for? = fn public_key_pem ->
      %SigningKey{private_key: private_key} = SigningKey.for_site(site)
      [entry] = :public_key.pem_decode(public_key_pem)
      signature = :public_key.sign("hello", :sha256, private_key)
      :public_key.verify("hello", :sha256, signature, :public_key.pem_entry_decode(entry))
    end

    {:ok, rotated} = Fediverse.rotate_key(Scope.put_site(c.scope, Repo.reload!(site)))
    new_public_key = rotated.fediverse_pending_public_key
    assert signs_for?.(old_public_key)

    failing = Keyword.put(c.opts, :runner, runner(c.synced, {:error, "rclone sync failed"}))
    assert {:error, _message} = Deploy.run(c.target, failing)
    assert signs_for?.(old_public_key)
    assert Fediverse.key_pending?(Repo.reload!(site))

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    {_url, account} = look_up(c.synced, "@timon@timon.blog")
    assert account["publicKey"]["publicKeyPem"] == new_public_key
    assert signs_for?.(new_public_key)
    refute signs_for?.(old_public_key)
    refute Fediverse.key_pending?(Repo.reload!(site))

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    {_url, account} = look_up(c.synced, "@timon@timon.blog")
    assert account["publicKey"]["publicKeyPem"] == new_public_key
  end

  test "a new domain puts a new account online with the next deploy, without the followers",
       c do
    {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => "timon"})
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    site = Repo.reload!(site)
    follower_fixture(site)
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:delivered, conn.host <> conn.request_path})
      send_resp(conn, 202, "")
    end)

    {:ok, moved} =
      Sites.update_site(Scope.put_site(c.scope, site), site, %{domain: "pumbaa.blog"})

    refute Fediverse.online?(moved)

    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    {url, _account} = look_up(c.synced, "@timon@pumbaa.blog")
    assert url == "https://pumbaa.blog/activitypub/timon"
    assert Fediverse.online?(Repo.reload!(moved))
    refute_received {:delivered, _inbox}

    uris = Repo.all(from o in FederatedObject, where: o.site_id == ^site.id, select: o.uri)
    assert url in uris
    assert Enum.all?(uris, &String.starts_with?(&1, "https://pumbaa.blog/"))

    post_fixture(Scope.put_site(c.scope, moved), %{title: "", slug: nil})
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)
    refute_received {:delivered, _inbox}
  end

  test "a site without a fediverse name puts no account online", c do
    assert {:ok, :deployed} = Deploy.run(c.target, c.opts)

    refute File.exists?(Path.join(c.synced, ".well-known"))
    refute File.exists?(Path.join(c.synced, "activitypub"))
    assert Repo.reload!(c.scope.site).fediverse_online_at == nil
  end
end
