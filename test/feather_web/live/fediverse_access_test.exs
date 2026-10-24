defmodule FeatherWeb.FediverseAccessTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Fediverse, Repo}
  alias Feather.Fediverse.{Block, FollowedAccount, MemberReply, Mention}

  @moduletag :capture_log

  setup [:register_and_log_in_user, :create_site_for_user]

  setup %{scope: scope} do
    {:ok, _site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
    other = fediverse_scope_fixture(%{domain: "pumbaa.blog"})
    %{other: other, theirs: other.site}
  end

  defp page_path(site, page), do: "/sites/#{site.public_id}/#{page}"

  # Another site's record is as missing as one that never was.
  defp assert_refused(conn, path, event, params) do
    {:ok, lv, _html} = live(conn, path)
    Process.flag(:trap_exit, true)

    assert {{%Ecto.NoResultsError{}, _stacktrace}, _call} =
             catch_exit(render_click(lv, event, params)),
           event
  end

  test "a non-member cannot open the Fediverse pages or the settings",
       %{conn: conn, theirs: theirs} do
    for page <- ~w(mentions timeline following settings) do
      assert_raise Ecto.NoResultsError, fn -> live(conn, page_path(theirs, page)) end
    end
  end

  test "Mentions acts on no mention or reply of another site",
       %{conn: conn, site: site, other: other, theirs: theirs} do
    mention = mention_fixture(theirs, post_id: post_fixture(other).id)
    reply = member_reply_fixture(mention)

    for {event, params} <- [
          {"approve", %{"id" => mention.id, "version" => Mention.version(mention)}},
          {"hide", %{"id" => mention.id}},
          {"reply", %{"mention_id" => mention.id, "reply" => %{"content" => "Hi"}}},
          {"delete_reply", %{"id" => reply.id}},
          {"block_account", %{"id" => mention.id}},
          {"block_server", %{"id" => mention.id}}
        ] do
      assert_refused(conn, page_path(site, "mentions"), event, params)
    end

    assert Repo.reload!(mention).approval == :waiting
    assert [%MemberReply{id: id}] = Repo.all(MemberReply)
    assert id == reply.id
    assert Repo.all(Block) == []
  end

  test "the Timeline acts on no post or reply of another site",
       %{conn: conn, site: site, theirs: theirs} do
    post = theirs |> followed_account_fixture() |> timeline_post_fixture()
    reply = theirs |> mention_fixture() |> member_reply_fixture()

    for {event, params} <- [
          {"reply", %{"timeline_post_id" => post.id, "reply" => %{"content" => "Hi"}}},
          {"delete_reply", %{"id" => reply.id}},
          {"block_account", %{"id" => post.id}},
          {"block_server", %{"id" => post.id}}
        ] do
      assert_refused(conn, page_path(site, "timeline"), event, params)
    end

    assert [%MemberReply{id: id}] = Repo.all(MemberReply)
    assert id == reply.id
    assert Repo.all(Block) == []
  end

  test "Following unfollows no account another site follows",
       %{conn: conn, site: site, theirs: theirs} do
    followed = followed_account_fixture(theirs)

    assert_refused(conn, page_path(site, "following"), "unfollow", %{"id" => followed.id})

    assert Repo.get(FollowedAccount, followed.id)
  end

  test "the settings lift no block of another site", %{conn: conn, site: site, other: other} do
    {:ok, block} = Fediverse.block(other, remote_account_fixture(), :server)

    assert_refused(conn, page_path(site, "settings"), "unblock", %{"id" => block.id})

    assert Repo.get(Block, block.id)
  end
end
