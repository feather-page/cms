defmodule FeatherWeb.MCP.Tools.UpdatePostTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias FeatherWeb.MCP.Tools.{GetPost, UpdatePost}

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "changes only the fields given into unpublished changes, null clears one", %{
    site_scope: site_scope,
    scope: scope
  } do
    header = image_fixture(site_scope)

    post =
      post_fixture(site_scope,
        title: "Hello",
        emoji: "👋",
        tags: "elixir",
        header_image_id: header.id
      )

    assert {:ok, result} =
             UpdatePost.call(scope, %{
               "site" => "notes.example",
               "post" => post.public_id,
               "lock_version" => post.lock_version,
               "title" => "Hello, world",
               "emoji" => nil,
               "header_image" => nil,
               "content" => [%{"type" => "paragraph", "text" => "New."}]
             })

    assert %{
             title: "Hello, world",
             emoji: nil,
             tags: ["elixir"],
             header_image: nil,
             content: [%{"text" => "New."}],
             status: :unpublished_changes
           } = result

    assert result.lock_version == post.lock_version + 1

    [published] = site_scope |> Content.list_posts() |> Content.as_published()
    assert published.title == "Hello"
  end

  test "tags are normalized, null clears them", %{site_scope: site_scope, scope: scope} do
    post = post_fixture(site_scope, tags: "elixir")
    arguments = %{"site" => "notes.example", "post" => post.public_id}

    assert {:ok, %{tags: ["phoenix", "elixir"], lock_version: lock_version}} =
             UpdatePost.call(
               scope,
               Map.merge(arguments, %{
                 "lock_version" => post.lock_version,
                 "tags" => [" Phoenix", "elixir", "phoenix"]
               })
             )

    assert {:ok, %{tags: []}} =
             UpdatePost.call(
               scope,
               Map.merge(arguments, %{"lock_version" => lock_version, "tags" => nil})
             )
  end

  test "publish_at sent back as get_post gave it changes nothing", %{
    site_scope: site_scope,
    scope: scope
  } do
    post = post_fixture(site_scope, publish_at: ~U[2026-10-01 09:00:00.123456Z])
    {:ok, read} = GetPost.call(scope, %{"site" => "notes.example", "post" => post.public_id})
    %{"publish_at" => publish_at} = read |> Jason.encode!() |> Jason.decode!()

    assert {:ok, %{status: :published}} =
             UpdatePost.call(scope, %{
               "site" => "notes.example",
               "post" => post.public_id,
               "lock_version" => read.lock_version,
               "publish_at" => publish_at
             })
  end

  test "a post changed elsewhere since its lock version is not saved", %{
    site_scope: site_scope,
    scope: scope
  } do
    post = post_fixture(site_scope, title: "Hello", draft: true)
    {:ok, _post} = Content.update_post(site_scope, post, %{title: "Hello from the editor"})

    assert UpdatePost.call(scope, %{
             "site" => "notes.example",
             "post" => post.public_id,
             "lock_version" => post.lock_version,
             "title" => "Hello from Claude"
           }) ==
             {:error,
              "The post was changed elsewhere since lock_version #{post.lock_version}, " <>
                "so nothing was saved. get_post gives it as it is now."}

    assert Content.get_post!(site_scope, post.public_id).title == "Hello from the editor"
  end

  test "invalid changes are an error", %{site_scope: site_scope, scope: scope} do
    post = post_fixture(site_scope, draft: true)

    assert UpdatePost.call(scope, %{
             "site" => "notes.example",
             "post" => post.public_id,
             "lock_version" => post.lock_version,
             "slug" => "/images/me"
           }) == {:error, "Invalid post: slug is reserved"}
  end

  test "a post of another site is missing", %{scope: scope} do
    theirs = post_fixture(site_scope_fixture())

    assert UpdatePost.call(scope, %{
             "site" => "notes.example",
             "post" => theirs.public_id,
             "lock_version" => theirs.lock_version,
             "title" => "Mine"
           }) ==
             {:error,
              "There is no post #{theirs.public_id} on notes.example. " <>
                "list_posts lists its posts."}
  end
end
