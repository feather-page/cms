defmodule Feather.Fediverse.BlocksTest do
  use Feather.DataCase

  alias Feather.Fediverse

  alias Feather.Fediverse.{
    Block,
    Blocks,
    FollowedAccount,
    Follower,
    Mention,
    Pictures,
    TimelinePost
  }

  @moduletag :capture_log

  @account "https://timon.blog/activitypub/timon"

  setup do
    scope = fediverse_scope_fixture(%{domain: "timon.blog"})
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      inbox = "https://#{conn.host}#{conn.request_path}"
      send(test_pid, {:delivered, inbox, Jason.decode!(body)})
      Plug.Conn.send_resp(conn, 202, "")
    end)

    %{scope: scope, site: scope.site, ana: account("example.social", "ana")}
  end

  defp account(host, user) do
    uri = "https://#{host}/users/#{user}"
    remote_account_fixture(%{uri: uri, inbox: uri <> "/inbox", handle: "@#{user}@#{host}"})
  end

  defp delivered(inbox) do
    receive do
      {:delivered, ^inbox, activity} -> [activity | delivered(inbox)]
    after
      0 -> []
    end
  end

  defp by_type(activities), do: Map.new(activities, &{&1["type"], &1})

  defp follower_uris(site) do
    Repo.all(
      from f in Follower,
        join: a in assoc(f, :remote_account),
        where: f.site_id == ^site.id,
        order_by: a.uri,
        select: a.uri
    )
  end

  defp mention_authors(site) do
    Repo.all(
      from m in Mention,
        join: a in assoc(m, :remote_account),
        where: m.site_id == ^site.id,
        order_by: a.uri,
        select: a.uri
    )
  end

  test "blocking an account ends the follows both ways, deletes its mentions and tells its server",
       %{scope: scope, site: site, ana: ana} do
    bob = account("example.social", "bob")
    for account <- [ana, bob], do: follower_fixture(site, account)
    followed = followed_account_fixture(site, remote_account: ana)
    timeline_post_fixture(followed)
    for account <- [ana, bob], do: mention_fixture(site, remote_account: account)

    assert {:ok,
            %Block{account_uri: account_uri, handle: "@ana@example.social", host: nil} = block} =
             Fediverse.block(scope, ana, :account)

    assert account_uri == ana.uri

    assert %{"Undo" => undo, "Reject" => reject, "Block" => sent} =
             by_type(delivered(ana.inbox))

    assert undo["object"]["id"] == followed.follow_id

    assert reject["object"] == %{
             "id" => ana.uri <> "#follow",
             "type" => "Follow",
             "actor" => ana.uri,
             "object" => @account
           }

    assert sent == %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => @account <> "#blocks/" <> block.id,
             "type" => "Block",
             "actor" => @account,
             "object" => ana.uri
           }

    assert delivered(bob.inbox) == []
    assert follower_uris(site) == [bob.uri]
    assert mention_authors(site) == [bob.uri]
    assert Repo.all(FollowedAccount) == []
    assert Repo.all(TimelinePost) == []

    assert Blocks.blocked?(site, ana.uri)
    refute Blocks.blocked?(site, bob.uri)
  end

  test "blocking a server blocks every account on it, no other, and sends no Block",
       %{scope: scope, site: site, ana: ana} do
    bob = account("example.social", "bob")
    carl = account("example.social.other", "carl")

    for account <- [ana, bob, carl] do
      follower_fixture(site, account)
      mention_fixture(site, remote_account: account)
    end

    assert {:ok, %Block{host: "example.social", account_uri: nil, handle: nil}} =
             Fediverse.block(scope, bob, :server)

    for account <- [ana, bob] do
      assert [%{"type" => "Reject"}] = delivered(account.inbox)
    end

    assert delivered(carl.inbox) == []
    assert follower_uris(site) == [carl.uri]
    assert mention_authors(site) == [carl.uri]

    assert Blocks.blocked?(site, "https://EXAMPLE.social/users/zoe")
    refute Blocks.blocked?(site, carl.uri)
    refute Blocks.blocked?(fediverse_site_fixture(%{domain: "pumbaa.blog"}), ana.uri)
  end

  test "blocking a server blocks its subdomains too, written with a trailing dot or not",
       %{scope: scope, site: site} do
    zoe = account("example.social.", "zoe")
    media = account("media.example.social", "bob")
    other = account("notexample.social", "carl")
    for account <- [media, other], do: follower_fixture(site, account)

    assert {:ok, %Block{host: "example.social"}} = Fediverse.block(scope, zoe, :server)

    assert follower_uris(site) == [other.uri]
    assert Blocks.blocked?(site, "https://example.social/users/ana")
    assert Blocks.blocked?(site, "https://a.media.example.social./users/dan")
    refute Blocks.blocked?(site, other.uri)
  end

  test "a blocked account's approved replies leave the site with a deploy, their pictures after it",
       %{scope: scope, site: site, ana: ana} do
    deployment_target_fixture(scope)
    post = post_fixture(scope)
    approved = approved_reply_fixture(site, post, remote_account: ana)

    {:ok, _block} = Fediverse.block(scope, ana, :account)

    assert Repo.all(Mention) == []
    assert Pictures.unused(site) == [approved.approved_picture]
    assert_received {:deploy_requested, _target}
    assert Fediverse.approved_replies(site, [post]) == %{}
  end

  test "blocking twice keeps one block", %{scope: scope, ana: ana} do
    {:ok, block} = Fediverse.block(scope, ana, :account)
    {:ok, again} = Fediverse.block(scope, ana, :account)
    {:ok, server} = Fediverse.block(scope, ana, :server)
    {:ok, server_again} = Fediverse.block(scope, ana, :server)

    assert again.id == block.id
    assert server_again.id == server.id
    assert Enum.map(Fediverse.list_blocks(scope), & &1.id) == [server.id, block.id]
  end

  test "unblocking an account sends the Undo of its Block; a server is unblocked quietly",
       %{scope: scope, site: site, ana: ana} do
    {:ok, block} = Fediverse.block(scope, ana, :account)
    assert [%{"type" => "Block"} = sent] = delivered(ana.inbox)

    assert :ok = Fediverse.unblock(scope, Fediverse.get_block!(scope, block.id))

    assert [
             %{
               "type" => "Undo",
               "id" => undo_id,
               "actor" => @account,
               "object" => object
             }
           ] = delivered(ana.inbox)

    assert undo_id == sent["id"] <> "/undo"
    assert object == Map.delete(sent, "@context")
    refute Blocks.blocked?(site, ana.uri)

    {:ok, server} = Fediverse.block(scope, ana, :server)
    assert :ok = Fediverse.unblock(scope, server)
    assert delivered(ana.inbox) == []
    assert Fediverse.list_blocks(scope) == []
  end

  test "lists and finds only the blocks of the scope's site", %{scope: scope, ana: ana} do
    other = fediverse_scope_fixture(%{domain: "pumbaa.blog"})
    {:ok, block} = Fediverse.block(other, ana, :account)

    assert Fediverse.list_blocks(scope) == []
    assert_raise Ecto.NoResultsError, fn -> Fediverse.get_block!(scope, block.id) end
  end
end
