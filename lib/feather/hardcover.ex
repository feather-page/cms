defmodule Feather.Hardcover do
  @moduledoc """
  A small client for Hardcover's GraphQL book search, which the book search
  (`Feather.Books.search_books/2`) asks when a token is configured
  (ADR 0023).

  The token comes from `config :feather, :hardcover_token`
  (`HARDCOVER_TOKEN`) and acts as its owner's Hardcover account, so it is
  only sent from the server. Requests time out after 5 seconds. Tests stub
  them with `Req.Test` (`config :feather, :hardcover_req_options, plug:
  {Req.Test, Feather.Hardcover}`).
  """

  require Logger

  @base_url "https://api.hardcover.app"
  @timeout 5_000
  @min_query_length 3
  @per_page 10

  @search_query """
  query BookSearch($query: String!) {
    search(query: $query, query_type: "Book", per_page: #{@per_page}, page: 1) { results }
  }
  """

  @type result :: %{
          title: String.t() | nil,
          author: String.t() | nil,
          isbn: String.t() | nil,
          cover_url: String.t() | nil
        }

  @doc "Returns true if a token is configured."
  @spec configured?() :: boolean()
  def configured?, do: token() not in [nil, ""]

  @doc """
  Searches books by title or author. Queries shorter than 3 characters
  return no results without asking Hardcover.
  """
  @spec search(String.t() | nil) :: {:ok, [result()]} | {:error, String.t()}
  def search(query) do
    query = if is_binary(query), do: String.trim(query), else: ""

    cond do
      String.length(query) < @min_query_length -> {:ok, []}
      not configured?() -> {:error, "Hardcover is not configured"}
      true -> search_books(query)
    end
  end

  defp search_books(query) do
    body = %{query: @search_query, variables: %{query: query}}

    case Req.post(req(), url: "/v1/graphql", json: body) do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{"data" => %{"search" => %{"results" => %{"hits" => hits}}}}
       }}
      when is_list(hits) ->
        {:ok, for(%{"document" => %{} = document} <- hits, do: to_result(document))}

      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.warning("Hardcover search failed: #{inspect(body)}")
        {:error, "Hardcover search failed"}

      {:ok, %Req.Response{status: 401}} ->
        Logger.warning("Hardcover search failed: invalid or expired token")
        {:error, "Hardcover token is invalid or expired"}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Hardcover search failed with status #{status}")
        {:error, "Hardcover search failed (status #{status})"}

      {:error, exception} ->
        Logger.warning("Hardcover search failed: #{Exception.message(exception)}")
        {:error, "Hardcover search failed"}
    end
  end

  defp to_result(document) do
    %{
      title: document["title"],
      author: document["author_names"] |> List.wrap() |> List.first(),
      isbn: document["isbns"] |> List.wrap() |> Enum.find(&isbn13?/1),
      cover_url: cover_url(document["image"])
    }
  end

  defp isbn13?(isbn), do: is_binary(isbn) and String.length(isbn) == 13

  defp cover_url(%{"url" => url}) when is_binary(url), do: url
  defp cover_url(_image), do: nil

  defp req do
    [
      base_url: @base_url,
      auth: {:bearer, String.replace_prefix(token(), "Bearer ", "")},
      receive_timeout: @timeout,
      connect_options: [timeout: @timeout],
      retry: false
    ]
    |> Req.new()
    |> Req.merge(Application.get_env(:feather, :hardcover_req_options, []))
  end

  defp token, do: Application.get_env(:feather, :hardcover_token)
end
