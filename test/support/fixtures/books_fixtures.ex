defmodule Feather.BooksFixtures do
  @moduledoc """
  Test helpers for books. All take a scope with a site.
  """

  def book_fixture(scope, attrs \\ %{}) do
    {:ok, book} =
      Feather.Books.create_book(
        scope,
        Enum.into(attrs, %{title: "The Pragmatic Programmer", author: "Andrew Hunt"})
      )

    book
  end
end
