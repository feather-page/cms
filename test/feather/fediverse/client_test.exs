defmodule Feather.Fediverse.ClientTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias Feather.Fediverse.{Client, SigningKey}

  @actor "https://mastodon.example/users/ana"

  setup_all do
    private_key = :public_key.generate_key({:rsa, 2048, 65_537})

    %{
      key: %SigningKey{
        key_id: "https://timon.blog/activitypub/timon#main-key",
        private_key: private_key
      },
      public_key: {:RSAPublicKey, elem(private_key, 2), elem(private_key, 3)}
    }
  end

  # Answers every request: an address that is refused must be refused before it is requested.
  defp serve_everything do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:requested, conn.host, conn.request_path})

      conn
      |> put_resp_content_type("application/activity+json")
      |> send_resp(200, ~s({"id": "#{@actor}"}))
    end)
  end

  defp redirect_to(location) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:requested, conn.host, conn.request_path})

      conn
      |> put_resp_header("location", location)
      |> send_resp(302, "")
    end)
  end

  defp private_addresses(path) do
    [
      "https://127.0.0.1.nip.io" <> path,
      "https://10.0.0.1.nip.io" <> path,
      "https://169.254.169.254.nip.io" <> path,
      "https://[::1]" <> path,
      "https://127.0.0.1" <> path,
      "https://localhost" <> path,
      "https://private-and-public.example" <> path
    ]
  end

  describe "addresses that resolve to private or loopback addresses" do
    test "are refused for actors and keys", %{key: key} do
      serve_everything()

      for url <- private_addresses("/users/ana") ++ private_addresses("/users/ana#main-key") do
        assert {:error, _reason} = Client.get_object(url, key), url
      end

      refute_received {:requested, _host, _path}
    end

    test "are refused for inboxes", %{key: key} do
      serve_everything()

      for url <- private_addresses("/inbox") do
        assert {:error, _reason} = Client.post(url, ~s({"type": "Follow"}), key), url
      end

      refute_received {:requested, _host, _path}
    end

    test "are refused for pictures", %{key: key} do
      serve_everything()

      for url <- private_addresses("/avatar.png") do
        assert {:error, _reason} = Client.get_picture(url, key), url
      end

      refute_received {:requested, _host, _path}
    end

    test "are refused after a redirect", %{key: key} do
      redirect_to("https://127.0.0.1.nip.io/users/ana")

      assert {:error, :forbidden_address} = Client.get_object(@actor, key)
      assert {:error, :forbidden_address} = Client.get_object(@actor <> "#main-key", key)
      assert {:error, :forbidden_address} = Client.get_picture(@actor <> "/avatar.png", key)

      redirect_to("https://localhost/users/ana")
      assert {:error, {:forbidden_redirect, _message}} = Client.get_object(@actor, key)

      for _request <- 1..4, do: assert_received({:requested, "mastodon.example", _path})
      refute_received {:requested, _host, _path}
    end
  end

  test "requests only https on port 443", %{key: key} do
    serve_everything()

    for url <- [
          "http://mastodon.example/users/ana",
          "https://mastodon.example:8443/users/ana",
          "ftp://mastodon.example/users/ana"
        ] do
      assert {:error, {:invalid_url, _message}} = Client.get_object(url, key), url
      assert {:error, {:invalid_url, _message}} = Client.post(url, "{}", key), url
    end

    redirect_to("http://mastodon.example/users/ana")
    assert {:error, {:forbidden_redirect, _message}} = Client.get_object(@actor, key)
  end

  test "follows redirects of GETs, each checked, and reports where it ended", %{key: key} do
    Req.Test.stub(Feather.Fediverse, fn conn ->
      case conn.host do
        "old.example" ->
          conn
          |> put_resp_header("location", @actor)
          |> send_resp(301, "")

        "mastodon.example" ->
          conn
          |> put_resp_content_type("application/activity+json")
          |> send_resp(200, ~s({"id": "#{@actor}"}))
      end
    end)

    assert {:ok, %{"id" => @actor}, %URI{host: "mastodon.example", path: "/users/ana"}} =
             Client.get_object("https://old.example/users/ana", key)
  end

  test "POSTs follow no redirects", %{key: key} do
    redirect_to("https://mastodon.example/inbox")

    assert {:error, _reason} = Client.post("https://old.example/inbox", "{}", key)
    assert_received {:requested, "old.example", "/inbox"}
    refute_received {:requested, _host, _path}
  end

  test "signs GETs and POSTs with the site's key", %{key: key, public_key: public_key} do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      send(test_pid, {:request, conn.method, conn.request_path, conn.req_headers, body})

      conn
      |> put_resp_content_type("application/activity+json")
      |> send_resp(202, ~s({"id": "#{@actor}"}))
    end)

    assert {:ok, _document, _url} = Client.get_object(@actor <> "?page=1", key)
    assert_received {:request, "GET", "/users/ana", headers, ""}
    assert_signed(headers, "get /users/ana?page=1", ~w(host date), public_key)

    body = ~s({"type": "Follow"})
    assert :ok = Client.post("https://mastodon.example/inbox", body, key)
    assert_received {:request, "POST", "/inbox", headers, ^body}

    assert header(headers, "digest") ==
             "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, body))

    assert header(headers, "content-type") == "application/activity+json"
    assert_signed(headers, "post /inbox", ~w(host date digest), public_key)
  end

  defp assert_signed(headers, request_target, signed_headers, public_key) do
    params = signature_params(headers)

    assert params["keyId"] == "https://timon.blog/activitypub/timon#main-key"
    assert params["algorithm"] == "rsa-sha256"
    assert params["headers"] == Enum.join(["(request-target)" | signed_headers], " ")
    assert header(headers, "host") == "mastodon.example"
    assert header(headers, "date") =~ ~r/^\w{3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} GMT$/

    signature = Base.decode64!(params["signature"])
    signing_string = signing_string(headers, request_target, signed_headers)
    assert :public_key.verify(signing_string, :sha256, signature, public_key)
  end

  defp signature_params(headers) do
    ~r/(\w+)="([^"]*)"/
    |> Regex.scan(header(headers, "signature"))
    |> Map.new(fn [_all, name, value] -> {name, value} end)
  end

  defp signing_string(headers, request_target, signed_headers) do
    Enum.map_join(["(request-target)" | signed_headers], "\n", fn
      "(request-target)" -> "(request-target): " <> request_target
      name -> name <> ": " <> header(headers, name)
    end)
  end

  defp header(headers, name) do
    {^name, value} = List.keyfind(headers, name, 0)
    value
  end

  test "accepts only ActivityStreams JSON for objects", %{key: key} do
    Req.Test.stub(Feather.Fediverse, fn conn ->
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, ~s({"id": "#{@actor}"}))
    end)

    assert {:error, {:content_type, "text/html"}} = Client.get_object(@actor, key)

    Req.Test.stub(Feather.Fediverse, fn conn ->
      conn
      |> put_resp_header(
        "content-type",
        ~s(application/ld+json; profile="https://www.w3.org/ns/activitystreams")
      )
      |> send_resp(200, "not json")
    end)

    assert {:error, :invalid_json} = Client.get_object(@actor, key)
  end

  test "reads WebFinger answers as JRD", %{key: key} do
    Req.Test.stub(Feather.Fediverse, fn conn ->
      assert conn.query_string == "resource=acct%3Aana%40mastodon.example"

      conn
      |> put_resp_content_type("application/jrd+json")
      |> send_resp(200, ~s({"subject": "acct:ana@mastodon.example"}))
    end)

    assert {:ok, %{"subject" => "acct:ana@mastodon.example"}} =
             Client.get_webfinger(
               "https://mastodon.example/.well-known/webfinger?resource=acct%3Aana%40mastodon.example",
               key
             )
  end

  test "refuses JSON over 1 MB and pictures over 2 MB", %{key: key} do
    Req.Test.stub(Feather.Fediverse, fn conn ->
      case conn.request_path do
        "/users/ana" ->
          conn
          |> put_resp_content_type("application/activity+json")
          |> send_resp(200, ~s({"name": "#{String.duplicate("a", 1_000_000)}"}))

        "/small.png" ->
          send_resp(conn, 200, :binary.copy(<<0>>, 2_000_000))

        "/big.png" ->
          send_resp(conn, 200, :binary.copy(<<0>>, 2_000_001))
      end
    end)

    assert {:error, :too_large} = Client.get_object(@actor, key)
    assert {:ok, picture} = Client.get_picture("https://mastodon.example/small.png", key)
    assert byte_size(picture) == 2_000_000
    assert {:error, :too_large} = Client.get_picture("https://mastodon.example/big.png", key)
  end

  test "reports the status of a failed request", %{key: key} do
    Req.Test.stub(Feather.Fediverse, &send_resp(&1, 410, "gone"))

    assert {:error, {:status, 410}} = Client.get_object(@actor, key)
    assert {:error, {:status, 410}} = Client.post("https://mastodon.example/inbox", "{}", key)
  end
end
