defmodule Feather.Fediverse.SigningKeyTest do
  use Feather.DataCase

  alias Feather.Fediverse.SigningKey

  @now ~U[2026-10-23 08:05:09.123456Z]

  defp public_key(%SigningKey{private_key: private_key}),
    do: {:RSAPublicKey, elem(private_key, 2), elem(private_key, 3)}

  defp signature_params(headers) do
    {"signature", signature} = List.keyfind(headers, "signature", 0)

    ~r/(\w+)="([^"]*)"/
    |> Regex.scan(signature)
    |> Map.new(fn [_all, name, value] -> {name, value} end)
  end

  test "the site signs with its private key under its account's key id" do
    site = fediverse_site_fixture(%{domain: "timon.blog"})
    key = SigningKey.for_site(site)

    assert key.key_id == "https://timon.blog/activitypub/timon#main-key"
    signature = :public_key.sign("hello", :sha256, key.private_key)
    [entry] = :public_key.pem_decode(site.fediverse_public_key)
    assert :public_key.verify("hello", :sha256, signature, :public_key.pem_entry_decode(entry))
    refute inspect(key) =~ "RSAPrivateKey"
  end

  test "signs (request-target), host, date and digest of a POST" do
    key = SigningKey.for_site(fediverse_site_fixture())
    body = ~s({"type":"Follow"})
    uri = URI.parse("https://mastodon.example/users/ana/inbox?x=1")

    headers = SigningKey.sign(key, :post, uri, body, @now)
    digest = "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, body))

    assert {"host", "mastodon.example"} in headers
    assert {"date", "Fri, 23 Oct 2026 08:05:09 GMT"} in headers
    assert {"digest", digest} in headers

    params = signature_params(headers)
    assert params["keyId"] == key.key_id
    assert params["algorithm"] == "rsa-sha256"
    assert params["headers"] == "(request-target) host date digest"

    signing_string =
      "(request-target): post /users/ana/inbox?x=1\n" <>
        "host: mastodon.example\n" <>
        "date: Fri, 23 Oct 2026 08:05:09 GMT\n" <>
        "digest: " <> digest

    assert :public_key.verify(
             signing_string,
             :sha256,
             Base.decode64!(params["signature"]),
             public_key(key)
           )
  end

  test "signs a GET without a digest" do
    key = SigningKey.for_site(fediverse_site_fixture())
    headers = SigningKey.sign(key, :get, URI.parse("https://mastodon.example"), nil, @now)

    refute List.keymember?(headers, "digest", 0)
    params = signature_params(headers)
    assert params["headers"] == "(request-target) host date"

    assert :public_key.verify(
             "(request-target): get /\nhost: mastodon.example\ndate: Fri, 23 Oct 2026 08:05:09 GMT",
             :sha256,
             Base.decode64!(params["signature"]),
             public_key(key)
           )
  end
end
