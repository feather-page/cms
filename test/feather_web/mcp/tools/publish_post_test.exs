defmodule FeatherWeb.MCP.Tools.PublishPostTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias FeatherWeb.MCP.Tools.PublishPost

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  defp publish(scope, post),
    do:
      PublishPost.call(scope, %{
        "site" => "notes.example",
        "post" => post.public_id,
        "lock_version" => post.lock_version
      })

  test "publishes the post in the state of its lock version", %{
    site_scope: site_scope,
    scope: scope
  } do
    post = post_fixture(site_scope, title: "Hello", draft: true)
    {:ok, post} = Content.update_post(site_scope, post, %{title: "Hello from the editor"})

    assert {:ok, %{status: :published, title: "Hello from the editor"}} = publish(scope, post)

    [published] = site_scope |> Content.list_posts() |> Content.as_published()
    assert published.title == "Hello from the editor"
  end

  test "a post changed elsewhere since its lock version is not published", %{
    site_scope: site_scope,
    scope: scope
  } do
    post = post_fixture(site_scope, title: "Hello", draft: true)
    {:ok, _post} = Content.update_post(site_scope, post, %{title: "Half written"})

    assert publish(scope, post) ==
             {:error,
              "Not published: the post was changed elsewhere since lock_version " <>
                "#{post.lock_version}. get_post gives it as it is now."}

    assert Content.draft?(Content.get_post!(site_scope, post.public_id))
  end

  test "a publish date in the future makes a scheduled post", %{
    site_scope: site_scope,
    scope: scope
  } do
    publish_at = DateTime.add(DateTime.utc_now(), 3, :day)
    post = post_fixture(site_scope, publish_at: publish_at, draft: true)

    assert {:ok, %{status: :published}} = publish(scope, post)

    [published] = site_scope |> Content.list_posts() |> Content.as_published()
    refute Content.due?(published, DateTime.utc_now())
  end

  test "a slug another published post has is an error", %{site_scope: site_scope, scope: scope} do
    other = post_fixture(site_scope, slug: "/hello")
    {:ok, _other} = Content.update_post(site_scope, other, %{slug: "/moved"})
    post = post_fixture(site_scope, slug: "/hello", draft: true)

    assert publish(scope, post) ==
             {:error, "Not published: another post or page is published with the slug /hello."}

    assert Content.draft?(Content.get_post!(site_scope, post.public_id))
  end

  test "a post of another site is missing", %{scope: scope} do
    theirs = post_fixture(site_scope_fixture(), draft: true)

    assert publish(scope, theirs) ==
             {:error,
              "There is no post #{theirs.public_id} on notes.example. " <>
                "list_posts lists its posts."}
  end
end
