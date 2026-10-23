defmodule FeatherWeb.MCP.Tools.SearchBooksTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias FeatherWeb.MCP.Tools.SearchBooks

  setup do
    %{scope: Scope.for_user(user_fixture())}
  end

  test "gives title, author, ISBN and cover URL of the books found", %{scope: scope} do
    Req.Test.stub(Feather.OpenLibrary, fn conn ->
      assert conn.query_string =~ "q=dune"

      Req.Test.json(conn, %{
        "docs" => [
          %{
            "title" => "Dune",
            "author_name" => ["Frank Herbert"],
            "isbn" => ["9780441013593"],
            "cover_i" => 1
          }
        ]
      })
    end)

    assert SearchBooks.call(scope, %{"query" => "dune"}) ==
             {:ok,
              %{
                books: [
                  %{
                    title: "Dune",
                    author: "Frank Herbert",
                    isbn: "9780441013593",
                    cover_url: "https://covers.openlibrary.org/b/id/1-M.jpg"
                  }
                ]
              }}
  end

  @tag :capture_log
  test "a failed search is an error", %{scope: scope} do
    Req.Test.stub(Feather.OpenLibrary, &Plug.Conn.send_resp(&1, 500, ""))

    assert SearchBooks.call(scope, %{"query" => "dune"}) ==
             {:error, "OpenLibrary search failed (status 500)"}
  end
end
