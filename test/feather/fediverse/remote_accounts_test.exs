defmodule Feather.Fediverse.RemoteAccountsTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Fediverse.{RemoteAccount, RemoteAccounts}

  @moduletag :capture_log

  @ana "https://mastodon.example/users/ana"

  setup do
    %{site: fediverse_site_fixture(%{domain: "timon.blog"})}
  end

  defp actor(attrs \\ %{}) do
    Map.merge(
      %{
        "@context" => ["https://www.w3.org/ns/activitystreams", "https://w3id.org/security/v1"],
        "id" => @ana,
        "type" => "Person",
        "preferredUsername" => "ana",
        "name" => "Ana",
        "inbox" => @ana <> "/inbox",
        "followers" => @ana <> "/followers",
        "endpoints" => %{"sharedInbox" => "https://mastodon.example/inbox"},
        "icon" => %{"type" => "Image", "url" => "https://files.mastodon.example/ana.png"},
        "publicKey" => %{
          "id" => @ana <> "#main-key",
          "owner" => @ana,
          "publicKeyPem" => "-----BEGIN PUBLIC KEY-----\nANA\n-----END PUBLIC KEY-----\n"
        }
      },
      attrs
    )
  end

  defp webfinger_url(acct) do
    [_user, domain] = String.split(acct, "@")

    "https://#{domain}/.well-known/webfinger?" <>
      URI.encode_query(%{"resource" => "acct:" <> acct})
  end

  defp webfinger(subject, actor) do
    %{
      "subject" => "acct:" <> subject,
      "links" => [
        %{
          "rel" => "http://webfinger.net/rel/profile-page",
          "href" => "https://mastodon.example/@ana"
        },
        %{"rel" => "self", "type" => "application/activity+json", "href" => actor}
      ]
    }
  end

  defp serve(documents) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      query = if conn.query_string == "", do: "", else: "?" <> conn.query_string
      url = "https://#{conn.host}#{conn.request_path}#{query}"
      send(test_pid, {:requested, url, get_req_header(conn, "signature")})

      case Map.fetch(documents, url) do
        {:ok, {:redirect, location}} ->
          conn |> put_resp_header("location", location) |> send_resp(302, "")

        {:ok, %{"links" => _links} = jrd} ->
          conn
          |> put_resp_content_type("application/jrd+json")
          |> send_resp(200, Jason.encode!(jrd))

        {:ok, document} ->
          conn
          |> put_resp_content_type("application/activity+json")
          |> send_resp(200, Jason.encode!(document))

        :error ->
          send_resp(conn, 404, "")
      end
    end)
  end

  test "fetches an actor, signed, and caches its key, name, handle, picture, inboxes and followers",
       %{site: site} do
    serve(%{
      @ana => actor(),
      webfinger_url("ana@mastodon.example") => webfinger("ana@mastodon.example", @ana)
    })

    assert {:ok, %RemoteAccount{} = account} = RemoteAccounts.fetch(site, @ana)

    assert account.uri == @ana
    assert account.key_id == @ana <> "#main-key"
    assert account.public_key =~ "ANA"
    assert account.name == "Ana"
    assert account.handle == "@ana@mastodon.example"
    assert account.picture_url == "https://files.mastodon.example/ana.png"
    assert account.inbox == @ana <> "/inbox"
    assert account.shared_inbox == "https://mastodon.example/inbox"
    assert account.followers_url == @ana <> "/followers"
    assert Repo.get_by!(RemoteAccount, uri: @ana).id == account.id

    assert_received {:requested, @ana, [signature]}
    assert signature =~ ~s(keyId="https://timon.blog/activitypub/timon#main-key")
  end

  test "verifies a handle on another domain with a second lookup", %{site: site} do
    serve(%{
      @ana => actor(),
      webfinger_url("ana@mastodon.example") => webfinger("ana@example.social", @ana),
      webfinger_url("ana@example.social") => webfinger("ana@example.social", @ana)
    })

    assert {:ok, %RemoteAccount{handle: "@ana@example.social"}} =
             RemoteAccounts.fetch(site, @ana)
  end

  test "keeps no handle unless WebFinger leads back to the actor", %{site: site} do
    serve(%{
      @ana => actor(),
      webfinger_url("ana@mastodon.example") => webfinger("ana@example.social", @ana),
      webfinger_url("ana@example.social") =>
        webfinger("ana@example.social", "https://example.social/users/ana")
    })

    assert {:ok, %RemoteAccount{handle: nil}} = RemoteAccounts.fetch(site, @ana)

    serve(%{@ana => actor()})

    assert {:ok, %RemoteAccount{handle: nil, name: "Ana"}} =
             RemoteAccounts.fetch(site, @ana)
  end

  test "refuses a document that is not the actor at its address", %{site: site} do
    serve(%{@ana => actor(%{"id" => "https://mastodon.example/users/bob"})})
    assert {:error, _reason} = RemoteAccounts.fetch(site, @ana)

    serve(%{
      @ana => {:redirect, "https://evil.example/ana"},
      "https://evil.example/ana" => actor()
    })

    assert {:error, _reason} = RemoteAccounts.fetch(site, @ana)

    serve(%{@ana => actor(%{"type" => "Note"})})
    assert {:error, _reason} = RemoteAccounts.fetch(site, @ana)

    other_key = %{
      "id" => "https://evil.example/key",
      "owner" => "https://evil.example/actor",
      "publicKeyPem" => "PEM"
    }

    serve(%{@ana => actor(%{"publicKey" => other_key})})
    assert {:error, _reason} = RemoteAccounts.fetch(site, @ana)

    assert Repo.all(RemoteAccount) == []
  end

  test "refuses an actor whose inbox or shared inbox is on another server", %{site: site} do
    serve(%{@ana => actor(%{"inbox" => "https://other.example/users/ana/inbox"})})
    assert {:error, :invalid_actor} = RemoteAccounts.fetch(site, @ana)

    serve(%{@ana => actor(%{"endpoints" => %{"sharedInbox" => "https://other.example/inbox"}})})
    assert {:error, :invalid_actor} = RemoteAccounts.fetch(site, @ana)

    assert Repo.all(RemoteAccount) == []
  end

  test "keeps only https addresses", %{site: site} do
    serve(%{@ana => actor(%{"icon" => %{"url" => "http://files.mastodon.example/ana.png"}})})
    assert {:ok, %RemoteAccount{picture_url: nil}} = RemoteAccounts.fetch(site, @ana)

    serve(%{@ana => actor(%{"inbox" => "http://mastodon.example/users/ana/inbox"})})
    assert {:error, _reason} = RemoteAccounts.fetch(site, @ana)
  end

  test "refuses actor addresses that resolve to private addresses, also after a redirect",
       %{site: site} do
    serve(%{
      "https://127.0.0.1.nip.io/users/ana" =>
        actor(%{"id" => "https://127.0.0.1.nip.io/users/ana"}),
      @ana => {:redirect, "https://127.0.0.1.nip.io/users/ana"}
    })

    assert {:error, _reason} =
             RemoteAccounts.fetch(site, "https://127.0.0.1.nip.io/users/ana")

    assert {:error, _reason} = RemoteAccounts.fetch(site, @ana)

    assert_received {:requested, @ana, _signature}
    refute_received {:requested, _url, _signature}
  end

  test "answers from the cache and fetches again after a day", %{site: site} do
    serve(%{@ana => actor()})
    assert {:ok, %RemoteAccount{name: "Ana"} = cached} = RemoteAccounts.get(site, @ana)
    assert_received {:requested, @ana, _signature}

    assert {:ok, ^cached} = RemoteAccounts.get(site, @ana)
    refute_received {:requested, @ana, _signature}

    Repo.update_all(RemoteAccount,
      set: [fetched_at: DateTime.add(DateTime.utc_now(), -25, :hour)]
    )

    serve(%{@ana => actor(%{"name" => "Ana B."})})

    assert {:ok, %RemoteAccount{name: "Ana B."} = refreshed} =
             RemoteAccounts.get(site, @ana)

    assert refreshed.id == cached.id

    Repo.update_all(RemoteAccount,
      set: [fetched_at: DateTime.add(DateTime.utc_now(), -25, :hour)]
    )

    serve(%{})
    assert {:ok, %RemoteAccount{name: "Ana B."}} = RemoteAccounts.get(site, @ana)
  end
end
