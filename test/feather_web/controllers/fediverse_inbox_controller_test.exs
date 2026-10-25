defmodule FeatherWeb.FediverseInboxControllerTest do
  use FeatherWeb.ConnCase

  import Ecto.Query
  import ExUnit.CaptureLog

  alias Feather.{Fediverse, Repo}

  alias Feather.Fediverse.{
    Deliveries,
    Delivery,
    FollowedAccount,
    Follower,
    Mention,
    ReceivedActivity,
    RemoteAccount,
    RemoteAccounts,
    TimelinePost
  }

  @moduletag :capture_log

  @as "https://www.w3.org/ns/activitystreams"
  @public "https://www.w3.org/ns/activitystreams#Public"
  @account "https://timon.blog/activitypub/timon"

  setup_all do
    {key, public_key} = remote_key_pair()
    {other_key, _public_key} = remote_key_pair()
    %{key: key, public_key: public_key, other_key: other_key}
  end

  # A fresh actor per test: the inbox throttles fetching an actor's key across tests.
  setup %{public_key: public_key} do
    ana = "https://mastodon.example/users/ana#{System.unique_integer([:positive])}"
    serve(ana, public_key)
    scope = fediverse_scope_fixture(%{domain: "timon.blog"})
    %{site: scope.site, scope: scope, ana: ana}
  end

  defp actor(ana, public_key) do
    %{
      "@context" => [@as, "https://w3id.org/security/v1"],
      "id" => ana,
      "type" => "Person",
      "preferredUsername" => "ana",
      "inbox" => ana <> "/inbox",
      "followers" => ana <> "/followers",
      "publicKey" => %{"id" => ana <> "#main-key", "owner" => ana, "publicKeyPem" => public_key}
    }
  end

  # Serves the actors and takes deliveries; tells the test about every request.
  defp serve(actors, public_key) do
    test_pid = self()
    actors = List.wrap(actors)

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      url = "https://#{conn.host}#{conn.request_path}"
      send(test_pid, {:remote, conn.method, url, body})

      cond do
        conn.method == "GET" and url in actors ->
          conn
          |> put_resp_content_type("application/activity+json")
          |> send_resp(200, Jason.encode!(actor(url, public_key)))

        conn.method == "POST" ->
          send_resp(conn, 202, "")

        true ->
          send_resp(conn, 404, "")
      end
    end)
  end

  defp inbox(site), do: "/fediverse/inbox/#{site.public_id}"

  defp send_activity(c, activity, opts \\ []) do
    body = Keyword.get_lazy(opts, :body, fn -> Jason.encode!(activity) end)
    post_signed(c, activity_headers(c, body, opts), body)
  end

  defp activity_headers(c, body, opts) do
    key = Keyword.get(opts, :key, c.key)
    key_id = Keyword.get(opts, :key_id, c.ana <> "#main-key")
    signed_headers(key, key_id, inbox(c.site), body, Keyword.take(opts, [:host, :date, :digest]))
  end

  defp post_signed(c, headers, body) do
    headers
    |> Enum.reduce(build_conn(), &put_header/2)
    |> put_req_header("content-type", "application/activity+json")
    |> post(inbox(c.site), body)
  end

  # Plug keeps the host apart from the headers, but servers pass the header on as sent.
  defp put_header({"host", host}, conn),
    do: %{conn | req_headers: [{"host", host} | conn.req_headers]}

  defp put_header({name, value}, conn), do: put_req_header(conn, name, value)

  defp follow(c, id \\ "https://mastodon.example/follows/1") do
    %{"@context" => @as, "id" => id, "type" => "Follow", "actor" => c.ana, "object" => @account}
  end

  defp activity(c, type, object, n \\ 0) do
    %{
      "@context" => @as,
      "id" => "https://mastodon.example/activities/#{n}",
      "type" => type,
      "actor" => c.ana,
      "object" => object
    }
  end

  defp followers(site),
    do: Repo.all(from f in Follower, where: f.site_id == ^site.id, preload: :remote_account)

  defp known_ana(c), do: known(c.ana, c.public_key)

  defp known(uri, public_key) do
    remote_account_fixture(%{
      uri: uri,
      key_id: uri <> "#main-key",
      public_key: public_key,
      inbox: uri <> "/inbox"
    })
  end

  defp note(c, n, attrs) do
    Map.merge(
      %{
        "id" => c.ana <> "/statuses/#{n}",
        "type" => "Note",
        "attributedTo" => c.ana,
        "url" => "https://mastodon.example/@ana/#{n}",
        "published" => "2026-10-23T12:00:00Z",
        "content" => "<p>Note #{n}</p>",
        "to" => [@public],
        "cc" => [c.ana <> "/followers"]
      },
      attrs
    )
  end

  defp mention_of(account \\ @account), do: [%{"type" => "Mention", "href" => account}]

  defp private_note(c, n, attrs \\ %{}),
    do: note(c, n, Map.merge(%{"to" => [@account], "cc" => [], "tag" => mention_of()}, attrs))

  defp create(c, note, n),
    do: Map.merge(activity(c, "Create", note, n), Map.take(note, ["to", "cc"]))

  defp mentions(site),
    do:
      Repo.all(
        from m in Mention,
          where: m.site_id == ^site.id,
          order_by: m.uri,
          preload: :remote_account
      )

  defp delivered(c) do
    inbox = c.ana <> "/inbox"

    receive do
      {:remote, "POST", ^inbox, body} -> Jason.decode!(body)
    after
      0 -> nil
    end
  end

  describe "a request beside the inbox" do
    test "reaches no other route, plain or encoded", %{site: site} do
      paths = [
        "/fediverse/inbox",
        "/fediverse/inbox/../../users/log-in",
        "/fediverse/inbox/%2e%2e/%2E%2E/users/log-in",
        "/fediverse/inbox/#{site.public_id}/../../../users/settings",
        "/fediverse/inbox/..%2F..%2Fusers%2Flog-in",
        "/fediverse/inbox/x%2F..%2F..%2F..%2Fsites%2F#{site.public_id}%2Fsettings",
        "/fediverse/inbox/#{site.public_id}%2F..%2F..%2F..%2Fup"
      ]

      for path <- paths, method <- [:get, :post] do
        conn = dispatch(build_conn(), @endpoint, method, path, nil)

        assert conn.status == 404, "#{method} #{path}"
        assert get_resp_header(conn, "content-security-policy") == [], "#{method} #{path}"
        assert conn.resp_cookies == %{}, "#{method} #{path}"
      end
    end

    test "parses no body below the inbox's prefix written encoded", %{site: site} do
      multipart = ~s(--x\r\nContent-Disposition: form-data; name="a"\r\n\r\nb\r\n--x--\r\n)

      for path <- [
            "/fediverse/%69nbox/x",
            "/fediverse/%69nbox",
            "/%66ediverse/inbox/#{site.public_id}"
          ],
          {content_type, body} <- [
            {"application/json", ~s({"a": "b"})},
            {"multipart/form-data; boundary=x", multipart}
          ] do
        conn =
          build_conn()
          |> put_req_header("content-type", content_type)
          |> post(path, body)

        assert conn.status == 404, path
        assert conn.resp_body == "", path
        assert %Plug.Conn.Unfetched{} = conn.body_params
        assert conn.resp_cookies == %{}, path
      end
    end

    test "takes a malformed escape in the first path segments for no inbox" do
      assert build_conn() |> get("/fediverse/%zz/x") |> response(404)
    end

    test "only takes a POST", %{site: site} do
      assert build_conn() |> get(inbox(site)) |> response(404)
    end
  end

  describe "inbox security" do
    test "answers 404 for a site that is not an account", c do
      site = site_fixture()
      assert response(send_activity(%{c | site: site}, follow(c)), 404)

      unknown = %{site | public_id: "nosuchsite00"}
      assert response(send_activity(%{c | site: unknown}, follow(c)), 404)
    end

    test "rejects a missing or wrong signature", c do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/activity+json")
        |> post(inbox(c.site), Jason.encode!(follow(c)))

      assert response(conn, 401)
      assert response(send_activity(c, follow(c), key: c.other_key), 401)
      assert followers(c.site) == []
    end

    test "rejects a stale date, a digest that does not match and another host", c do
      stale = DateTime.add(DateTime.utc_now(), -13, :hour)
      assert response(send_activity(c, follow(c), date: stale), 401)

      other_digest = "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, "{}"))
      assert response(send_activity(c, follow(c), digest: other_digest), 401)

      assert response(send_activity(c, follow(c), host: "timon.blog"), 401)
      assert followers(c.site) == []
    end

    test "accepts and drops what a key on another origin signed without fetching anything", c do
      known_ana(c)
      bob = "https://other.example/users/bob"

      reply =
        note(c, 1, %{
          "inReplyTo" => bob <> "/statuses/1",
          "tag" => mention_of(),
          "cc" => [@account]
        })

      for activity <- [create(c, reply, 1), follow(c)] do
        assert response(send_activity(c, activity, key_id: bob <> "#main-key"), 202)
      end

      stale = DateTime.add(DateTime.utc_now(), -13, :hour)
      assert response(send_activity(c, follow(c), key_id: bob <> "#main-key", date: stale), 401)

      assert mentions(c.site) == []
      assert followers(c.site) == []
      assert Repo.all(ReceivedActivity) == []
      refute_received {:remote, _method, _url, _body}
    end

    test "rejects a keyId without an https origin", c do
      for key_id <- ["/users/ana#main-key", "main-key", "http://mastodon.example/users/ana"] do
        assert response(send_activity(c, follow(c), key_id: key_id), 401)
      end

      assert followers(c.site) == []
    end

    test "rejects a Delete or Update of someone else's object", c do
      bob = remote_account_fixture(%{uri: "https://mastodon.example/users/bob"})

      bobs_note = %{
        "id" => "https://mastodon.example/users/bob/statuses/1",
        "type" => "Note",
        "attributedTo" => bob.uri
      }

      activities = [
        activity(c, "Delete", "https://other.example/users/ana/statuses/1", 1),
        activity(c, "Delete", bob.uri, 2),
        activity(c, "Update", bobs_note, 3)
      ]

      for activity <- activities do
        assert response(send_activity(c, activity), 403)
      end

      assert Repo.get(RemoteAccount, bob.id)
      refute_received {:remote, _method, _url, _body}
    end

    test "answers 202 to an Update or Delete of something unknown without fetching anything",
         c do
      status = "https://mastodon.example/users/ana/statuses/1"

      assert response(send_activity(c, activity(c, "Update", status, 1)), 202)
      assert response(send_activity(c, activity(c, "Delete", status, 2)), 202)
      refute_received {:remote, _method, _url, _body}
    end

    test "refuses a body above 1 MB and anything but ActivityStreams JSON", c do
      body = Jason.encode!(Map.put(follow(c), "padding", String.duplicate("a", 1_000_000)))
      assert response(send_activity(c, follow(c), body: body), 413)

      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post(inbox(c.site), Jason.encode!(follow(c)))

      assert response(conn, 415)
      assert response(send_activity(c, follow(c), body: "[1, 2]"), 400)
      refute_received {:remote, _method, _url, _body}
    end

    test "processes a repeated activity once", c do
      assert response(send_activity(c, follow(c)), 202)
      assert %{"type" => "Accept"} = delivered(c)

      assert response(send_activity(c, follow(c)), 202)
      assert delivered(c) == nil
    end

    test "forgets the activities it took in more than 30 days ago", c do
      assert response(send_activity(c, follow(c)), 202)
      assert %{"type" => "Accept"} = delivered(c)

      Repo.update_all(ReceivedActivity,
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -31, :day)]
      )

      recent = follow(c, "https://mastodon.example/follows/2")
      assert response(send_activity(c, recent), 202)
      assert %{"type" => "Accept"} = delivered(c)

      assert :ok = Fediverse.run_due()

      assert Enum.map(Repo.all(ReceivedActivity), & &1.activity_id) == [recent["id"]]
      assert response(send_activity(c, follow(c)), 202)
      assert %{"type" => "Accept"} = delivered(c)
    end

    test "limits the requests per client, behind a proxy too", %{site: site} do
      request = fn forwarded_for ->
        %{build_conn() | remote_ip: {10, 0, 0, 1}}
        |> put_req_header("x-forwarded-for", forwarded_for)
        |> put_req_header("content-type", "text/plain")
        |> post(inbox(site), "")
      end

      for _n <- 1..300, do: assert(request.("93.184.215.14").status == 415)

      assert response(request.("93.184.215.14"), 429)
      assert response(request.("6.6.6.6, 93.184.215.14"), 429)
      assert response(request.("93.184.215.15"), 415)
    end

    test "limits an IPv6 client per /64 and reads forwarded addresses with a port",
         %{site: site} do
      request = fn forwarded_for ->
        %{build_conn() | remote_ip: {10, 0, 0, 2}}
        |> put_req_header("x-forwarded-for", forwarded_for)
        |> put_req_header("content-type", "text/plain")
        |> post(inbox(site), "")
      end

      for n <- 1..300 do
        address = "[2a00:1450:4001:80b::#{Integer.to_string(n, 16)}]:443"
        assert request.(address).status == 415
      end

      assert response(request.("2a00:1450:4001:80b:ffff::1"), 429)
      assert response(request.("[2a00:1450:4001:80c::1]"), 415)

      for _n <- 1..300, do: assert(request.("93.184.215.20:5678").status == 415)
      assert response(request.("93.184.215.20"), 429)
    end

    test "a key fetch the limiter turns away does not spend the actor's fetch allowance", c do
      busy_limiter(:inbox)
      assert response(send_activity(c, follow(c)), 401)

      Application.delete_env(:feather, :fediverse_inbox_limiter)
      assert response(send_activity(c, follow(c)), 202)
    end

    test "counts only signed activities against the limit per host", c do
      ana = "https://social#{System.unique_integer([:positive])}.example/users/ana"
      serve(ana, c.public_key)
      c = %{c | ana: ana}

      forged = fn n ->
        %{build_conn() | remote_ip: {93, 184, 216, 34}}
        |> put_req_header("content-type", "application/activity+json")
        |> post(inbox(c.site), Jason.encode!(follow(c, ana <> "#follows/#{n}")))
      end

      for n <- 1..300, do: assert(response(forged.(n), 401))

      assert response(send_activity(c, follow(c, ana <> "#follows/0")), 202)
    end

    test "checks signatures in a pool of its own, so a full one leaves deliveries alone", c do
      busy_limiter(:inbox)

      assert response(send_activity(c, follow(c)), 401)
      refute_received {:remote, _method, _url, _body}

      bob = remote_account_fixture()
      bobs_inbox = bob.inbox
      assert :ok = Deliveries.deliver(c.site, [bob], %{"type" => "Note"})
      assert_received {:remote, "POST", ^bobs_inbox, _body}
    end

    test "checks signatures in a pool of its own, so a full general one leaves it alone", c do
      busy_limiter()
      ana = c.ana

      assert response(send_activity(c, follow(c)), 202)

      assert_received {:remote, "GET", ^ana, _body}
      assert_received {:remote, "GET", "https://mastodon.example/.well-known/webfinger", _body}
      assert [_follower] = followers(c.site)
      assert delivered(c) == nil
      assert [%Delivery{attempts: 0}] = Repo.all(Delivery)
    end
  end

  describe "a rejected activity" do
    # The test config only prints warnings.
    defp signature_value(headers) do
      {"signature", header} = List.keyfind(headers, "signature", 0)
      [_match, value] = Regex.run(~r/signature="([^"]+)"/, header)
      value
    end

    defp rejection_log(fun) do
      level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: level) end)
      capture_log([level: :info], fun)
    end

    test "logs why a signature failed, naming the signed headers", c do
      for {opts, reason, detail} <- [
            {[host: "timon.blog"], "wrong_host", ~s(host="timon.blog")},
            {[digest: "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, "{}"))], "digest", ""},
            {[date: DateTime.add(DateTime.utc_now(), -13, :hour)], "stale", "date="}
          ] do
        body = Jason.encode!(follow(c))
        headers = activity_headers(c, body, opts)
        log = rejection_log(fn -> assert response(post_signed(c, headers, body), 401) end)

        assert log =~ "Inbox rejected Follow from mastodon.example: unauthorized #{reason}"
        assert log =~ "key_host=mastodon.example"
        assert log =~ "signed=(request-target),host,date,digest"
        assert log =~ detail
        refute log =~ signature_value(headers)
        refute log =~ "follows/1"
      end
    end

    test "logs a missing signature", c do
      log =
        rejection_log(fn ->
          conn =
            build_conn()
            |> put_req_header("content-type", "application/activity+json")
            |> post(inbox(c.site), Jason.encode!(follow(c)))

          assert response(conn, 401)
        end)

      assert log =~ "Inbox rejected Follow from mastodon.example: unauthorized unsigned"
      assert log =~ "key_host=none signed=none"
    end

    test "logs a signature the fetched key does not verify", c do
      body = Jason.encode!(follow(c))
      headers = activity_headers(c, body, key: c.other_key)
      log = rejection_log(fn -> assert response(post_signed(c, headers, body), 401) end)

      assert log =~ "unauthorized not_verified key_host=mastodon.example"
      refute log =~ signature_value(headers)
    end

    test "logs what a key on another origin signed as ignored", c do
      body = Jason.encode!(follow(c))
      headers = activity_headers(c, body, key_id: "https://other.example/users/bob#main-key")
      log = rejection_log(fn -> assert response(post_signed(c, headers, body), 202) end)

      assert log =~
               "Inbox ignored Follow from mastodon.example: key_host=other.example " <>
                 "signed=(request-target),host,date,digest"

      refute log =~ "rejected"
      refute log =~ signature_value(headers)
    end

    test "logs no signed header names that are malformed or too many", c do
      body = Jason.encode!(follow(c))
      signed = ~s[headers="(request-target) host date digest"]

      for names <- [
            "(request-target) host date digest key_host=mastodon.social unauthorized not_verified",
            "(request-target) host date digest" <> String.duplicate(" x-padding", 13)
          ] do
        headers =
          c
          |> activity_headers(body, [])
          |> Enum.map(fn
            {"signature", value} ->
              {"signature", String.replace(value, signed, ~s(headers="#{names}"))}

            header ->
              header
          end)

        log = rejection_log(fn -> assert response(post_signed(c, headers, body), 401) end)

        assert log =~ "Inbox rejected Follow from mastodon.example: unauthorized"
        assert log =~ "signed=invalid"
        refute log =~ "mastodon.social"
        refute log =~ "x-padding"
      end
    end

    test "logs a forbidden and an invalid activity", c do
      log =
        rejection_log(fn ->
          delete = activity(c, "Delete", "https://other.example/users/ana/statuses/1", 1)
          assert response(send_activity(c, delete), 403)

          assert response(send_activity(c, Map.delete(follow(c), "id")), 400)
        end)

      assert log =~
               "Inbox rejected Delete from mastodon.example: forbidden key_host=mastodon.example " <>
                 "signed=(request-target),host,date,digest"

      assert log =~
               "Inbox rejected Follow from mastodon.example: invalid key_host=mastodon.example"
    end
  end

  describe "processing" do
    defp process_by_scheduler_only do
      Application.put_env(:feather, :fediverse_inbox, :scheduler)
      on_exit(fn -> Application.put_env(:feather, :fediverse_inbox, :inline) end)
    end

    defp received, do: Repo.all(ReceivedActivity)

    test "keeps an activity it answered, encrypted, until it is processed after a restart", c do
      process_by_scheduler_only()

      assert response(send_activity(c, follow(c)), 202)
      assert followers(c.site) == []

      %{rows: [[payload]]} = Repo.query!("SELECT payload FROM fediverse_received_activities")
      refute payload =~ "Follow"

      assert :ok = Fediverse.run_due()

      assert [_follower] = followers(c.site)
      assert %{"type" => "Accept"} = delivered(c)
      assert [%ReceivedActivity{payload: nil, processed_at: %DateTime{}}] = received()

      assert response(send_activity(c, follow(c)), 202)
      assert :ok = Fediverse.run_due()
      assert delivered(c) == nil
    end

    test "processes an activity sent again that it did not process yet", c do
      process_by_scheduler_only()
      assert response(send_activity(c, follow(c)), 202)

      Application.put_env(:feather, :fediverse_inbox, :inline)
      assert response(send_activity(c, follow(c)), 202)

      assert [_follower] = followers(c.site)
      assert %{"type" => "Accept"} = delivered(c)
    end

    test "processes what a crash interrupted once its claim lapsed", c do
      process_by_scheduler_only()
      assert response(send_activity(c, follow(c)), 202)

      claim = fn seconds ->
        Repo.update_all(ReceivedActivity,
          set: [claimed_until: DateTime.add(DateTime.utc_now(), seconds)]
        )
      end

      claim.(60)
      assert :ok = Fediverse.run_due()
      assert followers(c.site) == []

      claim.(-1)
      assert :ok = Fediverse.run_due()
      assert [_follower] = followers(c.site)
    end

    test "tries an activity whose processing failed again later and gives it up after a day",
         c do
      process_by_scheduler_only()
      assert response(send_activity(c, follow(c)), 202)
      Repo.update_all(ReceivedActivity, set: [payload: "{"])

      assert :ok = Fediverse.run_due()
      assert [%ReceivedActivity{attempts: 1, processed_at: nil} = failed] = received()
      assert DateTime.diff(failed.next_attempt_at, DateTime.utc_now()) in 55..60

      assert :ok = Fediverse.run_due()
      assert [%ReceivedActivity{attempts: 1}] = received()

      Repo.update_all(ReceivedActivity, set: [next_attempt_at: DateTime.utc_now()])
      assert :ok = Fediverse.run_due()
      assert [%ReceivedActivity{attempts: 2} = failed] = received()
      assert DateTime.diff(failed.next_attempt_at, DateTime.utc_now()) in 115..120

      Repo.update_all(ReceivedActivity,
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -25, :hour)]
      )

      assert :ok = Fediverse.run_due()
      assert received() == []
      assert followers(c.site) == []
    end

    test "takes an activity id another account of the server used as another activity", c do
      bob = "https://mastodon.example/users/bob#{System.unique_integer([:positive])}"
      serve([c.ana, bob], c.public_key)
      as_bob = %{c | ana: bob}

      assert response(send_activity(as_bob, follow(as_bob)), 202)
      assert response(send_activity(c, follow(c)), 202)

      assert [_bob, _ana] = followers(c.site)
    end
  end

  describe "the signer's key" do
    defp serve_failing_actors(public_key) do
      test_pid = self()

      Req.Test.stub(Feather.Fediverse, fn conn ->
        url = "https://#{conn.host}#{conn.request_path}"
        send(test_pid, {:remote, conn.method, url, ""})

        case conn.host do
          "timeout.example" ->
            Req.Test.transport_error(conn, :timeout)

          "html.example" ->
            conn
            |> put_resp_content_type("text/html")
            |> send_resp(200, Jason.encode!(actor(url, public_key)))

          "note.example" ->
            conn
            |> put_resp_content_type("application/activity+json")
            |> send_resp(200, Jason.encode!(%{actor(url, public_key) | "type" => "Note"}))

          _missing ->
            send_resp(conn, 404, "")
        end
      end)
    end

    defp answer(c, actor) do
      c = %{c | ana: actor}
      conn = send_activity(c, follow(c, actor <> "#follows/1"))
      {conn.status, conn.resp_body, List.keydelete(conn.resp_headers, "x-request-id", 0)}
    end

    test "answers every failed fetch of it with the same empty 401", c do
      serve_failing_actors(c.public_key)
      n = System.unique_integer([:positive])
      note_actor = "https://note.example/users/ana#{n}"

      failures =
        for actor <- [
              "https://127.0.0.1.nip.io/users/ana#{n}",
              "https://mastodon.example/users/missing#{n}",
              "https://timeout.example/users/ana#{n}",
              "https://html.example/users/ana#{n}",
              note_actor
            ],
            do: answer(c, actor)

      assert_received {:remote, "GET", ^note_actor, _body}
      rate_limited = answer(c, note_actor)
      refute_received {:remote, "GET", ^note_actor, _body}

      busy_limiter(:inbox)
      busy = answer(c, "https://mastodon.example/users/busy#{n}")

      assert [{401, "", _headers}] = Enum.uniq(failures ++ [rate_limited, busy])
      refute_received {:remote, _method, "https://127.0.0.1.nip.io" <> _path, _body}
      assert followers(c.site) == []
    end

    test "tries the cached key first and fetches the actor again at most once in 10 minutes",
         c do
      ana = c.ana

      known_ana(c)

      assert response(send_activity(c, follow(c)), 202)
      refute_received {:remote, "GET", ^ana, _body}

      unfollow = activity(c, "Undo", Map.delete(follow(c), "@context"), 1)
      assert response(send_activity(c, unfollow, key: c.other_key), 401)
      assert_received {:remote, "GET", ^ana, _body}

      assert response(send_activity(c, unfollow, key: c.other_key), 401)
      refute_received {:remote, "GET", ^ana, _body}
      assert [_follower] = followers(c.site)
    end
  end

  describe "inbox handling" do
    test "accepts a follow and answers with Accept", c do
      assert response(send_activity(c, follow(c)), 202)

      assert [%Follower{follow_id: "https://mastodon.example/follows/1"} = follower] =
               followers(c.site)

      assert follower.remote_account.uri == c.ana
      assert Fediverse.count_followers(c.scope) == 1

      assert %{"type" => "Accept", "actor" => @account, "object" => object} = delivered(c)

      assert object == %{
               "id" => "https://mastodon.example/follows/1",
               "type" => "Follow",
               "actor" => c.ana,
               "object" => @account
             }
    end

    test "answers a follow once the account is online", c do
      site = fediverse_site_fixture(%{domain: "pumbaa.blog", online: false})
      follow = %{follow(c) | "object" => "https://pumbaa.blog/activitypub/timon"}

      assert response(send_activity(%{c | site: site}, follow), 202)

      assert [_follower] = followers(site)
      assert delivered(c) == nil
      assert [%Delivery{} = delivery] = Repo.all(Delivery)
      assert delivery.inbox == c.ana <> "/inbox"
    end

    test "ignores a follow of another account", c do
      follow = %{follow(c) | "object" => "https://timon.blog/activitypub/pumbaa"}

      assert response(send_activity(c, follow), 202)
      assert followers(c.site) == []
      refute_received {:remote, _method, _url, _body}
    end

    test "removes the follower on Undo", c do
      assert response(send_activity(c, follow(c)), 202)

      undo = activity(c, "Undo", Map.delete(follow(c), "@context"), 1)

      assert response(send_activity(c, undo), 202)
      assert followers(c.site) == []
    end

    test "keeps a follow sent again when the Undo of an older one comes late", c do
      assert response(send_activity(c, follow(c, "https://mastodon.example/follows/2")), 202)

      undo = activity(c, "Undo", Map.delete(follow(c), "@context"), 1)

      assert response(send_activity(c, undo), 202)
      assert [%Follower{follow_id: "https://mastodon.example/follows/2"}] = followers(c.site)
    end

    test "accepts at most 100 new followers of a server within an hour, refusing more with Reject",
         c do
      n = System.unique_integer([:positive])
      carl = "https://mastodon.example/users/carl#{n}"
      bob = "https://other.example/users/bob#{n}"
      serve([c.ana, carl, bob], c.public_key)
      as_carl = %{c | ana: carl}
      as_bob = %{c | ana: bob}

      assert response(send_activity(c, follow(c)), 202)
      assert %{"type" => "Accept"} = delivered(c)
      for _n <- 1..99, do: follower_fixture(c.site)

      assert response(send_activity(as_carl, follow(as_carl)), 202)
      assert %{"type" => "Reject"} = delivered(as_carl)

      refute Repo.get_by(RemoteAccount, uri: carl).id in Enum.map(
               followers(c.site),
               & &1.remote_account_id
             )

      assert response(send_activity(c, follow(c, "https://mastodon.example/follows/2")), 202)
      assert %{"type" => "Accept"} = delivered(c)

      assert response(
               send_activity(as_bob, follow(as_bob, "https://other.example/follows/1")),
               202
             )

      assert length(followers(c.site)) == 101

      Repo.update_all(Follower,
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -61, :minute)]
      )

      assert response(
               send_activity(as_carl, follow(as_carl, "https://mastodon.example/follows/3")),
               202
             )

      assert %{"type" => "Accept"} = delivered(as_carl)
    end

    test "ignores likes and boosts", c do
      post = "https://timon.blog/activitypub/posts/abc"

      assert response(send_activity(c, activity(c, "Like", post, 1)), 202)
      assert response(send_activity(c, activity(c, "Announce", post, 2)), 202)

      assert followers(c.site) == []
      refute_received {:remote, _method, _url, _body}
    end

    test "purges the follow and the site's pending deliveries to a deleted account's own inbox",
         c do
      assert response(send_activity(c, follow(c)), 202)
      ana = Repo.get_by!(RemoteAccount, uri: c.ana)
      other_site = fediverse_site_fixture(%{domain: "pumbaa.blog"})

      queue = fn site, inbox ->
        Repo.insert!(%Delivery{
          site_id: site.id,
          inbox: inbox,
          host: "mastodon.example",
          payload: "{}",
          next_attempt_at: DateTime.add(DateTime.utc_now(), 3600)
        })
      end

      queue.(c.site, ana.inbox)
      other_sites = queue.(other_site, ana.inbox)
      shared = queue.(c.site, "https://mastodon.example/inbox")

      delete = %{activity(c, "Delete", c.ana) | "id" => c.ana <> "#delete"}

      assert response(send_activity(c, delete), 202)

      assert followers(c.site) == []

      assert Repo.all(from d in Delivery, order_by: d.inbox, select: d.id) == [
               shared.id,
               other_sites.id
             ]

      refute Repo.get(RemoteAccount, ana.id)
    end
  end

  describe "blocks" do
    test "refuses a follow from a blocked server with Reject", c do
      bob = remote_account_fixture(%{uri: "https://mastodon.example/users/bob"})
      {:ok, _block} = Fediverse.block(c.scope, bob, :server)

      assert response(send_activity(c, follow(c)), 202)

      assert followers(c.site) == []
      assert %{"type" => "Reject", "actor" => @account, "object" => object} = delivered(c)

      assert object == %{
               "id" => "https://mastodon.example/follows/1",
               "type" => "Follow",
               "actor" => c.ana,
               "object" => @account
             }
    end

    test "drops everything else of a blocked account without fetching anything", c do
      ana = known_ana(c)
      {:ok, _block} = Fediverse.block(c.scope, ana, :account)
      assert %{"type" => "Block"} = delivered(c)

      assert response(send_activity(c, create(c, private_note(c, 1), 1)), 202)
      assert response(send_activity(c, activity(c, "Delete", c.ana)), 202)

      assert mentions(c.site) == []
      assert Repo.get(RemoteAccount, ana.id)
      refute_received {:remote, _method, _url, _body}
    end
  end

  describe "a Delete before its Create" do
    test "of a known account leaves a tombstone without fetching anything", c do
      known_ana(c)
      note = private_note(c, 1)

      assert response(send_activity(c, activity(c, "Delete", note["id"], 1)), 202)
      refute_received {:remote, _method, _url, _body}

      assert response(send_activity(c, create(c, note, 2)), 202)
      assert mentions(c.site) == []
    end

    test "refuses a Create that waited to be processed", c do
      process_by_scheduler_only()
      note = private_note(c, 1)

      assert response(send_activity(c, create(c, note, 1)), 202)

      Application.put_env(:feather, :fediverse_inbox, :inline)
      assert response(send_activity(c, activity(c, "Delete", note["id"], 2)), 202)

      assert :ok = Fediverse.run_due()
      assert mentions(c.site) == []
    end

    test "of an account the CMS does not know is ignored", c do
      note = private_note(c, 1)

      assert response(send_activity(c, activity(c, "Delete", note["id"], 1)), 202)
      assert response(send_activity(c, create(c, note, 2)), 202)
      assert [_mention] = mentions(c.site)
    end

    test "by another account of the server does not bury the author's object", c do
      bob = "https://mastodon.example/users/bob#{System.unique_integer([:positive])}"
      known(bob, c.public_key)
      as_bob = %{c | ana: bob}
      note = private_note(c, 1)

      assert response(send_activity(as_bob, activity(as_bob, "Delete", note["id"], 1)), 202)
      assert response(send_activity(c, create(c, note, 2)), 202)
      assert [_mention] = mentions(c.site)
    end
  end

  describe "an unsigned or forged probe" do
    test "gets the same answer for followers, followed, blocked and other accounts", c do
      n = System.unique_integer([:positive])

      [follower, followed, blocked, author, _stranger] =
        uris =
        for name <- ~w(follower followed blocked author stranger),
            do: "https://mastodon.example/users/#{name}#{n}"

      serve(uris, c.public_key)
      accounts = Map.new(uris, &{&1, known(&1, c.public_key)})

      follower_fixture(c.site, accounts[follower])

      followed =
        followed_account_fixture(c.site, remote_account: accounts[followed], accepted: false)

      {:ok, _block} = Fediverse.block(c.scope, accounts[blocked], :account)
      mention_fixture(c.site, remote_account: accounts[author], uri: author <> "/statuses/1")

      probes = fn actor ->
        as = %{c | ana: actor}
        undone = %{"id" => actor <> "#follow", "type" => "Follow", "object" => @account}

        [
          activity(as, "Undo", Map.put(undone, "actor", actor), 1),
          activity(as, "Accept", followed.follow_id, 2),
          activity(as, "Update", note(as, 1, %{}), 3),
          activity(as, "Delete", actor <> "/statuses/1", 4),
          create(as, private_note(as, 2), 5)
        ]
      end

      unsigned = fn activity ->
        build_conn()
        |> put_req_header("content-type", "application/activity+json")
        |> post(inbox(c.site), Jason.encode!(activity))
      end

      answers =
        for actor <- uris, activity <- probes.(actor) do
          forged = send_activity(%{c | ana: actor}, activity, key: c.other_key)
          {unsigned.(activity).status, forged.status}
        end

      assert Enum.uniq(answers) == [{401, 401}]

      unknown = "https://mastodon.example/users/unknown#{n}"
      assert unknown |> probes.() |> Enum.map(&unsigned.(&1).status) |> Enum.uniq() == [401]

      assert [_follower] = followers(c.site)
      assert [%Mention{content: "Hello @timon"}] = mentions(c.site)
      refute FollowedAccount.accepted?(Repo.reload!(followed))
    end
  end

  describe "mentions" do
    test "files a reply, a mention and a private message into Mentions of the addressed site only",
         c do
      post = post_fixture(c.scope)
      pumbaa_site = fediverse_site_fixture(%{domain: "pumbaa.blog", fediverse_name: "pumbaa"})
      pumbaa = "https://pumbaa.blog/activitypub/pumbaa"

      reply =
        note(c, 1, %{"inReplyTo" => "https://timon.blog/activitypub/posts/#{post.public_id}"})

      mention = note(c, 2, %{"cc" => [c.ana <> "/followers", @account], "tag" => mention_of()})
      private = private_note(c, 3)
      for_pumbaa = note(c, 4, %{"to" => [pumbaa], "cc" => [], "tag" => mention_of(pumbaa)})

      for {note, n} <- Enum.with_index([reply, mention, private, for_pumbaa], 1) do
        assert response(send_activity(c, create(c, note, n)), 202)
      end

      assert response(send_activity(%{c | site: pumbaa_site}, create(c, private, 5)), 202)

      assert [filed_reply, filed_mention, filed_private] = mentions(c.site)
      assert {filed_reply.uri, filed_reply.post_id} == {reply["id"], post.id}
      assert {filed_mention.uri, filed_mention.post_id} == {mention["id"], nil}
      assert filed_private.uri == private["id"]

      assert Enum.map([filed_reply, filed_mention, filed_private], & &1.visibility) ==
               [:public, :public, :direct]

      assert filed_reply.remote_account_id == Repo.get_by!(RemoteAccount, uri: c.ana).id
      assert mentions(pumbaa_site) == []
    end

    test "files a reply to the author's followers as followers only", c do
      followers_only = note(c, 1, %{"to" => [c.ana <> "/followers"], "cc" => [@account]})

      assert response(send_activity(c, create(c, followers_only, 1)), 202)
      assert [%Mention{visibility: :followers}] = mentions(c.site)
    end

    test "keeps the content sanitized and encrypted, the author and the time in clear text", c do
      note =
        private_note(c, 1, %{
          "content" =>
            ~s|<p>Secret <script>alert(1)</script><a href="/tags/x">#x</a></p>| <>
              ~s(<p><a href="https://ana.example/" class="u-url">ana</a></p>),
          "summary" => "Secret <b>spoiler</b>",
          "attachment" => [
            %{
              "type" => "Document",
              "mediaType" => "image/png",
              "url" => "https://files.mastodon.example/secret.png",
              "name" => "A secret picture"
            }
          ]
        })

      assert response(send_activity(c, create(c, note, 1)), 202)

      assert [mention] = mentions(c.site)

      assert mention.content ==
               ~s(Secret <a>#x</a><br><br><a href="https://ana.example/" rel="nofollow ugc noopener">ana</a>)

      assert mention.summary == "Secret <b>spoiler</b>"

      assert mention.attachments == [
               %{
                 "url" => "https://files.mastodon.example/secret.png",
                 "media_type" => "image/png",
                 "name" => "A secret picture"
               }
             ]

      assert mention.url == "https://mastodon.example/@ana/1"
      assert mention.published_at == ~U[2026-10-23 12:00:00.000000Z]

      %{rows: [[uri, content, summary, attachments]]} =
        Repo.query!("SELECT uri, content, summary, attachments FROM fediverse_mentions")

      assert uri == note["id"]
      for column <- [content, summary, attachments], do: refute(column =~ "ecret")
    end

    test "changes a mention on Update and removes it on Delete", c do
      note = private_note(c, 1)

      assert response(send_activity(c, create(c, note, 1)), 202)

      edited = %{note | "content" => "<p>Edited</p>", "cc" => [c.ana <> "/followers"]}
      assert response(send_activity(c, activity(c, "Update", edited, 2)), 202)
      assert [%Mention{content: "Edited", visibility: :followers}] = mentions(c.site)

      tombstone = %{"id" => note["id"], "type" => "Tombstone"}
      assert response(send_activity(c, activity(c, "Delete", tombstone, 3)), 202)
      assert mentions(c.site) == []
    end

    test "leaves a mention alone that another account of its server updates or deletes", c do
      bob = "https://mastodon.example/users/bob#{System.unique_integer([:positive])}"
      serve([c.ana, bob], c.public_key)
      note = private_note(c, 1)

      assert response(send_activity(c, create(c, note, 1)), 202)

      as_bob = %{c | ana: bob}
      edited = Map.delete(%{note | "content" => "<p>Bob was here</p>"}, "attributedTo")

      assert response(send_activity(as_bob, activity(as_bob, "Update", edited, 2)), 202)
      assert response(send_activity(as_bob, activity(as_bob, "Delete", note["id"], 3)), 202)
      assert [%Mention{content: "Note 1"}] = mentions(c.site)
    end

    test "purges the mentions of a deleted account", c do
      assert response(send_activity(c, create(c, private_note(c, 1), 1)), 202)
      assert [_mention] = mentions(c.site)

      delete = %{activity(c, "Delete", c.ana, 2) | "id" => c.ana <> "#delete"}

      assert response(send_activity(c, delete), 202)
      assert mentions(c.site) == []
    end
  end

  describe "replies" do
    setup c do
      %{target: deployment_target_fixture(c.scope), post: post_fixture(c.scope)}
    end

    defp reply_to(c, n, attrs \\ %{}),
      do: note(c, n, Map.merge(%{"inReplyTo" => Fediverse.post_url(c.site, c.post)}, attrs))

    defp approve_filed(c) do
      assert [mention] = mentions(c.site)

      assert {:ok, %Mention{approval: :approved}} =
               Fediverse.approve_reply(c.scope, mention, Mention.version(mention))

      assert_received {:deploy_requested, _target}
    end

    test "a reply waits for approval and waits again once its author edits it", c do
      reply = reply_to(c, 1)

      assert response(send_activity(c, create(c, reply, 1)), 202)
      assert [%Mention{approval: :waiting}] = mentions(c.site)
      assert Fediverse.approved_replies(c.site, [c.post]) == %{}

      approve_filed(c)
      assert [%Mention{}] = Fediverse.approved_replies(c.site, [c.post])[c.post.id]

      edited = %{reply | "content" => "<p>Edited</p>"}
      assert response(send_activity(c, activity(c, "Update", edited, 2)), 202)

      assert [%Mention{approval: :waiting, content: "Edited"}] = mentions(c.site)
      assert Fediverse.approved_replies(c.site, [c.post]) == %{}
      refute_received {:deploy_requested, _target}
    end

    test "a deleted reply leaves the site with a deploy, and a later Create is refused", c do
      reply = reply_to(c, 1)

      assert response(send_activity(c, create(c, reply, 1)), 202)
      approve_filed(c)

      tombstone = %{"id" => reply["id"], "type" => "Tombstone"}
      assert response(send_activity(c, activity(c, "Delete", tombstone, 2)), 202)

      assert mentions(c.site) == []
      assert_received {:deploy_requested, _target}

      assert response(send_activity(c, create(c, reply, 3)), 202)
      assert mentions(c.site) == []
    end

    test "a reply to the author's followers or in a private message cannot be approved", c do
      followers_only = reply_to(c, 1, %{"to" => [c.ana <> "/followers"], "cc" => [@account]})
      private = reply_to(c, 2, %{"to" => [@account], "cc" => [], "tag" => mention_of()})

      assert response(send_activity(c, create(c, followers_only, 1)), 202)
      assert response(send_activity(c, create(c, private, 2)), 202)

      assert [_followers_only, _private] = filed = mentions(c.site)

      for mention <- filed,
          do:
            assert(
              Fediverse.approve_reply(c.scope, mention, Mention.version(mention)) ==
                {:error, :not_approvable}
            )

      %{rows: rows} = Repo.query!("SELECT content FROM fediverse_mentions")
      for [content] <- rows, do: refute(content =~ "Note")
    end
  end

  describe "Timeline" do
    setup c do
      {:ok, ana} = RemoteAccounts.fetch(c.site, c.ana)
      %{followed: followed_account_fixture(c.site, remote_account: ana)}
    end

    defp timeline(site),
      do: Repo.all(from t in TimelinePost, where: t.site_id == ^site.id, order_by: t.uri)

    defp followers_only(c, n), do: note(c, n, %{"to" => [c.ana <> "/followers"], "cc" => []})

    test "files a post of a followed account into the Timeline", c do
      article =
        note(c, 1, %{
          "type" => "Article",
          "name" => "Hakuna <b>matata</b>",
          "content" => ~s{<p>No worries <script>alert(1)</script></p>},
          "attachment" => [
            %{
              "type" => "Document",
              "mediaType" => "image/png",
              "url" => "https://files.mastodon.example/1.png",
              "name" => "Two friends"
            }
          ]
        })

      assert response(send_activity(c, create(c, article, 1)), 202)

      assert [post] = timeline(c.site)
      assert post.followed_account_id == c.followed.id
      assert post.uri == article["id"]
      assert post.url == "https://mastodon.example/@ana/1"
      assert post.visibility == :public
      assert post.name == "Hakuna <b>matata</b>"
      assert post.content == "No worries "

      assert [%{"url" => "https://files.mastodon.example/1.png", "name" => "Two friends"}] =
               post.attachments

      assert mentions(c.site) == []

      %{rows: [[name, content]]} =
        Repo.query!("SELECT name, content FROM fediverse_timeline_posts")

      for column <- [name, content], do: refute(column =~ "matata" or column =~ "worries")
    end

    test "files no post of an account the site does not follow, nor a private message", c do
      bob = "https://mastodon.example/users/bob#{System.unique_integer([:positive])}"
      as_bob = %{c | ana: bob}

      assert response(send_activity(as_bob, create(as_bob, note(as_bob, 1, %{}), 1)), 202)
      refute_received {:remote, _method, ^bob, _body}

      assert response(send_activity(c, create(c, private_note(c, 2), 2)), 202)

      assert timeline(c.site) == []
      assert [%Mention{visibility: :direct}] = mentions(c.site)
    end

    test "files a reply of a followed account to a post into the Timeline and Mentions", c do
      post = post_fixture(c.scope)
      reply = note(c, 1, %{"inReplyTo" => Fediverse.post_url(c.site, post)})

      assert response(send_activity(c, create(c, reply, 1)), 202)

      assert [%TimelinePost{}] = timeline(c.site)
      assert [%Mention{post_id: post_id}] = mentions(c.site)
      assert post_id == post.id
    end

    test "files posts to the author's followers only once the site's follow was accepted", c do
      Repo.update!(Ecto.Changeset.change(c.followed, accepted_at: nil))

      assert response(send_activity(c, create(c, followers_only(c, 1), 1)), 202)
      assert timeline(c.site) == []

      accept = activity(c, "Accept", %{"id" => c.followed.follow_id, "type" => "Follow"}, 2)
      assert response(send_activity(c, accept), 202)
      assert FollowedAccount.accepted?(Repo.reload!(c.followed))

      assert response(send_activity(c, create(c, followers_only(c, 3), 3)), 202)
      assert [%TimelinePost{visibility: :followers}] = timeline(c.site)
    end

    test "ignores the Accept of another follow", c do
      Repo.update!(Ecto.Changeset.change(c.followed, accepted_at: nil))

      accept = activity(c, "Accept", "https://timon.blog/activitypub/timon#follows/other", 1)

      assert response(send_activity(c, accept), 202)
      refute FollowedAccount.accepted?(Repo.reload!(c.followed))
    end

    test "ends the follow on Reject, with the account's posts", c do
      assert response(send_activity(c, create(c, note(c, 1, %{}), 1)), 202)
      assert [_post] = timeline(c.site)

      reject =
        activity(
          c,
          "Reject",
          %{
            "type" => "Follow",
            "actor" => @account,
            "object" => c.ana
          },
          2
        )

      assert response(send_activity(c, reject), 202)
      refute Repo.get(FollowedAccount, c.followed.id)
      assert timeline(c.site) == []
    end

    test "changes a post on Update and removes it on Delete, for good", c do
      post = note(c, 1, %{})
      assert response(send_activity(c, create(c, post, 1)), 202)

      edited = %{post | "content" => "<p>Edited</p>"}
      assert response(send_activity(c, activity(c, "Update", edited, 2)), 202)
      assert [%TimelinePost{content: "Edited"}] = timeline(c.site)

      tombstone = %{"id" => post["id"], "type" => "Tombstone"}
      assert response(send_activity(c, activity(c, "Delete", tombstone, 3)), 202)
      assert timeline(c.site) == []

      assert response(send_activity(c, create(c, post, 4)), 202)
      assert timeline(c.site) == []
    end

    test "purges the Timeline posts of a deleted account", c do
      assert response(send_activity(c, create(c, note(c, 1, %{}), 1)), 202)

      delete = %{activity(c, "Delete", c.ana, 2) | "id" => c.ana <> "#delete"}

      assert response(send_activity(c, delete), 202)
      assert timeline(c.site) == []
      refute Repo.get(FollowedAccount, c.followed.id)
    end
  end
end
