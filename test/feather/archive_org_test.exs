defmodule Feather.ArchiveOrgTest do
  use ExUnit.Case, async: true

  alias Feather.ArchiveOrg

  @keys %{access_key: "ak", secret_key: "sk"}

  test "asks Save Page Now 2 to save the URL with the keys" do
    test = self()

    Req.Test.stub(ArchiveOrg, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      send(test, {
        :request,
        conn.method,
        conn.host,
        conn.request_path,
        Plug.Conn.get_req_header(conn, "authorization"),
        Plug.Conn.get_req_header(conn, "accept"),
        URI.decode_query(body)
      })

      Req.Test.json(conn, %{"url" => "https://example.com/", "job_id" => "spn2-1"})
    end)

    assert ArchiveOrg.save("https://example.com/", @keys) == :ok

    assert_received {:request, "POST", "web.archive.org", "/save", ["LOW ak:sk"],
                     ["application/json"], %{"url" => "https://example.com/"}}
  end

  test "returns archive.org's message when it refuses" do
    Req.Test.stub(ArchiveOrg, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => "error", "message" => "Too many captures"})
    end)

    assert ArchiveOrg.save("https://example.com/", @keys) ==
             {:error, {:status, 429, "Too many captures"}}

    Req.Test.stub(ArchiveOrg, &Plug.Conn.send_resp(&1, 502, "Bad gateway"))
    assert ArchiveOrg.save("https://example.com/", @keys) == {:error, {:status, 502}}
  end
end
