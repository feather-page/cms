defmodule FeatherWeb.MCP.BookFields do
  @moduledoc """
  The fields of a book in the book tools: their input schema, the
  attributes they set and a book as a tool result.
  """

  alias Feather.Accounts.Scope
  alias Feather.Books
  alias Feather.Books.Book
  alias FeatherWeb.MCP.Tool

  @fields ~w(title author isbn emoji reading_status rating read_at)

  @doc "The input schema properties of the book's fields and of `cover_url`."
  @spec properties() :: map()
  def properties do
    %{
      "title" => %{"type" => "string"},
      "author" => %{"type" => "string"},
      "isbn" => %{"type" => ["string", "null"], "description" => "The ISBN-13"},
      "emoji" => %{
        "type" => ["string", "null"],
        "description" => "An emoji the bookshelf shows while the book has no cover"
      },
      "reading_status" => %{"type" => "string", "enum" => Book.reading_statuses()},
      "rating" => %{
        "type" => ["integer", "null"],
        "minimum" => 1,
        "maximum" => 5,
        "description" => "Stars from 1 to 5"
      },
      "read_at" => %{
        "type" => ["string", "null"],
        "format" => "date",
        "description" => "When the book was finished, as YYYY-MM-DD"
      },
      "cover_url" => %{
        "type" => "string",
        "format" => "uri",
        "description" =>
          "The URL of a cover image, such as a search_books result's cover_url. " <>
            "The CMS downloads it as the book's cover."
      }
    }
  end

  @doc "The book's attributes among the arguments, without `cover_url`."
  @spec attrs(map()) :: map()
  def attrs(arguments), do: Map.take(arguments, @fields)

  @doc """
  The result of a saved book, after downloading its cover from
  `cover_url` if one is given. A failed download leaves the book as saved
  and says why in `cover_error`.
  """
  @spec with_cover(Scope.t(), Book.t(), String.t() | nil) :: map()
  def with_cover(%Scope{}, %Book{} = book, nil), do: result(book)

  def with_cover(%Scope{} = scope, %Book{} = book, cover_url) do
    case Books.attach_cover_from_url(scope, book, cover_url) do
      {:ok, book} ->
        result(book)

      {:error, reason} ->
        Map.put(
          result(book),
          :cover_error,
          "The cover could not be downloaded: #{message(reason)}"
        )
    end
  end

  defp message(%Ecto.Changeset{} = changeset), do: Tool.errors(changeset)
  defp message(message) when is_binary(message), do: message

  @doc "A book as a tool result; `id` is its public id."
  @spec result(Book.t()) :: map()
  def result(%Book{} = book) do
    %{
      id: book.public_id,
      title: book.title,
      author: book.author,
      isbn: book.isbn,
      emoji: book.emoji,
      reading_status: book.reading_status,
      rating: book.rating,
      read_at: book.read_at,
      has_cover: book.cover_image_id != nil
    }
  end
end
