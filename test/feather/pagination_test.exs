defmodule Feather.PaginationTest do
  use Feather.DataCase

  alias Feather.Content.Post
  alias Feather.Pagination

  setup do
    scope = site_scope_fixture()
    for n <- 1..5, do: post_fixture(scope, title: "Post #{n}")
    %{query: from(p in Post, where: p.site_id == ^scope.site.id, order_by: p.title)}
  end

  test "pages through a query", %{query: query} do
    assert %Pagination{entries: [_, _], page: 1, total_pages: 3, total_entries: 5} =
             Pagination.paginate(query, 1, per_page: 2)

    assert %Pagination{entries: [_], page: 3} = Pagination.paginate(query, "3", per_page: 2)
  end

  test "clamps a page beyond the last one by default", %{query: query} do
    assert %Pagination{entries: [_], page: 3} = Pagination.paginate(query, 9, per_page: 2)
  end

  test "out_of_range: :empty returns an empty page instead", %{query: query} do
    assert %Pagination{entries: [], page: 9, total_pages: 3, total_entries: 5} =
             Pagination.paginate(query, "9", per_page: 2, out_of_range: :empty)
  end

  test "anything but a positive integer is page 1", %{query: query} do
    for page <- [nil, "0", "-1", "abc", 0] do
      assert %Pagination{page: 1} = Pagination.paginate(query, page, out_of_range: :empty)
    end
  end
end
