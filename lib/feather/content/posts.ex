defmodule Feather.Content.Posts do
  @moduledoc """
  The posts of a site, called through `Feather.Content`.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.{Post, Saving, Slug}
  alias Feather.Pagination
  alias Feather.Repo
  alias Feather.Sites.Site

  @doc """
  Lists the posts of the scope's site, newest `publish_at` first.
  """
  @spec list_posts(Scope.t()) :: [Post.t()]
  def list_posts(%Scope{site: %Site{id: site_id}}) do
    Repo.all(from p in Post, where: p.site_id == ^site_id, order_by: [desc: p.publish_at])
  end

  @doc """
  Gets a post of the scope's site by public id. Raises if not found.
  """
  @spec get_post!(Scope.t(), String.t()) :: Post.t()
  def get_post!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from p in Post, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc """
  Gets a post of the scope's site by public id, or nil.
  """
  @spec get_post(Scope.t(), String.t()) :: Post.t() | nil
  def get_post(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one(from p in Post, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc """
  One page of the scope's posts for the admin, newest `publish_at` first,
  with the thumbnail image, the reviewed book and the published version
  preloaded.
  """
  @spec paginate_admin_posts(Scope.t(), pos_integer() | String.t() | nil) ::
          Pagination.t()
  def paginate_admin_posts(%Scope{site: %Site{id: site_id}}, page) do
    query =
      from p in Post,
        where: p.site_id == ^site_id,
        order_by: [desc: p.publish_at, desc: p.inserted_at],
        preload: [:thumbnail_image, :book, :published_version]

    Pagination.paginate(query, page)
  end

  @doc """
  Gets a post of the scope's site by slug, or nil.
  """
  @spec get_post_by_slug(Scope.t(), String.t()) :: Post.t() | nil
  def get_post_by_slug(%Scope{site: %Site{id: site_id}}, slug) do
    Repo.get_by(Post, site_id: site_id, slug: Slug.normalize(slug))
  end

  @doc """
  Creates a post in the scope's site, as a draft (see "Saving" in the
  `Feather.Content` module doc).
  """
  @spec create_post(Scope.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def create_post(%Scope{site: %Site{id: site_id}}, attrs) do
    %Post{site_id: site_id}
    |> Post.create_changeset(attrs)
    |> Saving.save_with_images(:post_id)
  end

  @doc """
  Updates a post: stores the changes as its unpublished changes (see
  "Saving" in the `Feather.Content` module doc).
  """
  @spec update_post(Scope.t(), Post.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def update_post(%Scope{site: %Site{id: site_id}}, %Post{site_id: site_id} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Saving.save_with_images(:post_id)
  end

  @doc """
  Deletes a post and the images it owns that nothing else uses. A book reviewed by the post
  loses its review.
  """
  @spec delete_post(Scope.t(), Post.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def delete_post(%Scope{site: %Site{id: site_id}} = scope, %Post{site_id: site_id} = post) do
    Saving.delete_with_images(scope, post, :post_id)
  end

  @doc "Returns a changeset for a post form."
  @spec change_post(Scope.t(), Post.t(), map()) :: Ecto.Changeset.t()
  def change_post(%Scope{}, %Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end
end
