defmodule Feather.Fediverse.DeliveriesTest do
  use Feather.DataCase

  import ExUnit.CaptureLog
  import Plug.Conn

  alias Feather.Fediverse
  alias Feather.Fediverse.{Deliveries, Delivery}

  @moduletag :capture_log

  @activity %{
    "@context" => "https://www.w3.org/ns/activitystreams",
    "id" => "https://timon.blog/activitypub/posts/abc#create",
    "type" => "Create",
    "object" => %{"type" => "Note", "content" => "<p>Hakuna matata</p>"}
  }

  setup do
    %{site: fediverse_site_fixture(%{domain: "timon.blog"})}
  end

  defp answer(status) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      [signature] = get_req_header(conn, "signature")
      send(test_pid, {:delivered, conn.host, conn.request_path, body, signature})
      send_resp(conn, status, "")
    end)
  end

  defp deliveries, do: Repo.all(from d in Delivery, order_by: [d.inserted_at, d.attempts])

  # Moves the queue back in time, as if `microseconds` had passed.
  defp travel(microseconds) do
    for delivery <- Repo.all(Delivery) do
      Repo.update_all(from(d in Delivery, where: d.id == ^delivery.id),
        set: [
          inserted_at: DateTime.add(delivery.inserted_at, -microseconds, :microsecond),
          next_attempt_at: DateTime.add(delivery.next_attempt_at, -microseconds, :microsecond)
        ]
      )
    end
  end

  defp microseconds_until(datetime),
    do: DateTime.diff(datetime, DateTime.utc_now(), :microsecond)

  test "delivers an activity at once, signed, to each server's shared inbox", %{site: site} do
    ana =
      remote_account_fixture(%{
        uri: "https://mastodon.example/users/ana",
        inbox: "https://mastodon.example/users/ana/inbox",
        shared_inbox: "https://mastodon.example/inbox"
      })

    bob =
      remote_account_fixture(%{
        uri: "https://mastodon.example/users/bob",
        inbox: "https://mastodon.example/users/bob/inbox",
        shared_inbox: "https://mastodon.example/inbox"
      })

    cleo =
      remote_account_fixture(%{
        uri: "https://micro.example/cleo",
        inbox: "https://micro.example/cleo/inbox"
      })

    answer(202)
    assert :ok = Deliveries.deliver(site, [ana, bob, cleo], @activity)

    assert_received {:delivered, "mastodon.example", "/inbox", body, signature}
    assert Jason.decode!(body) == @activity
    assert signature =~ ~s(keyId="https://timon.blog/activitypub/timon#main-key")
    assert_received {:delivered, "micro.example", "/cleo/inbox", ^body, _signature}
    refute_received {:delivered, _host, _path, _body, _signature}
    assert deliveries() == []
  end

  test "a failed delivery is retried with backoff and dropped after about a week",
       %{site: site} do
    answer(503)
    assert :ok = Deliveries.deliver(site, [remote_account_fixture()], @activity)
    assert_received {:delivered, "mastodon.example", _path, _body, _signature}

    assert [%Delivery{attempts: 1} = delivery] = deliveries()
    assert_in_delta microseconds_until(delivery.next_attempt_at), 60_000_000, 2_000_000

    assert :ok = Deliveries.deliver_due()
    refute_received {:delivered, _host, _path, _body, _signature}

    pauses = retry_until_dropped([])

    assert Enum.take(pauses, 4) == [60, 120, 240, 480]
    assert pauses == Enum.sort(pauses)
    assert List.last(pauses) == 12 * 3600
    assert Enum.sum(pauses) in (6 * 86_400)..(7 * 86_400)
  end

  defp retry_until_dropped(pauses) do
    case deliveries() do
      [] ->
        Enum.reverse(pauses)

      [delivery] ->
        pause = microseconds_until(delivery.next_attempt_at)
        travel(pause + 1_000)
        assert :ok = Deliveries.deliver_due()
        assert_received {:delivered, _host, _path, _body, _signature}
        retry_until_dropped([round(pause / 1_000_000) | pauses])
    end
  end

  test "overlapping runs do not send a delivery twice", %{site: site} do
    answer(503)
    assert :ok = Deliveries.deliver(site, [remote_account_fixture()], @activity)
    assert_received {:delivered, _host, _path, _body, _signature}
    travel(120_000_000)

    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:sending, self()})

      receive do
        :go -> send_resp(conn, 202, "")
      end
    end)

    first_run = Task.async(fn -> Deliveries.deliver_due() end)
    assert_receive {:sending, sender}

    assert :ok = Deliveries.deliver_due()
    refute_received {:sending, _sender}

    send(sender, :go)
    assert :ok = Task.await(first_run)
    refute_received {:sending, _sender}
    assert deliveries() == []
  end

  defp queue_due(site, attrs) do
    host = Keyword.fetch!(attrs, :host)

    Repo.insert!(%Delivery{
      site_id: site.id,
      inbox: "https://#{host}/inbox",
      host: host,
      payload: Jason.encode!(@activity),
      attempts: Keyword.get(attrs, :attempts, 0),
      next_attempt_at: Keyword.fetch!(attrs, :at)
    })
  end

  # Holds every request until the test sends :go to the process that made it.
  defp hold_requests do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:sending, self(), conn.host})

      receive do
        :go -> send_resp(conn, 202, "")
      end
    end)
  end

  defp sending_hosts(count) do
    for _request <- 1..count do
      assert_receive {:sending, sender, host}
      {sender, host}
    end
  end

  test "sends the due deliveries four at a time", %{site: site} do
    at = DateTime.add(DateTime.utc_now(), -1)
    for n <- 1..5, do: queue_due(site, host: "host#{n}.example", at: at)
    hold_requests()

    run = Task.async(fn -> Deliveries.deliver_due() end)
    sending = sending_hosts(4)
    refute_receive {:sending, _sender, _host}, 200

    for {sender, _host} <- sending, do: send(sender, :go)
    [{last, _host}] = sending_hosts(1)
    send(last, :go)

    assert :ok = Task.await(run)
    assert deliveries() == []
  end

  test "of the deliveries due at the same time, those tried before go first", %{site: site} do
    at = DateTime.add(DateTime.utc_now(), -1)
    queue_due(site, host: "fresh.example", at: at)
    for n <- 1..4, do: queue_due(site, host: "tried#{n}.example", attempts: n, at: at)
    hold_requests()

    run = Task.async(fn -> Deliveries.deliver_due() end)
    sending = sending_hosts(4)

    assert sending |> Enum.map(&elem(&1, 1)) |> Enum.sort() ==
             ~w(tried1.example tried2.example tried3.example tried4.example)

    for {sender, _host} <- sending, do: send(sender, :go)
    assert [{last, "fresh.example"}] = sending_hosts(1)
    send(last, :go)

    assert :ok = Task.await(run)
  end

  test "a host that fails backs off as a whole", %{site: site} do
    ana =
      remote_account_fixture(%{
        uri: "https://down.example/users/ana",
        inbox: "https://down.example/users/ana/inbox"
      })

    bob =
      remote_account_fixture(%{
        uri: "https://down.example/users/bob",
        inbox: "https://down.example/users/bob/inbox"
      })

    answer(503)
    assert :ok = Deliveries.deliver(site, [ana, bob], @activity)
    assert_received {:delivered, "down.example", _path, _body, _signature}
    refute_received {:delivered, _host, _path, _body, _signature}

    assert deliveries() |> Enum.map(& &1.attempts) |> Enum.sort() == [0, 1]
    assert [backing_off_until] = deliveries() |> Enum.map(& &1.next_attempt_at) |> Enum.uniq()
    assert_in_delta microseconds_until(backing_off_until), 60_000_000, 2_000_000

    assert :ok = Deliveries.deliver(site, [ana], %{@activity | "type" => "Update"})
    refute_received {:delivered, _host, _path, _body, _signature}

    assert deliveries() |> Enum.map(& &1.next_attempt_at) |> Enum.uniq() == [backing_off_until]
  end

  test "a delivery the limiter turns away goes again soon, without holding up its host",
       %{site: site} do
    ana = remote_account_fixture()
    busy_limiter()

    assert :ok = Deliveries.deliver(site, [ana], @activity)

    assert [%Delivery{attempts: 0} = delivery] = deliveries()
    assert_in_delta microseconds_until(delivery.next_attempt_at), 60_000_000, 2_000_000

    Application.delete_env(:feather, :fediverse_limiter)
    answer(202)

    assert :ok = Deliveries.deliver(site, [ana], %{@activity | "type" => "Update"})
    assert_received {:delivered, "mastodon.example", _path, _body, _signature}
    assert [%Delivery{id: id}] = deliveries()
    assert id == delivery.id

    travel(60_000_000)
    assert :ok = Deliveries.deliver_due()
    assert_received {:delivered, "mastodon.example", _path, _body, _signature}
    assert deliveries() == []
  end

  test "deliveries wait until a deploy has put the site's account online" do
    site = fediverse_site_fixture(%{online: false})
    answer(202)

    assert :ok = Deliveries.deliver(site, [remote_account_fixture()], @activity)
    assert :ok = Deliveries.deliver_due()
    refute_received {:delivered, _host, _path, _body, _signature}

    :ok = Fediverse.record_online(site, DateTime.utc_now())
    assert :ok = Deliveries.deliver_due()
    assert_received {:delivered, "mastodon.example", _path, _body, _signature}
    assert deliveries() == []
  end

  test "drops a delivery that is refused, retries one the server cannot take now",
       %{site: site} do
    local = remote_account_fixture(%{inbox: "https://127.0.0.1.nip.io/inbox"})

    gone =
      remote_account_fixture(%{
        uri: "https://gone.example/a",
        inbox: "https://gone.example/inbox"
      })

    busy =
      remote_account_fixture(%{
        uri: "https://busy.example/a",
        inbox: "https://busy.example/inbox"
      })

    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:delivered, conn.host})
      send_resp(conn, if(conn.host == "gone.example", do: 410, else: 429), "")
    end)

    assert :ok = Deliveries.deliver(site, [local, gone, busy], @activity)

    assert_received {:delivered, "gone.example"}
    assert_received {:delivered, "busy.example"}
    refute_received {:delivered, _host}
    assert [%Delivery{inbox: "https://busy.example/inbox", attempts: 1}] = deliveries()
  end

  test "drops a delivery whose inbox answers with a redirect", %{site: site} do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:delivered, conn.host})

      conn
      |> put_resp_header("location", "https://mastodon.example/new-inbox")
      |> send_resp(301, "")
    end)

    assert :ok = Deliveries.deliver(site, [remote_account_fixture()], @activity)

    assert_received {:delivered, "mastodon.example"}
    refute_received {:delivered, _host}
    assert deliveries() == []
  end

  test "logs what an inbox answered when it refused a delivery", %{site: site} do
    Req.Test.stub(Feather.Fediverse, fn conn ->
      send_resp(conn, 401, ~s({"error":\n  "Signature invalid"}))
    end)

    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)

    log =
      capture_log([level: :info], fn ->
        assert :ok = Deliveries.deliver(site, [remote_account_fixture()], @activity)
      end)

    assert log =~ "failed (attempt 1)"
    assert log =~ ~s({:status, 401, "{\\"error\\": \\"Signature invalid\\"}"})
  end

  test "stores payloads encrypted", %{site: site} do
    answer(503)
    assert :ok = Deliveries.deliver(site, [remote_account_fixture()], @activity)

    [[inbox, payload]] = Repo.query!("SELECT inbox, payload FROM fediverse_deliveries").rows
    assert inbox =~ "https://mastodon.example/"
    refute payload =~ "Hakuna"
  end
end
