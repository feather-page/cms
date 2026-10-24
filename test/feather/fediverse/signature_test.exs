defmodule Feather.Fediverse.SignatureTest do
  use ExUnit.Case, async: true

  import Feather.FediverseFixtures, only: [remote_key_pair: 0]

  alias Feather.Fediverse.Signature

  @now ~U[2026-10-23 08:05:09Z]
  @date "Fri, 23 Oct 2026 08:05:09 GMT"
  @key_id "https://mastodon.example/users/ana#main-key"
  @body ~s({"type":"Follow"})

  setup_all do
    {key, public_key} = remote_key_pair()
    %{key: key, public_key: public_key}
  end

  defp digest(body), do: "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, body))

  defp request(key, opts \\ []) do
    signed = Keyword.get(opts, :signed, ~w[(request-target) host date digest])
    algorithm = Keyword.get(opts, :algorithm, "rsa-sha256")

    headers =
      Keyword.get(opts, :headers, [
        {"host", "cms.example"},
        {"date", @date},
        {"digest", digest(@body)}
      ])

    request = %{
      method: "POST",
      path: "/fediverse/inbox/abc",
      query: "",
      headers: headers,
      body: @body
    }

    lines = for name <- signed, do: "#{name}: #{value(request, name)}"

    signature =
      lines |> Enum.join("\n") |> :public_key.sign(:sha256, key) |> Base.encode64()

    header =
      ~s[keyId="#{@key_id}",algorithm="#{algorithm}",headers="#{Enum.join(signed, " ")}",signature="#{signature}"]

    %{request | headers: [{"signature", header} | headers]}
  end

  defp value(_request, "(request-target)"), do: "post /fediverse/inbox/abc"

  defp value(request, name),
    do:
      request.headers |> Enum.filter(&(elem(&1, 0) == name)) |> Enum.map_join(", ", &elem(&1, 1))

  test "verifies a signature over (request-target), host, date and digest", c do
    assert {:ok, signature} = Signature.check(request(c.key), "cms.example", @now)

    assert signature.key_id == @key_id
    assert Signature.verified?(signature, c.public_key)

    {_other_key, other_public_key} = remote_key_pair()
    refute Signature.verified?(signature, other_public_key)
    refute Signature.verified?(signature, "not a key")
  end

  test "takes the algorithm from the key, not from the header", c do
    request = request(c.key, algorithm: "hmac-sha256")
    assert {:ok, signature} = Signature.check(request, "cms.example", @now)
    assert Signature.verified?(signature, c.public_key)

    ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
    {:ECPrivateKey, _version, _private, parameters, public, _attributes} = ec_key

    pem_entry =
      :public_key.pem_entry_encode(:SubjectPublicKeyInfo, {{:ECPoint, public}, parameters})

    refute Signature.verified?(signature, :public_key.pem_encode([pem_entry]))
  end

  test "requires (request-target), host, date and digest to be signed", c do
    for missing <- ~w[(request-target) host date digest] do
      signed = List.delete(~w[(request-target) host date digest], missing)

      assert {:error, :unsigned_headers} =
               Signature.check(request(c.key, signed: signed), "cms.example", @now)
    end

    assert {:error, :unsigned} =
             Signature.check(%{request(c.key) | headers: []}, "cms.example", @now)
  end

  test "requires a date within 12 hours", c do
    assert {:ok, _signature} =
             Signature.check(request(c.key), "cms.example", DateTime.add(@now, 12, :hour))

    assert {:error, :stale} =
             Signature.check(request(c.key), "cms.example", DateTime.add(@now, 13, :hour))

    assert {:error, :stale} =
             Signature.check(request(c.key), "cms.example", DateTime.add(@now, -13, :hour))
  end

  test "requires the public host and a digest of the body", c do
    assert {:error, :wrong_host} = Signature.check(request(c.key), "other.example", @now)

    headers = [{"host", "cms.example"}, {"date", @date}, {"digest", digest("{}")}]

    assert {:error, :digest} =
             Signature.check(request(c.key, headers: headers), "cms.example", @now)
  end
end
