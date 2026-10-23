defmodule FeatherWeb.MCP.Tools.CreatePostTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content}
  alias Feather.Content.BlockValidator
  alias FeatherWeb.MCP.Tools.CreatePost

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "saves a draft with the fields given, images named by id", %{
    site_scope: site_scope,
    scope: scope
  } do
    header = image_fixture(site_scope)
    thumbnail = image_fixture(site_scope)

    assert {:ok, result} =
             CreatePost.call(scope, %{
               "site" => "notes.example",
               "title" => "Hello",
               "slug" => "/hi",
               "meta_title" => "Hello there",
               "description" => "A first post.",
               "emoji" => "👋",
               "tags" => ["Elixir", "phoenix"],
               "publish_at" => "2026-10-01T09:00:00Z",
               "header_image" => header.public_id,
               "thumbnail_image" => thumbnail.public_id,
               "content" => [
                 %{"type" => "paragraph", "text" => "Hi."},
                 %{"type" => "image", "image_id" => header.public_id}
               ]
             })

    assert %{
             title: "Hello",
             slug: "/hi",
             meta_title: "Hello there",
             description: "A first post.",
             emoji: "👋",
             tags: ["elixir", "phoenix"],
             publish_at: ~U[2026-10-01 09:00:00.000000Z],
             header_image: header_id,
             thumbnail_image: thumbnail_id,
             content: [%{"text" => "Hi."}, %{"image_id" => image_id, "caption" => ""}],
             book: nil,
             status: :draft,
             lock_version: 1
           } = result

    assert {header_id, thumbnail_id, image_id} ==
             {header.public_id, thumbnail.public_id, header.public_id}

    post = Content.get_post!(site_scope, result.id)
    assert Content.draft?(post)
    assert post.header_image_id == header.id
  end

  test "suggests the slug from the title", %{site_scope: site_scope, scope: scope} do
    post_fixture(site_scope, title: "Hello", slug: "/hello")

    assert {:ok, %{slug: "/hello1"}} =
             CreatePost.call(scope, %{"site" => "notes.example", "title" => "Hello"})
  end

  test "a short post has no title and no slug until it is published", %{scope: scope} do
    assert {:ok, %{title: nil, slug: nil, preview_url: nil}} =
             CreatePost.call(scope, %{
               "site" => "notes.example",
               "content" => [%{"type" => "paragraph", "text" => "A quick note."}]
             })
  end

  test "with a book, the post becomes its review", %{site_scope: site_scope, scope: scope} do
    book = book_fixture(site_scope, title: "Dune")

    assert {:ok, %{id: id, book: book_id}} =
             CreatePost.call(scope, %{
               "site" => "notes.example",
               "book" => book.public_id,
               "title" => "Review: Dune"
             })

    assert book_id == book.public_id

    assert Books.get_review_post(site_scope, Books.get_book!(site_scope, book.public_id)).public_id ==
             id
  end

  test "a book that has a review gets no second one", %{site_scope: site_scope, scope: scope} do
    book = book_fixture(site_scope, title: "Dune")
    {:ok, %{post: review}} = Books.create_review(site_scope, book, %{title: "Review: Dune"})

    assert CreatePost.call(scope, %{
             "site" => "notes.example",
             "book" => book.public_id,
             "title" => "Another review"
           }) ==
             {:error,
              "Dune already has a review, the post #{review.public_id}. update_post changes it."}

    assert length(Content.list_posts(site_scope)) == 1
  end

  test "a book of another site is missing", %{site_scope: site_scope, scope: scope} do
    theirs = book_fixture(site_scope_fixture())

    assert CreatePost.call(scope, %{
             "site" => "notes.example",
             "book" => theirs.public_id,
             "title" => "Review"
           }) ==
             {:error,
              "There is no book #{theirs.public_id} on notes.example. list_books lists its books."}

    assert Content.list_posts(site_scope) == []
  end

  test "an image of another site is missing", %{site_scope: site_scope, scope: scope} do
    theirs = image_fixture(site_scope_fixture())

    assert CreatePost.call(scope, %{
             "site" => "notes.example",
             "title" => "Hello",
             "header_image" => theirs.public_id
           }) ==
             {:error, "header_image: there is no image #{theirs.public_id} on notes.example."}

    assert Content.list_posts(site_scope) == []
  end

  test "image and book blocks must name the site's images and books", %{
    site_scope: site_scope,
    scope: scope
  } do
    image = image_fixture(site_scope)

    assert CreatePost.call(scope, %{
             "site" => "notes.example",
             "content" => [
               %{"type" => "image", "image_id" => image.public_id},
               %{"type" => "image", "image_id" => "missing"},
               %{"type" => "book", "book_public_id" => "unknown"}
             ]
           }) ==
             {:error,
              "Invalid content: Block 1 (image): there is no image missing on notes.example; " <>
                "Block 2 (book): there is no book unknown on notes.example"}
  end

  test "invalid blocks are an error with the block validator's messages", %{scope: scope} do
    assert CreatePost.call(scope, %{
             "site" => "notes.example",
             "content" => [%{"type" => "header", "text" => "Hi", "level" => 1}]
           }) == {:error, "Invalid content: Block 0 (header): /level must be one of: 2, 3, 4"}
  end

  test "takes content in the block validator's schema" do
    %{inputSchema: schema} = CreatePost.definition()

    assert Map.delete(schema["properties"]["content"], "description") ==
             BlockValidator.content_schema()

    assert schema["$defs"] == BlockValidator.definitions()
  end

  test "invalid fields are an error", %{site_scope: site_scope, scope: scope} do
    post_fixture(site_scope, slug: "/taken")

    assert CreatePost.call(scope, %{
             "site" => "notes.example",
             "title" => "Hello",
             "slug" => "/taken"
           }) == {:error, "Invalid post: slug has already been taken"}
  end
end
