defmodule Feather.IndexNowTest do
  use ExUnit.Case, async: true

  alias Feather.IndexNow

  test "posts the URLs with the host, key and key location as JSON" do
    test = self()

    Req.Test.stub(IndexNow, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:request, conn.method, conn.host, conn.request_path, Jason.decode!(body)})
      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert IndexNow.submit("example.com", "abc", ["https://example.com/"]) == :ok

    assert_received {:request, "POST", "api.indexnow.org", "/indexnow", body}

    assert body == %{
             "host" => "example.com",
             "key" => "abc",
             "keyLocation" => "https://example.com/abc.txt",
             "urlList" => ["https://example.com/"]
           }
  end

  test "sends at most 10,000 URLs per request" do
    test = self()

    Req.Test.stub(IndexNow, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:batch, length(Jason.decode!(body)["urlList"])})
      Plug.Conn.send_resp(conn, 200, "")
    end)

    urls = for i <- 1..10_001, do: "https://example.com/#{i}/"
    assert IndexNow.submit("example.com", "abc", urls) == :ok

    assert_received {:batch, 10_000}
    assert_received {:batch, 1}
  end

  test "returns the status of a refused request and transport errors" do
    Req.Test.stub(IndexNow, &Plug.Conn.send_resp(&1, 403, ""))

    assert IndexNow.submit("example.com", "abc", ["https://example.com/"]) ==
             {:error, {:status, 403}}

    Req.Test.stub(IndexNow, &Req.Test.transport_error(&1, :timeout))

    assert {:error, %Req.TransportError{reason: :timeout}} =
             IndexNow.submit("example.com", "abc", ["https://example.com/"])
  end
end
