defmodule Feather.Fediverse.Signature do
  @moduledoc """
  The HTTP signature of a request to an inbox, as fediverse servers sign
  them (draft-cavage-http-signatures-12, the counterpart of
  `Feather.Fediverse.SigningKey`).

  `check/3` reads the `signature` header and checks everything but the
  signature itself:

    * the signed headers include `(request-target)`, `host`, `date` and,
      for a POST, `digest`;
    * `date` lies within 12 hours of now;
    * `host` is the CMS's public host;
    * for a POST, `digest` holds the SHA-256 of the raw body.

  `verified?/2` then checks the signature against a public key. The
  algorithm follows from the key, never from the header: an RSA key
  verifies `rsa-sha256`, other keys verify nothing.
  """

  alias Feather.Fediverse.SigningKey

  @enforce_keys [:key_id, :signing_string, :signature]
  defstruct [:key_id, :signing_string, :signature]

  @type t :: %__MODULE__{key_id: String.t(), signing_string: String.t(), signature: binary()}

  @type request :: %{
          method: String.t(),
          path: String.t(),
          query: String.t(),
          headers: [{String.t(), String.t()}],
          body: binary()
        }

  @max_skew_seconds 12 * 3600
  @months %{
    "Jan" => "01",
    "Feb" => "02",
    "Mar" => "03",
    "Apr" => "04",
    "May" => "05",
    "Jun" => "06",
    "Jul" => "07",
    "Aug" => "08",
    "Sep" => "09",
    "Oct" => "10",
    "Nov" => "11",
    "Dec" => "12"
  }
  @http_date ~r/\A[A-Z][a-z]{2}, (?<day>\d{2}) (?<month>[A-Z][a-z]{2}) (?<year>\d{4}) (?<time>\d{2}:\d{2}:\d{2}) GMT\z/

  @doc """
  Reads the signature of `request` and checks the headers it signs (see
  the module doc) against `public_host` (`host` or `host:port`) and `now`.
  """
  @spec check(request(), String.t(), DateTime.t()) :: {:ok, t()} | {:error, atom()}
  def check(request, public_host, now \\ DateTime.utc_now()) do
    with {:ok, params} <- parse(header(request, "signature")),
         :ok <- check_signed(params.headers, request.method),
         {:ok, signing_string} <- signing_string(params.headers, request),
         :ok <- check_date(header(request, "date"), now),
         :ok <- check_host(header(request, "host"), public_host),
         :ok <- check_digest(request) do
      {:ok,
       %__MODULE__{
         key_id: params.key_id,
         signing_string: signing_string,
         signature: params.signature
       }}
    end
  end

  @doc "Returns true if the signature is valid for the public key (PEM)."
  @spec verified?(t(), String.t()) :: boolean()
  def verified?(%__MODULE__{} = signature, public_key_pem) when is_binary(public_key_pem) do
    case :public_key.pem_decode(public_key_pem) do
      [entry] -> verify(signature, :public_key.pem_entry_decode(entry))
      _none_or_several -> false
    end
  rescue
    _malformed -> false
  end

  defp verify(signature, {:RSAPublicKey, _modulus, _exponent} = key),
    do: :public_key.verify(signature.signing_string, :sha256, signature.signature, key)

  defp verify(_signature, _key), do: false

  defp header(request, name) do
    case for({^name, value} <- request.headers, do: value) do
      [] -> nil
      values -> Enum.join(values, ", ")
    end
  end

  defp parse(nil), do: {:error, :unsigned}

  defp parse(header) do
    params =
      ~r/(\w+)="([^"]*)"/
      |> Regex.scan(header)
      |> Map.new(fn [_param, name, value] -> {name, value} end)

    with %{"keyId" => key_id, "signature" => signature} <- params,
         {:ok, signature} <- Base.decode64(signature) do
      headers = params |> Map.get("headers", "date") |> String.downcase() |> String.split()
      {:ok, %{key_id: key_id, signature: signature, headers: headers}}
    else
      _malformed -> {:error, :malformed_signature}
    end
  end

  defp check_signed(headers, method) do
    required = ["(request-target)", "host", "date" | List.wrap(if method == "POST", do: "digest")]
    if Enum.all?(required, &(&1 in headers)), do: :ok, else: {:error, :unsigned_headers}
  end

  defp signing_string(headers, request) do
    lines = Enum.map(headers, &{&1, signed_value(&1, request)})

    if Enum.any?(lines, fn {_name, value} -> is_nil(value) end),
      do: {:error, :missing_header},
      else: {:ok, SigningKey.signing_string(lines)}
  end

  defp signed_value("(request-target)", %{method: method, path: path, query: query}) do
    target = if query in [nil, ""], do: path, else: path <> "?" <> query
    String.downcase(method) <> " " <> target
  end

  defp signed_value(name, request), do: header(request, name)

  defp check_date(date, now) do
    case parse_http_date(date) do
      {:ok, date} ->
        if abs(DateTime.diff(now, date)) <= @max_skew_seconds, do: :ok, else: {:error, :stale}

      :error ->
        {:error, :stale}
    end
  end

  defp parse_http_date(date) when is_binary(date) do
    with %{"day" => day, "month" => month, "year" => year, "time" => time} <-
           Regex.named_captures(@http_date, date),
         {:ok, month} <- Map.fetch(@months, month),
         {:ok, datetime, 0} <- DateTime.from_iso8601("#{year}-#{month}-#{day}T#{time}Z") do
      {:ok, datetime}
    else
      _malformed -> :error
    end
  end

  defp parse_http_date(_date), do: :error

  defp check_host(host, public_host) when is_binary(host) do
    if String.downcase(host) == String.downcase(public_host),
      do: :ok,
      else: {:error, :wrong_host}
  end

  defp check_host(nil, _public_host), do: {:error, :wrong_host}

  defp check_digest(%{method: "POST", body: body} = request) do
    expected = Base.encode64(:crypto.hash(:sha256, body))

    if Enum.any?(digests(header(request, "digest")), &Plug.Crypto.secure_compare(&1, expected)),
      do: :ok,
      else: {:error, :digest}
  end

  defp check_digest(_request), do: :ok

  defp digests(nil), do: []

  defp digests(header) do
    for entry <- String.split(header, ","),
        [algorithm, value] <- [entry |> String.trim() |> String.split("=", parts: 2)],
        String.downcase(algorithm) == "sha-256",
        do: value
  end
end
