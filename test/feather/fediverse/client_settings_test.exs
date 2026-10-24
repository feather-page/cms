defmodule Feather.Fediverse.ClientSettingsTest do
  # These tests change the application env, so they cannot run async with the other client tests.
  use ExUnit.Case

  import Plug.Conn

  alias Feather.Fediverse.{Client, Limiter, SigningKey}

  @actor "https://mastodon.example/users/ana"

  setup_all do
    %{
      key: %SigningKey{
        key_id: "https://timon.blog/activitypub/timon#main-key",
        private_key: :public_key.generate_key({:rsa, 2048, 65_537})
      }
    }
  end

  defp put_env(key, value) do
    previous = Application.fetch_env(:feather, key)
    Application.put_env(:feather, key, value)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:feather, key, value)
        :error -> Application.delete_env(:feather, key)
      end
    end)
  end

  test "sends every request through the configured proxy, after a redirect too", %{key: key} do
    proxy = {:http, "proxy.example", 3128}
    put_env(:fediverse_proxy, proxy)
    put_env(:fediverse_req_options, adapter: Feather.ReportingAdapter)

    Req.Test.stub(Feather.Fediverse, fn conn ->
      case conn.host do
        "old.example" ->
          conn |> put_resp_header("location", @actor) |> send_resp(301, "")

        "mastodon.example" ->
          conn
          |> put_resp_content_type("application/activity+json")
          |> send_resp(200, ~s({"id": "#{@actor}"}))
      end
    end)

    assert {:ok, %{"id" => @actor}, _url} =
             Client.get_object("https://old.example/users/ana", key)

    assert_received {:connecting, "old.example", %{proxy: ^proxy, ip: {93, 184, 215, 14}}}
    assert_received {:connecting, "mastodon.example", %{proxy: ^proxy, ip: {93, 184, 215, 14}}}
  end

  test "a redirect waits for a slot of its own host", %{key: key, test: limiter} do
    start_supervised!({Limiter, name: limiter, max_per_host: 1})
    put_env(:fediverse_limiter, server: limiter, timeout: 100)
    test_pid = self()

    holder =
      Task.async(fn ->
        Limiter.run(
          "mastodon.example",
          fn ->
            send(test_pid, :holding)
            receive do: (:release -> :ok)
          end,
          server: limiter
        )
      end)

    assert_receive :holding

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:requested, conn.host})

      conn
      |> put_resp_header("location", @actor)
      |> send_resp(301, "")
    end)

    assert {:error, :busy} = Client.get_object("https://old.example/users/ana", key)
    assert_received {:requested, "old.example"}
    refute_received {:requested, _host}

    send(holder.pid, :release)
    assert :ok = Task.await(holder)
  end
end
