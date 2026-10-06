defmodule Feather.Pagination do
  @moduledoc """
  Offset pagination for admin listings (the Rails admin used Pagy with 20
  items per page).
  """

  import Ecto.Query, warn: false

  alias Feather.Repo

  @default_per_page 20

  defstruct entries: [], page: 1, per_page: @default_per_page, total_entries: 0, total_pages: 1

  @type t :: %__MODULE__{
          entries: list(),
          page: pos_integer(),
          per_page: pos_integer(),
          total_entries: non_neg_integer(),
          total_pages: pos_integer()
        }

  @doc "The number of items per page unless given."
  @spec default_per_page() :: pos_integer()
  def default_per_page, do: @default_per_page

  @doc """
  Loads one page of the query. Pages are 1-based; a page beyond the last one
  is clamped to the last page. `page` may be a string (from params).
  """
  @spec paginate(Ecto.Queryable.t(), pos_integer() | String.t() | nil, pos_integer()) :: t()
  def paginate(query, page, per_page \\ @default_per_page) do
    total_entries = Repo.aggregate(exclude(query, :preload), :count)
    total_pages = max(div(total_entries + per_page - 1, per_page), 1)
    page = page |> to_page() |> min(total_pages)

    entries =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %__MODULE__{
      entries: entries,
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp to_page(page) when is_integer(page) and page > 0, do: page

  defp to_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp to_page(_page), do: 1
end
