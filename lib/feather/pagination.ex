defmodule Feather.Pagination do
  @moduledoc """
  Offset pagination for the admin listings (the Rails admin used Pagy with
  20 items per page) and the content API.

  A page beyond the last one is clamped to the last page by default (the
  admin); `out_of_range: :empty` returns it empty with the requested page
  number instead (the content API, which documents that behaviour).
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
  Loads one page of the query. Pages are 1-based; `page` may be a string
  (from params), anything that is not a positive integer is page 1.

  Options: `per_page` (default 20) and `out_of_range` (`:clamp`, the
  default, or `:empty`).
  """
  @spec paginate(Ecto.Queryable.t(), pos_integer() | String.t() | nil, keyword()) :: t()
  def paginate(query, page, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, @default_per_page)
    total_entries = Repo.aggregate(exclude(query, :preload), :count)
    total_pages = max(div(total_entries + per_page - 1, per_page), 1)

    page =
      case Keyword.get(opts, :out_of_range, :clamp) do
        :clamp -> page |> to_page() |> min(total_pages)
        :empty -> to_page(page)
      end

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
