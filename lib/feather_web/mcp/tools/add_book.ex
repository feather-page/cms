defmodule FeatherWeb.MCP.Tools.AddBook do
  @moduledoc """
  The tool `add_book`: puts a book on the site's bookshelf, with the cover
  downloaded from a URL.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Books
  alias FeatherWeb.MCP.{BookFields, Tool}

  @impl true
  def definition do
    %{
      name: "add_book",
      title: "Add book",
      description:
        "Puts a book on the site's bookshelf, such as a search_books result with its " <>
          "cover_url. A book is finished unless reading_status says otherwise, and a " <>
          "finished book without read_at was read today. If the cover cannot be downloaded, " <>
          "the book is added without one and cover_error says why. The bookshelf on the " <>
          "live site changes with the next deploy_site.",
      inputSchema: Tool.input_schema(BookFields.properties(), ["site", "title", "author"]),
      annotations: %{readOnlyHint: false, destructiveHint: false, idempotentHint: false}
    }
  end

  @impl true
  def call(scope, %{"site" => domain} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      case Books.create_book(scope, BookFields.attrs(arguments)) do
        {:ok, book} -> {:ok, BookFields.with_cover(scope, book, arguments["cover_url"])}
        {:error, changeset} -> {:error, "Invalid book: " <> Tool.errors(changeset)}
      end
    end
  end
end
