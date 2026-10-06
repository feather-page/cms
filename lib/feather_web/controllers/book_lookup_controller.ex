defmodule FeatherWeb.BookLookupController do
  @moduledoc """
  `GET /sites/:site_id/books/lookup?q=` for the Editor.js book block: the
  site's books as JSON (`public_id`, `title`, `author`, `cover_url`,
  `emoji`), see `Feather.Books.lookup_books/2`.
  """
  use FeatherWeb, :controller

  alias Feather.Books
  alias FeatherWeb.SiteComponents

  def index(conn, params) do
    scope = conn.assigns.current_scope

    books =
      scope
      |> Books.lookup_books(params["q"])
      |> Enum.map(fn book ->
        %{
          public_id: book.public_id,
          title: book.title,
          author: book.author,
          cover_url: SiteComponents.image_path(scope.site, book.cover_image, "mobile_x1.webp"),
          emoji: book.emoji
        }
      end)

    json(conn, books)
  end
end
