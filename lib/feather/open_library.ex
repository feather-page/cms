defmodule Feather.OpenLibrary do
  @moduledoc """
  A small client for the OpenLibrary search API (port of Rails'
  `OpenLibrary::Client`), used by the admin's book form.

  Requests time out after 5 seconds. Tests stub them with `Req.Test`
  (`config :feather, :open_library_req_options, plug: {Req.Test,
  Feather.OpenLibrary}`).
  """

  require Logger

  @base_url "https://openlibrary.org"
  @covers_url "https://covers.openlibrary.org"
  @timeout 5_000
  @min_query_length 3

  @type result :: %{
          title: String.t() | nil,
          author: String.t() | nil,
          isbn: String.t() | nil,
          key: String.t() | nil,
          cover_url: String.t() | nil
        }

  @doc """
  Searches books by title or author. Queries shorter than 3 characters
  return no results without asking OpenLibrary.
  """
  @spec search(String.t() | nil, keyword()) :: {:ok, [result()]} | {:error, String.t()}
  def search(query, opts \\ []) do
    query = if is_binary(query), do: String.trim(query), else: ""

    if String.length(query) < @min_query_length do
      {:ok, []}
    else
      params = [q: query, limit: Keyword.get(opts, :limit, 10)]

      case Req.get(req(), url: "/search.json", params: params) do
        {:ok, %Req.Response{status: 200, body: %{"docs" => docs}}} when is_list(docs) ->
          {:ok, Enum.map(docs, &to_result/1)}

        {:ok, %Req.Response{status: status}} ->
          Logger.warning("OpenLibrary search failed with status #{status}")
          {:error, "OpenLibrary search failed (status #{status})"}

        {:error, exception} ->
          Logger.warning("OpenLibrary search failed: #{Exception.message(exception)}")
          {:error, "OpenLibrary search failed"}
      end
    end
  end

  defp to_result(doc) do
    %{
      title: doc["title"],
      author: doc["author_name"] |> List.wrap() |> List.first(),
      isbn: doc["isbn"] |> List.wrap() |> List.first(),
      key: doc["key"],
      cover_url: cover_url(doc["cover_i"])
    }
  end

  defp cover_url(nil), do: nil
  defp cover_url(cover_id), do: "#{@covers_url}/b/id/#{cover_id}-M.jpg"

  defp req do
    Req.new(
      base_url: @base_url,
      receive_timeout: @timeout,
      connect_options: [timeout: @timeout],
      retry: false
    )
    |> Req.merge(Application.get_env(:feather, :open_library_req_options, []))
  end
end
