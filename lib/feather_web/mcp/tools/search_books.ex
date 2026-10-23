defmodule FeatherWeb.MCP.Tools.SearchBooks do
  @moduledoc """
  The tool `search_books`: the book search of the book form
  (`Feather.Books.search_books/2`).
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Books
  alias FeatherWeb.MCP.Tool

  @impl true
  def definition do
    %{
      name: "search_books",
      title: "Search books",
      description:
        "Searches a book database by title or author (at least 3 characters) and gives " <>
          "title, author, ISBN and cover URL of up to 10 books. add_book puts one on a " <>
          "site's bookshelf with its cover.",
      inputSchema:
        Tool.input_schema(
          %{"query" => %{"type" => "string", "description" => "Title or author"}},
          ["query"]
        ),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"query" => query}) do
    with {:ok, books} <- Books.search_books(scope, query), do: {:ok, %{books: books}}
  end
end
