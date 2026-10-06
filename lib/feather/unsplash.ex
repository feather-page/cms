defmodule Feather.Unsplash do
  @moduledoc """
  A small client for the Unsplash API (port of Rails' `Unsplash::Client`),
  used by the admin's header image picker.

  The access key comes from `config :feather, :unsplash_access_key`
  (`UNSPLASH_ACCESS_KEY`); without one the search is disabled. Requests
  time out after 5 seconds. Tests stub them with `Req.Test` (`config
  :feather, :unsplash_req_options, plug: {Req.Test, Feather.Unsplash}`).
  """

  require Logger

  @base_url "https://api.unsplash.com"
  @timeout 5_000
  @min_query_length 2

  @type photo :: %{
          id: String.t(),
          description: String.t() | nil,
          thumbnail_url: String.t(),
          full_url: String.t(),
          photographer_name: String.t() | nil,
          photographer_url: String.t() | nil,
          download_location: String.t() | nil
        }

  @doc "Returns true if an access key is configured."
  @spec configured?() :: boolean()
  def configured?, do: access_key() not in [nil, ""]

  @doc """
  Searches photos. Queries shorter than 2 characters return no results
  without asking Unsplash.
  """
  @spec search(String.t() | nil, keyword()) :: {:ok, [photo()]} | {:error, String.t()}
  def search(query, opts \\ []) do
    query = if is_binary(query), do: String.trim(query), else: ""

    cond do
      String.length(query) < @min_query_length ->
        {:ok, []}

      not configured?() ->
        {:error, "Unsplash is not configured"}

      true ->
        params = [
          query: query,
          page: Keyword.get(opts, :page, 1),
          per_page: Keyword.get(opts, :per_page, 12)
        ]

        case Req.get(req(), url: "/search/photos", params: params) do
          {:ok, %Req.Response{status: 200, body: %{"results" => results}}}
          when is_list(results) ->
            {:ok, Enum.map(results, &to_photo/1)}

          {:ok, %Req.Response{status: status}} ->
            Logger.warning("Unsplash search failed with status #{status}")
            {:error, "Unsplash search failed (status #{status})"}

          {:error, exception} ->
            Logger.warning("Unsplash search failed: #{Exception.message(exception)}")
            {:error, "Unsplash search failed"}
        end
    end
  end

  @doc """
  The attribution stored with an image taken from Unsplash
  (`images.unsplash_data`).
  """
  @spec unsplash_data(photo()) :: map()
  def unsplash_data(photo) do
    %{
      "photographer_name" => photo.photographer_name,
      "photographer_url" => photo.photographer_url,
      "download_location" => photo.download_location
    }
  end

  defp to_photo(data) do
    urls = data["urls"] || %{}
    user = data["user"] || %{}

    %{
      id: data["id"],
      description: data["description"] || data["alt_description"],
      thumbnail_url: urls["thumb"],
      full_url: urls["regular"],
      photographer_name: user["name"],
      photographer_url: get_in(user, ["links", "html"]),
      download_location: get_in(data, ["links", "download_location"])
    }
  end

  defp req do
    Req.new(
      base_url: @base_url,
      headers: [
        {"authorization", "Client-ID #{access_key()}"},
        {"accept-version", "v1"}
      ],
      receive_timeout: @timeout,
      connect_options: [timeout: @timeout],
      retry: false
    )
    |> Req.merge(Application.get_env(:feather, :unsplash_req_options, []))
  end

  defp access_key, do: Application.get_env(:feather, :unsplash_access_key)
end
