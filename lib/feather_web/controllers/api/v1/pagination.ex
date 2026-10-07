defmodule FeatherWeb.Api.V1.Pagination do
  @moduledoc """
  The `?p=` page parameter of the content API's list endpoints and the
  `meta` object of their responses.
  """

  @doc """
  The requested page: the integer in `"p"`, 1 when it is missing or not a
  positive integer.
  """
  @spec page(map()) :: pos_integer()
  def page(params) do
    with p when is_binary(p) <- Map.get(params, "p"),
         {page, ""} when page >= 1 <- Integer.parse(p) do
      page
    else
      _ -> 1
    end
  end

  @doc """
  The `meta` object of a list response: `page`, `pages` (at least 1) and
  the total `count`.
  """
  @spec meta(Feather.Pagination.t()) :: map()
  def meta(%Feather.Pagination{page: page, total_pages: pages, total_entries: count}),
    do: %{page: page, pages: pages, count: count}
end
