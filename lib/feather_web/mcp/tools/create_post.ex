defmodule FeatherWeb.MCP.Tools.CreatePost do
  @moduledoc """
  The tool `create_post`: writes a post as a draft, with a book as its
  review.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.{Books, Content}
  alias Feather.Books.Book
  alias FeatherWeb.MCP.{BookFields, ContentFields, PostFields, Tool}

  @impl true
  def definition do
    %{
      name: "create_post",
      title: "Create post",
      description:
        "Writes a new post and saves it as a draft, which the site does not show until " <>
          "publish_post. Without a slug, one is suggested from the title. With book, the post " <>
          "becomes the review of that book, unless it has one. The result links to the " <>
          "editor and the preview, where the member can look at the post before it is " <>
          "published.",
      inputSchema:
        Tool.input_schema(
          Map.put(PostFields.properties(), "book", %{
            "type" => "string",
            "description" => "The id of a book from list_books the post reviews"
          }),
          ["site"]
        ),
      annotations: %{readOnlyHint: false, destructiveHint: false, idempotentHint: false}
    }
  end

  @impl true
  def call(scope, %{"site" => domain} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, attrs} <- PostFields.attrs(scope, put_suggested_slug(scope, arguments)),
         {:ok, post} <- create(scope, attrs, arguments["book"]) do
      {:ok, PostFields.result(scope, post)}
    end
  end

  defp put_suggested_slug(scope, %{"title" => title} = arguments)
       when is_binary(title) and not is_map_key(arguments, "slug"),
       do: Map.put(arguments, "slug", Content.suggest_slug(scope, title))

  defp put_suggested_slug(_scope, arguments), do: arguments

  defp create(scope, attrs, nil) do
    case Content.create_post(scope, attrs) do
      {:ok, post} -> {:ok, post}
      {:error, changeset} -> {:error, ContentFields.save_error(changeset, "post")}
    end
  end

  defp create(scope, attrs, book_id) do
    with {:ok, book} <- BookFields.fetch_book(scope, book_id) do
      case Books.create_review(scope, book, attrs) do
        {:ok, %{post: post}} -> {:ok, post}
        {:error, :already_reviewed} -> {:error, already_reviewed(scope, book)}
        {:error, changeset} -> {:error, ContentFields.save_error(changeset, "post")}
      end
    end
  end

  defp already_reviewed(scope, %Book{} = book) do
    review = Books.get_review_post(scope, book)
    "#{book.title} already has a review, the post #{review.public_id}. update_post changes it."
  end
end
