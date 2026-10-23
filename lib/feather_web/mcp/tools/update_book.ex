defmodule FeatherWeb.MCP.Tools.UpdateBook do
  @moduledoc """
  The tool `update_book`: changes the fields of a book that `add_book`
  sets, the cover too.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Books
  alias FeatherWeb.MCP.{BookFields, Tool}

  @impl true
  def definition do
    %{
      name: "update_book",
      title: "Update book",
      description:
        "Changes a book on the site's bookshelf: only the fields given. null clears isbn, " <>
          "emoji, rating or read_at, and a finished book without read_at was read today. " <>
          "cover_url replaces the cover as in add_book. The bookshelf on the live site " <>
          "changes with the next deploy_site.",
      inputSchema:
        Tool.input_schema(
          Map.put(BookFields.properties(), "book", %{
            "type" => "string",
            "description" => "The book's id from list_books"
          }),
          ["site", "book"]
        ),
      annotations: %{readOnlyHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "book" => id} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, book} <- BookFields.fetch_book(scope, id) do
      case Books.update_book(scope, book, BookFields.attrs(arguments)) do
        {:ok, book} -> {:ok, BookFields.with_cover(scope, book, arguments["cover_url"])}
        {:error, changeset} -> {:error, "Invalid book: " <> Tool.errors(changeset)}
      end
    end
  end
end
