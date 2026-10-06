defmodule Feather.Books do
  @moduledoc """
  The bookshelf of a site and book reviews.

  A review is a post linked from the book (`book.post_id`). Deleting a
  review deletes the post and clears the rating; deleting a book deletes
  its review post and its cover image.
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Accounts.Scope
  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.Post
  alias Feather.Media
  alias Feather.Sites.Site

  @doc """
  Lists the books of the scope's site, most recently read first. Pass
  `status:` to only list books with that reading status.
  """
  @spec list_books(Scope.t(), keyword()) :: [Book.t()]
  def list_books(%Scope{site: %Site{id: site_id}}, opts \\ []) do
    query =
      from b in Book,
        where: b.site_id == ^site_id,
        order_by: [desc_nulls_last: b.read_at, asc: b.title]

    query =
      case opts[:status] do
        nil -> query
        status -> where(query, [b], b.reading_status == ^to_string(status))
      end

    Repo.all(query)
  end

  @doc "Gets a book of the scope's site by public id. Raises if not found."
  @spec get_book!(Scope.t(), String.t()) :: Book.t()
  def get_book!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from b in Book, where: b.site_id == ^site_id and b.public_id == ^public_id)
  end

  @doc "Gets the book reviewed by a post, or nil."
  @spec get_book_for_post(Scope.t(), Post.t()) :: Book.t() | nil
  def get_book_for_post(%Scope{site: %Site{id: site_id}}, %Post{id: post_id}) do
    Repo.one(from b in Book, where: b.site_id == ^site_id and b.post_id == ^post_id)
  end

  @doc "Creates a book in the scope's site."
  @spec create_book(Scope.t(), map()) :: {:ok, Book.t()} | {:error, Ecto.Changeset.t()}
  def create_book(%Scope{site: %Site{id: site_id}}, attrs) do
    %Book{site_id: site_id}
    |> Book.create_changeset(attrs)
    |> Media.validate_site_images([:cover_image_id])
    |> Repo.insert()
  end

  @doc "Updates a book."
  @spec update_book(Scope.t(), Book.t(), map()) :: {:ok, Book.t()} | {:error, Ecto.Changeset.t()}
  def update_book(%Scope{site: %Site{id: site_id}}, %Book{site_id: site_id} = book, attrs) do
    book
    |> Book.changeset(attrs)
    |> Media.validate_site_images([:cover_image_id])
    |> Repo.update()
  end

  @doc "Deletes a book, its review post and its cover image."
  @spec delete_book(Scope.t(), Book.t()) :: {:ok, Book.t()} | {:error, Ecto.Changeset.t()}
  def delete_book(%Scope{site: %Site{id: site_id}} = scope, %Book{site_id: site_id} = book) do
    book = Repo.preload(book, [:post, :cover_image])

    Repo.transact(fn ->
      with {:ok, deleted} <- Repo.delete(book) do
        if book.post, do: {:ok, _} = Content.delete_post(scope, book.post)
        if book.cover_image, do: {:ok, _} = Media.delete_image(book.cover_image)
        {:ok, deleted}
      end
    end)
  end

  @doc "Returns a changeset for a book form."
  @spec change_book(Scope.t(), Book.t(), map()) :: Ecto.Changeset.t()
  def change_book(%Scope{}, %Book{} = book, attrs \\ %{}) do
    Book.changeset(book, attrs)
  end

  @doc """
  Creates a review: a post with the given attributes linked from the book.
  """
  @spec create_review(Scope.t(), Book.t(), map()) ::
          {:ok, %{book: Book.t(), post: Post.t()}}
          | {:error, Ecto.Changeset.t()}
          | {:error, :already_reviewed}
  def create_review(
        %Scope{site: %Site{id: site_id}} = scope,
        %Book{site_id: site_id} = book,
        attrs
      ) do
    if Book.review?(book) do
      {:error, :already_reviewed}
    else
      Repo.transact(fn ->
        with {:ok, post} <- Content.create_post(scope, attrs),
             {:ok, book} <- book |> Ecto.Changeset.change(post_id: post.id) |> Repo.update() do
          {:ok, %{book: book, post: post}}
        end
      end)
    end
  end

  @doc """
  Deletes the review of a book: the post is deleted and the rating cleared.
  """
  @spec delete_review(Scope.t(), Book.t()) :: {:ok, Book.t()} | {:error, :no_review}
  def delete_review(%Scope{site: %Site{id: site_id}} = scope, %Book{site_id: site_id} = book) do
    book = Repo.preload(book, :post)

    case book.post do
      nil ->
        {:error, :no_review}

      post ->
        Repo.transact(fn ->
          {:ok, _post} = Content.delete_post(scope, post)

          book
          |> Ecto.Changeset.change(post_id: nil, rating: nil)
          |> Repo.update()
        end)
    end
  end
end
