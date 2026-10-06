defmodule Feather.Books.Book do
  @moduledoc """
  A book on the site's bookshelf. A book may have a review: a post linked
  through `post_id` (there is no separate review model).
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  @reading_statuses ~w(want_to_read reading finished)

  schema "books" do
    field :public_id, :string
    field :title, :string
    field :author, :string
    field :emoji, :string
    field :isbn, :string
    field :open_library_key, :string
    field :rating, :integer
    field :read_at, :date
    field :reading_status, :string, default: "finished"

    belongs_to :site, Feather.Sites.Site
    belongs_to :post, Feather.Content.Post
    belongs_to :cover_image, Feather.Media.Image

    timestamps()
  end

  @doc "The valid reading statuses."
  def reading_statuses, do: @reading_statuses

  @doc false
  def changeset(book, attrs) do
    book
    |> cast(attrs, [
      :title,
      :author,
      :emoji,
      :isbn,
      :open_library_key,
      :rating,
      :read_at,
      :reading_status,
      :cover_image_id
    ])
    |> Feather.Validations.trim_to_nil(:emoji)
    |> validate_required([:title, :author, :reading_status])
    |> validate_inclusion(:reading_status, @reading_statuses)
    |> validate_inclusion(:rating, 1..5, message: "must be between 1 and 5")
    |> put_default_read_at()
    |> unique_constraint(:post_id)
  end

  @doc false
  def create_changeset(book, attrs) do
    book
    |> changeset(attrs)
    |> Feather.PublicId.put_new()
  end

  defp put_default_read_at(changeset) do
    if get_field(changeset, :reading_status) == "finished" and
         is_nil(get_field(changeset, :read_at)) do
      put_change(changeset, :read_at, Date.utc_today())
    else
      changeset
    end
  end

  @doc "Returns true if the book has a review post."
  @spec review?(t()) :: boolean()
  def review?(%__MODULE__{post_id: post_id}), do: not is_nil(post_id)

  @doc "The suggested title for a review of the book."
  @spec review_title_suggestion(t()) :: String.t()
  def review_title_suggestion(%__MODULE__{title: title}), do: "Review: #{title}"
end
