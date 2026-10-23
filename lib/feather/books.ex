defmodule Feather.Books do
  @moduledoc """
  The bookshelf of a site, the book search and book reviews.

  A review is a post linked from the book (`book.post_id`). Deleting a
  review deletes the post and clears the rating; deleting a book deletes
  its review post and its cover image.

  Books have no versions: adding, changing and deleting one, and a deleted
  review clearing a rating, move the site's `updated_at`
  (`Feather.Sites.touch_site/1`), so they count as not deployed.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.Post
  alias Feather.Hardcover
  alias Feather.Media
  alias Feather.OpenLibrary
  alias Feather.Repo
  alias Feather.Sites
  alias Feather.Sites.Site
  alias Feather.StaticSite.ImageVariants

  @doc """
  Lists the books of the scope's site, most recently read first. Pass
  `status:` to only list books with that reading status and `preload:` to
  preload associations (e.g. `[:cover_image]`).
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

    query =
      case opts[:preload] do
        nil -> query
        preloads -> preload(query, ^preloads)
      end

    Repo.all(query)
  end

  @doc """
  Finds books of the scope's site for the editor's book block, like Rails'
  `books#lookup`: without a query the 5 most recently read books, with a
  query up to 10 books whose title or author contains it (case-insensitive).
  The cover image is preloaded.
  """
  @spec lookup_books(Scope.t(), String.t() | nil) :: [Book.t()]
  def lookup_books(%Scope{site: %Site{id: site_id}}, query) do
    query = if is_binary(query), do: String.trim(query), else: ""

    base =
      from b in Book,
        where: b.site_id == ^site_id,
        order_by: [desc_nulls_last: b.read_at, desc: b.inserted_at],
        preload: [:cover_image]

    if query == "" do
      base |> limit(5) |> Repo.all()
    else
      pattern = "%" <> String.downcase(escape_like(query)) <> "%"

      base
      |> where(
        [b],
        fragment("lower(?) LIKE ? ESCAPE '\\'", b.title, ^pattern) or
          fragment("lower(?) LIKE ? ESCAPE '\\'", b.author, ^pattern)
      )
      |> limit(10)
      |> Repo.all()
    end
  end

  defp escape_like(text), do: String.replace(text, ~r/([\\%_])/, "\\\\\\1")

  @doc """
  The service the book search asks: Hardcover with a token, OpenLibrary
  without one (ADR 0023).
  """
  @spec search_service() :: Hardcover | OpenLibrary
  def search_service, do: if(Hardcover.configured?(), do: Hardcover, else: OpenLibrary)

  @doc """
  Searches books by title or author on the search service
  (`search_service/0`), for the book form and for agents. Queries shorter
  than 3 characters find nothing. Errors are the service's, never answered
  from the other one.
  """
  @spec search_books(Scope.t(), String.t() | nil) ::
          {:ok, [Hardcover.result() | OpenLibrary.result()]} | {:error, String.t()}
  def search_books(%Scope{}, query), do: search_service().search(query)

  @doc """
  Downloads a cover image (e.g. of a book search result) and makes it the
  book's cover. A previous cover image stays, for the daily image cleanup
  (`Feather.Media.cleanup_orphaned_images/1`) to delete once nothing uses
  it.
  """
  @spec attach_cover_from_url(Scope.t(), Book.t(), String.t()) ::
          {:ok, Book.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def attach_cover_from_url(
        %Scope{site: %Site{id: site_id}} = scope,
        %Book{site_id: site_id} = book,
        url
      ) do
    with {:ok, image} <- Media.create_image_from_url(scope, url, %{}, cover_variants(scope)) do
      attach_cover(scope, book, image)
    end
  end

  @doc """
  Makes an uploaded file the book's cover. A previous cover image stays,
  as with `attach_cover_from_url/3`.
  """
  @spec attach_cover_from_upload(Scope.t(), Book.t(), Path.t(), String.t()) ::
          {:ok, Book.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def attach_cover_from_upload(
        %Scope{site: %Site{id: site_id}} = scope,
        %Book{site_id: site_id} = book,
        path,
        filename
      ) do
    with {:ok, image} <-
           Media.create_image_from_upload(scope, path, filename, %{}, cover_variants(scope)) do
      attach_cover(scope, book, image)
    end
  end

  defp cover_variants(scope),
    do: [variants: ImageVariants.for_role(scope.site, :book_cover)]

  defp attach_cover(scope, book, image) do
    with {:error, changeset} <- update_book(scope, book, %{cover_image_id: image.id}) do
      Media.delete_image(image)
      {:error, changeset}
    end
  end

  @doc "Gets a book of the scope's site by public id. Raises if not found."
  @spec get_book!(Scope.t(), String.t()) :: Book.t()
  def get_book!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from b in Book, where: b.site_id == ^site_id and b.public_id == ^public_id)
  end

  @doc "Gets a book of the scope's site by public id, or nil."
  @spec get_book(Scope.t(), String.t()) :: Book.t() | nil
  def get_book(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one(from b in Book, where: b.site_id == ^site_id and b.public_id == ^public_id)
  end

  @doc """
  The books of the scope's site among `public_ids`, as a map of public id
  to book. Unknown ids and books of other sites are left out.
  """
  @spec books_by_public_id(Scope.t(), [String.t()]) :: %{String.t() => Book.t()}
  def books_by_public_id(%Scope{site: %Site{id: site_id}}, public_ids) do
    query = from b in Book, where: b.site_id == ^site_id and b.public_id in ^public_ids
    Map.new(Repo.all(query), &{&1.public_id, &1})
  end

  @doc "Preloads the cover image of a book."
  @spec preload_cover_image(Book.t()) :: Book.t()
  def preload_cover_image(%Book{} = book), do: Repo.preload(book, :cover_image)

  @doc "The review post of a book, or nil if it has none."
  @spec get_review_post(Scope.t(), Book.t()) :: Post.t() | nil
  def get_review_post(%Scope{}, %Book{post_id: nil}), do: nil

  def get_review_post(%Scope{site: %Site{id: site_id}}, %Book{site_id: site_id, post_id: post_id}) do
    Repo.one(from p in Post, where: p.id == ^post_id and p.site_id == ^site_id)
  end

  @doc "Creates a book in the scope's site."
  @spec create_book(Scope.t(), map()) :: {:ok, Book.t()} | {:error, Ecto.Changeset.t()}
  def create_book(%Scope{site: %Site{id: site_id}} = scope, attrs) do
    %Book{site_id: site_id}
    |> Book.create_changeset(attrs)
    |> Media.validate_site_images([:cover_image_id])
    |> save(scope)
  end

  @doc "Updates a book."
  @spec update_book(Scope.t(), Book.t(), map()) :: {:ok, Book.t()} | {:error, Ecto.Changeset.t()}
  def update_book(%Scope{site: %Site{id: site_id}} = scope, %Book{site_id: site_id} = book, attrs) do
    book
    |> Book.changeset(attrs)
    |> Media.validate_site_images([:cover_image_id])
    |> save(scope)
  end

  defp save(changeset, scope) do
    Repo.transact(fn ->
      with {:ok, book} <- Repo.insert_or_update(changeset),
           :ok <- touch_site_if_changed(changeset, scope),
           do: {:ok, book}
    end)
  end

  defp touch_site_if_changed(%Ecto.Changeset{changes: changes}, _scope) when changes == %{},
    do: :ok

  defp touch_site_if_changed(_changeset, scope), do: Sites.touch_site(scope)

  @doc "Deletes a book, its review post and its cover image."
  @spec delete_book(Scope.t(), Book.t()) :: {:ok, Book.t()} | {:error, Ecto.Changeset.t()}
  def delete_book(%Scope{site: %Site{id: site_id}} = scope, %Book{site_id: site_id} = book) do
    book = Repo.preload(book, [:post, :cover_image])

    Repo.transact(fn -> delete_book_and_dependents(scope, book) end)
  end

  defp delete_book_and_dependents(scope, book) do
    with {:ok, deleted} <- Repo.delete(book) do
      if book.post, do: {:ok, _} = Content.delete_post(scope, book.post)
      if book.cover_image, do: {:ok, _} = Media.delete_image(book.cover_image)
      Sites.touch_site(scope)
      {:ok, deleted}
    end
  end

  @doc "Returns a changeset for a book form."
  @spec change_book(Scope.t(), Book.t(), map()) :: Ecto.Changeset.t()
  def change_book(%Scope{}, %Book{} = book, attrs \\ %{}) do
    Book.changeset(book, attrs)
  end

  @doc """
  Creates a review: a post with the given attributes linked from the book.
  Like every new post it is a draft until it is published.
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
      Repo.transact(fn -> insert_review(scope, book, attrs) end)
    end
  end

  defp insert_review(scope, book, attrs) do
    with {:ok, post} <- Content.create_post(scope, attrs),
         {:ok, book} <- book |> Ecto.Changeset.change(post_id: post.id) |> Repo.update() do
      {:ok, %{book: book, post: post}}
    end
  end

  @doc """
  Autosaves the review form of a book: `Feather.Content.autosave/4` for
  the review post. A new post (without id) becomes the book's review when
  it is created.
  """
  @spec autosave_review(Scope.t(), Book.t(), Post.t(), map(), keyword()) ::
          {:ok, %{book: Book.t(), post: Post.t()}}
          | {:error, :stale | :already_reviewed | Ecto.Changeset.t()}
  def autosave_review(scope, book, post, attrs, opts \\ [])

  def autosave_review(%Scope{} = scope, %Book{} = book, %Post{id: nil} = post, attrs, opts) do
    if Book.review?(book) do
      {:error, :already_reviewed}
    else
      Repo.transact(fn -> autosave_new_review(scope, book, post, attrs, opts) end)
    end
  end

  def autosave_review(
        %Scope{} = scope,
        %Book{post_id: post_id} = book,
        %Post{id: post_id} = post,
        attrs,
        opts
      ) do
    with {:ok, post} <- Content.autosave(scope, post, attrs, opts) do
      {:ok, %{book: book, post: post}}
    end
  end

  defp autosave_new_review(scope, book, post, attrs, opts) do
    with {:ok, post} <- Content.autosave(scope, post, attrs, opts),
         {:ok, book} <- book |> Ecto.Changeset.change(post_id: post.id) |> Repo.update() do
      {:ok, %{book: book, post: post}}
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
        Repo.transact(fn -> delete_review_post(scope, book, post) end)
    end
  end

  defp delete_review_post(scope, book, post) do
    {:ok, _post} = Content.delete_post(scope, post)
    changeset = Ecto.Changeset.change(book, post_id: nil, rating: nil)

    with {:ok, book} <- Repo.update(changeset),
         :ok <- touch_site_if_rating_cleared(changeset, scope),
         do: {:ok, book}
  end

  # The bookshelf shows the rating.
  defp touch_site_if_rating_cleared(changeset, scope) do
    if Ecto.Changeset.changed?(changeset, :rating), do: Sites.touch_site(scope), else: :ok
  end
end
