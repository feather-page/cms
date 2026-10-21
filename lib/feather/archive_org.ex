defmodule Feather.ArchiveOrg do
  @moduledoc """
  Asks archive.org's Save Page Now 2 to save a page into the Wayback
  Machine (ADR 0027), with a site's archive.org keys
  (`Feather.Sites.archive_org_keys/1`, created at
  https://archive.org/account/s3.php).

  The request only queues the capture; archive.org saves the page later.
  Tests stub the requests with `Req.Test` (`config :feather,
  :archive_org_req_options, plug: {Req.Test, Feather.ArchiveOrg}`).
  """

  @endpoint "https://web.archive.org/save"

  @doc "Asks archive.org to save the page at `url`."
  @spec save(String.t(), %{access_key: String.t(), secret_key: String.t()}) ::
          :ok | {:error, term()}
  def save(url, %{access_key: access_key, secret_key: secret_key}) when is_binary(url) do
    headers = [accept: "application/json", authorization: "LOW #{access_key}:#{secret_key}"]

    case Req.post(req(), form: [url: url], headers: headers) do
      {:ok, %Req.Response{status: 200, body: %{"job_id" => job_id}}} when is_binary(job_id) ->
        :ok

      {:ok, %Req.Response{status: status, body: %{"message" => message}}} ->
        {:error, {:status, status, message}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:status, status}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp req do
    [url: @endpoint, retry: false]
    |> Req.new()
    |> Req.merge(Application.get_env(:feather, :archive_org_req_options, []))
  end
end
