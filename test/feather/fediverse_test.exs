defmodule Feather.FediverseTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Encryption, Fediverse, Sites}

  alias Feather.Fediverse.{
    Deliveries,
    Delivery,
    FederatedObject,
    FollowedAccount,
    Follower,
    SigningKey,
    TimelinePost
  }

  alias Feather.Sites.Site

  setup do
    %{scope: site_scope_fixture(%{domain: "timon.blog"})}
  end

  defp decode_pem(pem) do
    [entry] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode(entry)
  end

  describe "update_name/2" do
    test "makes the site the account @name@domain with an RSA key pair of 2048 bits",
         %{scope: scope} do
      assert {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => " Timon "})

      assert site.fediverse_name == "timon"
      assert Fediverse.handle(site) == "@timon@timon.blog"
      assert Fediverse.account_url(site) == "https://timon.blog/activitypub/timon"
      refute Fediverse.online?(site)

      assert site.fediverse_public_key =~ "-----BEGIN PUBLIC KEY-----"
      {:RSAPublicKey, modulus, exponent} = decode_pem(site.fediverse_public_key)
      assert byte_size(:binary.encode_unsigned(modulus)) * 8 == 2048

      private_key = site |> Fediverse.private_key() |> decode_pem()
      signature = :public_key.sign("hello", :sha256, private_key)
      assert :public_key.verify("hello", :sha256, signature, {:RSAPublicKey, modulus, exponent})
    end

    test "keeps the private key encrypted and out of loaded sites", %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
      private_key = Fediverse.private_key(site)

      assert private_key =~ "-----BEGIN RSA PRIVATE KEY-----"

      [[stored]] =
        Repo.query!("SELECT fediverse_private_key FROM sites WHERE id = ?", [site.id]).rows

      refute stored =~ "PRIVATE KEY"
      assert Repo.get!(Site, site.id).fediverse_private_key == nil
      refute inspect(%{site | fediverse_private_key: private_key}) =~ "PRIVATE KEY"
    end

    test "returns the site without its private key", %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})

      assert site.fediverse_private_key == nil
      assert Fediverse.private_key(site) =~ "-----BEGIN RSA PRIVATE KEY-----"
    end

    test "keeps the key pair when the name changes before the first deploy", %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
      scope = Scope.put_site(scope, site)

      assert {:ok, renamed} = Fediverse.update_name(scope, %{"fediverse_name" => "pumbaa"})
      assert renamed.fediverse_name == "pumbaa"
      assert renamed.fediverse_public_key == site.fediverse_public_key
      assert Fediverse.private_key(renamed) == Fediverse.private_key(site)
    end

    test "an empty name keeps the site out of the fediverse", %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})

      assert {:ok, site} =
               Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "  "})

      assert site.fediverse_name == nil
      assert Fediverse.handle(site) == nil
      refute Fediverse.account?(site)
    end

    test "refuses names that are no handle or that the account's documents take",
         %{scope: scope} do
      for name <- ["ti mon", "tim.on", "tim-on", "@timon", String.duplicate("a", 31)] do
        assert {:error, changeset} = Fediverse.update_name(scope, %{"fediverse_name" => name})
        assert [_message] = errors_on(changeset).fediverse_name, name
      end

      for name <- ~w(outbox posts replies followers following) do
        assert {:error, changeset} = Fediverse.update_name(scope, %{"fediverse_name" => name})
        assert "is taken by the account's documents" in errors_on(changeset).fediverse_name
      end

      assert Repo.reload!(scope.site).fediverse_public_key == nil
    end

    test "is fixed after the first deploy with it", %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
      :ok = Fediverse.record_online(site, ~U[2026-10-23 12:00:00.000000Z])

      for name <- ["pumbaa", ""] do
        assert {:error, changeset} = Fediverse.update_name(scope, %{"fediverse_name" => name})

        assert "can no longer be changed after the first deploy with it" in errors_on(changeset).fediverse_name
      end

      assert Repo.reload!(site).fediverse_name == "timon"
    end

    test "counts as a change that is not deployed yet", %{scope: scope} do
      before = Repo.reload!(scope.site).updated_at
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})

      assert DateTime.compare(site.updated_at, before) == :gt
    end
  end

  describe "record_online/2" do
    setup %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
      %{site: site}
    end

    test "records when the account first went online", %{site: site} do
      :ok = Fediverse.record_online(site, ~U[2026-10-23 12:00:00.000000Z])
      :ok = Fediverse.record_online(site, ~U[2026-10-24 12:00:00.000000Z])

      site = Repo.reload!(site)
      assert site.fediverse_online_at == ~U[2026-10-23 12:00:00.000000Z]
      assert Fediverse.online?(site)
    end

    test "records nothing for a name the site no longer has", %{site: site, scope: scope} do
      {:ok, _renamed} =
        Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "pumbaa"})

      :ok = Fediverse.record_online(site, ~U[2026-10-23 12:00:00.000000Z])

      refute Fediverse.online?(Repo.reload!(site))
    end

    test "records nothing for a site without a name", %{scope: scope} do
      site = Repo.reload!(scope.site)
      {:ok, site} = Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => ""})

      :ok = Fediverse.record_online(site, ~U[2026-10-23 12:00:00.000000Z])

      assert Repo.reload!(site).fediverse_online_at == nil
    end
  end

  describe "rotate_key/1" do
    setup %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
      %{scope: Scope.put_site(scope, site), site: site}
    end

    defp pending_private_key(site) do
      [[stored]] =
        Repo.query!("SELECT fediverse_pending_private_key FROM sites WHERE id = ?", [site.id]).rows

      stored && elem(Encryption.decrypt(stored), 1)
    end

    defp signs_for?(%SigningKey{private_key: private_key}, public_key_pem) do
      signature = :public_key.sign("hello", :sha256, private_key)
      :public_key.verify("hello", :sha256, signature, decode_pem(public_key_pem))
    end

    test "gives the account a new key pair that waits for a deploy to publish it", c do
      assert {:ok, site} = Fediverse.rotate_key(c.scope)

      assert Fediverse.key_pending?(site)
      assert site.fediverse_public_key == c.site.fediverse_public_key
      assert site.fediverse_pending_public_key =~ "-----BEGIN PUBLIC KEY-----"
      refute site.fediverse_pending_public_key == site.fediverse_public_key
      assert Fediverse.public_key(site) == site.fediverse_pending_public_key

      assert signs_for?(SigningKey.for_site(site), c.site.fediverse_public_key)
      assert pending_private_key(site) =~ "-----BEGIN RSA PRIVATE KEY-----"
    end

    test "keeps the pending private key encrypted and out of the sites the CMS loads", c do
      assert {:ok, site} = Fediverse.rotate_key(c.scope)
      assert site.fediverse_pending_private_key == nil

      [[stored]] =
        Repo.query!("SELECT fediverse_pending_private_key FROM sites WHERE id = ?", [site.id]).rows

      refute stored =~ "PRIVATE KEY"

      for loaded <- [
            Repo.get!(Site, site.id),
            Sites.get_site!(c.scope, site.public_id),
            Sites.get_member_site_by_domain(c.scope, site.domain)
          ] do
        assert loaded.fediverse_pending_private_key == nil
      end

      refute inspect(%{site | fediverse_pending_private_key: pending_private_key(site)}) =~
               "PRIVATE KEY"
    end

    test "the account signs with the new key once a deploy published it", c do
      {:ok, rotated} = Fediverse.rotate_key(c.scope)
      new_private_key = pending_private_key(rotated)

      :ok = Fediverse.record_online(rotated, DateTime.utc_now())

      site = Repo.reload!(rotated)
      refute Fediverse.key_pending?(site)
      assert site.fediverse_public_key == rotated.fediverse_pending_public_key
      assert Fediverse.private_key(site) == new_private_key
      assert signs_for?(SigningKey.for_site(site), rotated.fediverse_pending_public_key)
      assert pending_private_key(site) == nil
    end

    test "a deploy that published a key replaced since keeps the newer one pending", c do
      {:ok, first} = Fediverse.rotate_key(c.scope)
      {:ok, second} = Fediverse.rotate_key(c.scope)

      :ok = Fediverse.record_online(first, DateTime.utc_now())

      site = Repo.reload!(c.site)
      assert site.fediverse_public_key == c.site.fediverse_public_key
      assert site.fediverse_pending_public_key == second.fediverse_pending_public_key
      assert signs_for?(SigningKey.for_site(site), c.site.fediverse_public_key)
    end

    test "a site without a fediverse name has no key to rotate", c do
      {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => ""})

      assert Fediverse.rotate_key(Scope.put_site(c.scope, site)) == {:error, :not_an_account}
      refute Fediverse.key_pending?(Repo.reload!(site))
    end

    test "counts as a change that is not deployed yet", c do
      before = Repo.reload!(c.site).updated_at
      {:ok, site} = Fediverse.rotate_key(c.scope)

      assert DateTime.compare(site.updated_at, before) == :gt
    end
  end

  describe "a new domain" do
    setup %{scope: scope} do
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
      :ok = Fediverse.record_online(site, DateTime.utc_now())
      scope = Scope.put_site(scope, Repo.reload!(site))
      followed = followed_account_fixture(scope.site)
      timeline_post_fixture(followed)
      follower_fixture(scope.site)

      Repo.insert!(%FederatedObject{
        site_id: scope.site.id,
        uri: Fediverse.account_url(scope.site),
        document_hash: "hash"
      })

      Repo.insert!(%Delivery{
        site_id: scope.site.id,
        inbox: "https://mastodon.example/inbox",
        host: "mastodon.example",
        payload: ~s({"type":"Create"}),
        next_attempt_at: DateTime.utc_now()
      })

      %{scope: scope}
    end

    defp left_of(site) do
      for schema <- [Follower, FollowedAccount, TimelinePost, FederatedObject, Delivery],
          into: %{},
          do: {schema, Repo.aggregate(from(r in schema, where: r.site_id == ^site.id), :count)}
    end

    test "starts the account over: offline, without what the account at the old address had",
         %{scope: scope} do
      other = fediverse_site_fixture()
      follower_fixture(other)

      assert {:ok, site} = Sites.update_site(scope, scope.site, %{domain: "pumbaa.blog"})

      assert Fediverse.handle(site) == "@timon@pumbaa.blog"
      refute Fediverse.online?(site)
      refute Fediverse.online?(Repo.reload!(site))
      assert left_of(site) |> Map.values() |> Enum.uniq() == [0]
      assert Fediverse.online?(other)
      assert Fediverse.count_followers(Scope.put_site(scope, other)) == 1
    end

    test "any other change keeps the account as it is", %{scope: scope} do
      before = left_of(scope.site)

      assert {:ok, site} = Sites.update_site(scope, scope.site, %{title: "Pumbaa's Blog"})

      assert Fediverse.online?(Repo.reload!(site))
      assert left_of(site) == before
    end

    test "deliveries and follows wait for the new account to go online", %{scope: scope} do
      {:ok, site} = Sites.update_site(scope, scope.site, %{domain: "pumbaa.blog"})
      scope = Scope.put_site(scope, site)
      serve_remote_accounts(["ana@example.social"])

      assert {:ok, [{_handle, {:ok, _followed}}]} =
               Fediverse.follow(scope, "@ana@example.social")

      :ok = Deliveries.deliver_due()
      refute_received {:fediverse_request, "POST", _url, _body}

      :ok = Fediverse.record_online(site, DateTime.utc_now())
      :ok = Deliveries.deliver_due()

      assert_received {:fediverse_request, "POST", "https://example.social/users/ana/inbox", body}

      assert %{"type" => "Follow", "actor" => "https://pumbaa.blog/activitypub/timon"} =
               Jason.decode!(body)
    end
  end

  test "inbox_url/1 is on the CMS's public host, below the inbox prefix", %{scope: scope} do
    assert Fediverse.inbox_url(scope.site) ==
             "http://localhost:4002/fediverse/inbox/#{scope.site.public_id}"
  end
end
