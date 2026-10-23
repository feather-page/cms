defmodule FeatherWeb.MCP.Tools.ListBooks do
  @moduledoc """
  The tool `list_books`: the books on the site's bookshelf, optionally
  with one reading status.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Books
  alias Feather.Books.Book
  alias FeatherWeb.MCP.{BookFields, Tool}

  @impl true
  def definition do
    %{
      name: "list_books",
      title: "List books",
      description:
        "Lists the books on the site's bookshelf, most recently read first, with their id " <>
          "for update_book.",
      inputSchema:
        Tool.input_schema(
          %{
            "reading_status" => %{
              "type" => "string",
              "enum" => Book.reading_statuses(),
              "description" => "Lists only the books with this reading status"
            }
          },
          ["site"]
        ),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      books = Books.list_books(scope, status: arguments["reading_status"])
      {:ok, %{books: Enum.map(books, &BookFields.result/1)}}
    end
  end
end
