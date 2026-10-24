defmodule Feather.Fediverse.FollowingTest do
  use Feather.DataCase

  alias Feather.Fediverse
  alias Feather.Fediverse.{Delivery, FollowedAccount, TimelinePost}

  @moduletag :capture_log

  @account "https://timon.blog/activitypub/timon"

  setup do
    scope = fediverse_scope_fixture(%{domain: "timon.blog"})
    %{scope: scope, site: scope.site}
  end

  defp delivered(inbox) do
    receive do
      {:fediverse_request, "POST", ^inbox, body} -> Jason.decode!(body)
    after
      0 -> nil
    end
  end

  defp followed_uris(site) do
    Repo.all(
      from f in FollowedAccount,
        join: a in assoc(f, :remote_account),
        where: f.site_id == ^site.id,
        order_by: a.uri,
        select: a.uri
    )
  end

  test "follows several handles at once and sends each a Follow", %{scope: scope, site: site} do
    serve_remote_accounts(["ana@example.social", "bob@micro.example"])

    text = """
    Ana @ana@example.social, bob@micro.example;
    Manton @manton
    """

    assert {:ok, results} = Fediverse.follow(scope, text)

    assert [
             {"@ana@example.social", {:ok, %FollowedAccount{} = ana}},
             {"@bob@micro.example", {:ok, %FollowedAccount{}}},
             {"@manton", {:error, :invalid_handle}}
           ] = results

    assert followed_uris(site) ==
             ["https://example.social/users/ana", "https://micro.example/users/bob"]

    refute FollowedAccount.accepted?(ana)

    assert delivered("https://example.social/users/ana/inbox") == %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => ana.follow_id,
             "type" => "Follow",
             "actor" => @account,
             "object" => "https://example.social/users/ana"
           }

    assert String.starts_with?(ana.follow_id, @account <> "#follows/")
    assert %{"type" => "Follow"} = delivered("https://micro.example/users/bob/inbox")
  end

  test "reports a handle that does not resolve, and the site's own", %{scope: scope} do
    serve_remote_accounts([{"timon@timon.blog", @account}])

    assert {:ok, [{"@nobody@example.social", {:error, :not_found}}]} =
             Fediverse.follow(scope, "@nobody@example.social")

    assert {:ok, [{"@timon@timon.blog", {:error, :own_account}}]} =
             Fediverse.follow(scope, "@timon@timon.blog")
  end

  test "follows an account once", %{scope: scope, site: site} do
    serve_remote_accounts(["ana@example.social"])

    assert {:ok, [{_handle, {:ok, first}}]} = Fediverse.follow(scope, "@ana@example.social")
    assert delivered("https://example.social/users/ana/inbox")

    assert {:ok, [{_handle, {:ok, again}}]} = Fediverse.follow(scope, "ana@example.social")
    assert again.id == first.id
    assert delivered("https://example.social/users/ana/inbox") == nil
    assert length(followed_uris(site)) == 1
  end

  test "refuses to follow a blocked account", %{scope: scope, site: site} do
    serve_remote_accounts(["ana@example.social"])
    zoe = remote_account_fixture(%{uri: "https://example.social/users/zoe"})
    {:ok, _block} = Fediverse.block(scope, zoe, :server)

    assert {:ok, [{"@ana@example.social", {:error, :blocked}}]} =
             Fediverse.follow(scope, "@ana@example.social")

    assert followed_uris(site) == []
    assert delivered("https://example.social/users/ana/inbox") == nil
  end

  test "holds the Follow until the site's account is online" do
    scope = fediverse_scope_fixture(%{domain: "pumbaa.blog", online: false})
    serve_remote_accounts(["ana@example.social"])

    assert {:ok, [{_handle, {:ok, _followed}}]} = Fediverse.follow(scope, "@ana@example.social")

    assert delivered("https://example.social/users/ana/inbox") == nil
    assert [%Delivery{inbox: "https://example.social/users/ana/inbox"}] = Repo.all(Delivery)
  end

  test "refuses no handles, too many and a site without a fediverse name", %{scope: scope} do
    assert Fediverse.follow(scope, "nothing here") == {:error, :no_handles}

    many = Enum.map_join(1..201, " ", &"@user#{&1}@example.social")
    assert Fediverse.follow(scope, many) == {:error, :too_many_handles}

    assert Fediverse.follow(site_scope_fixture(), "@ana@example.social") ==
             {:error, :not_an_account}
  end

  test "unfollowing sends Undo and takes the account's posts out of the Timeline",
       %{scope: scope, site: site} do
    serve_remote_accounts(["ana@example.social"])
    {:ok, [{_handle, {:ok, followed}}]} = Fediverse.follow(scope, "@ana@example.social")
    timeline_post_fixture(followed)

    assert :ok = Fediverse.unfollow(scope, Fediverse.get_followed_account!(scope, followed.id))

    assert %{"type" => "Follow"} = delivered("https://example.social/users/ana/inbox")

    assert delivered("https://example.social/users/ana/inbox") == %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => followed.follow_id <> "/undo",
             "type" => "Undo",
             "actor" => @account,
             "object" => %{
               "id" => followed.follow_id,
               "type" => "Follow",
               "actor" => @account,
               "object" => "https://example.social/users/ana"
             }
           }

    assert followed_uris(site) == []
    assert Repo.all(TimelinePost) == []
  end

  test "counts only the accepted follows", %{scope: scope, site: site} do
    followed_account_fixture(site)
    followed_account_fixture(site, accepted: false)

    assert Fediverse.count_following(scope) == 1
  end
end
