defmodule Feather.Fediverse.MemberRepliesTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Fediverse
  alias Feather.Fediverse.{MemberReply, Mention, Mentions}
  alias Feather.StaticSite.{Export, FileSink, RecordingSink, Routes}

  @moduletag :capture_log
  @moduletag :tmp_dir

  @public "https://www.w3.org/ns/activitystreams#Public"
  @account "https://timon.blog/activitypub/timon"
  @followers "https://timon.blog/activitypub/followers"

  setup do
    scope = fediverse_scope_fixture(%{domain: "timon.blog"})
    post = post_fixture(scope, %{title: "Hakuna matata", slug: "/hakuna-matata"})

    ana =
      remote_account_fixture(%{
        uri: "https://example.social/users/ana",
        inbox: "https://example.social/users/ana/inbox",
        name: "Ana",
        handle: "@ana@example.social"
      })

    follower_fixture(
      scope.site,
      remote_account_fixture(%{
        uri: "https://followers.example/users/bob",
        inbox: "https://followers.example/users/bob/inbox"
      })
    )

    capture_deliveries()
    %{scope: scope, site: scope.site, post: post, ana: ana}
  end

  defp capture_deliveries do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      send(test_pid, {:delivered, conn.host, Jason.decode!(body)})
      send_resp(conn, 202, "")
    end)
  end

  defp export(site) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(site), routes(site), sink)
    sink
  end

  # As a deploy does: export into a directory, then send the followers what changed.
  defp deploy(site, tmp_dir) do
    sink = FileSink.new(tmp_dir)
    :ok = Export.run(Repo.reload!(site), routes(site), sink)
    :ok = Fediverse.federate(Repo.reload!(site), FileSink.dir(sink))
    FileSink.discard(sink)
  end

  defp routes(site), do: Routes.new(site, canonical_url: "https://#{site.domain}/")

  defp document_path(reply), do: "activitypub/replies/#{reply.public_id}"

  defp reply!(scope, mention, content) do
    {:ok, reply} = Fediverse.reply_to_mention(scope, mention, %{"content" => content})
    reply
  end

  describe "a member's public reply" do
    setup c do
      target = deployment_target_fixture(c.scope)
      answered = approved_reply_fixture(c.site, c.post, remote_account: c.ana, picture: false)
      %{target: target, answered: answered}
    end

    test "goes to the author's server at once, with its content, and starts a deploy", c do
      reply = reply!(c.scope, c.answered, "Thank you, Ana!\n\nHakuna <matata>.")

      assert_received {:delivered, "example.social", create}
      assert_received {:delivered, "followers.example", ^create}
      assert_received {:deploy_requested, %{id: target_id}}
      assert target_id == c.target.id

      note = create["object"]
      id = "https://timon.blog/activitypub/replies/#{reply.public_id}"

      assert create["type"] == "Create"
      assert create["id"] == id <> "#create"
      assert create["actor"] == @account
      assert {create["to"], create["cc"]} == {[@public], [@followers, c.ana.uri]}

      assert note["id"] == id
      assert note["type"] == "Note"
      assert note["attributedTo"] == @account
      assert note["inReplyTo"] == c.answered.uri
      assert note["url"] == "https://timon.blog/hakuna-matata/#reply-#{reply.public_id}"
      assert note["content"] == "<p>Thank you, Ana!</p><p>Hakuna &lt;matata&gt;.</p>"
      assert note["contentMap"] == %{"en" => note["content"]}
      assert {note["to"], note["cc"]} == {[@public], [@followers, c.ana.uri]}
      assert note["tag"] == [%{"type" => "Mention", "href" => c.ana.uri}]

      assert %MemberReply{visibility: :public, post_id: post_id, recipients: [ana_uri]} = reply
      assert {post_id, ana_uri} == {c.post.id, c.ana.uri}
    end

    test "is written by the deploy it starts, without approval", c do
      reply = reply!(c.scope, c.answered, "Thank you, Ana!")
      assert_received {:delivered, "example.social", %{"object" => sent}}

      sink = export(c.site)
      document = sink |> RecordingSink.get(document_path(reply)) |> Jason.decode!()

      assert Map.delete(document, "@context") == sent
      assert document["@context"] == "https://www.w3.org/ns/activitystreams"

      doc = LazyHTML.from_document(RecordingSink.get(sink, "hakuna-matata/index.html"))

      assert doc
             |> LazyHTML.query(
               "#replies .reply-list > li .reply-answers > li#reply-#{reply.public_id}"
             )
             |> LazyHTML.text() =~ "Thank you, Ana!"
    end

    test "is checked before it goes out", c do
      for content <- ["", "  \n ", String.duplicate("a", 5_001)] do
        assert {:error, %Ecto.Changeset{}} =
                 Fediverse.reply_to_mention(c.scope, c.answered, %{"content" => content})
      end

      refute_received {:delivered, _host, _activity}
      refute_received {:deploy_requested, _target}
      assert Repo.all(MemberReply) == []
    end

    test "is deleted with a deploy first, then its Delete goes out", c do
      reply = reply!(c.scope, c.answered, "Thank you, Ana!")
      assert_received {:delivered, "example.social", %{"type" => "Create"}}
      assert_received {:delivered, "followers.example", %{"type" => "Create"}}
      assert_received {:deploy_requested, _target}
      deploy(c.site, c.tmp_dir)

      assert :ok = Fediverse.delete_member_reply(c.scope, reply)

      assert_received {:deploy_requested, _target}
      refute_received {:delivered, _host, _activity}
      refute Repo.reload!(reply).deleted_at == nil
      refute document_path(reply) in RecordingSink.paths(export(c.site))

      deploy(c.site, c.tmp_dir)

      assert_received {:delivered, "example.social", delete}
      assert_received {:delivered, "followers.example", ^delete}
      assert delete["type"] == "Delete"
      assert delete["actor"] == @account

      assert delete["object"] == %{
               "id" => "https://timon.blog/activitypub/replies/#{reply.public_id}",
               "type" => "Tombstone"
             }

      assert {delete["to"], delete["cc"]} == {[@public], [@followers, c.ana.uri]}
      assert Repo.reload(reply) == nil
    end

    test "waits for the deploy that takes its document off the site", c do
      reply = reply!(c.scope, c.answered, "Thank you, Ana!")
      sink = FileSink.new(c.tmp_dir)
      :ok = Export.run(Repo.reload!(c.site), routes(c.site), sink)

      :ok = Fediverse.delete_member_reply(c.scope, reply)
      :ok = Fediverse.federate(Repo.reload!(c.site), FileSink.dir(sink))

      refute_received {:delivered, _host, %{"type" => "Delete"}}
      assert Repo.reload(reply)
    end

    test "of a site without a deployment target is deleted at once", c do
      Repo.delete!(c.target)
      reply = reply!(c.scope, c.answered, "Thank you, Ana!")

      assert :ok = Fediverse.delete_member_reply(c.scope, reply)

      assert_received {:delivered, "example.social", %{"type" => "Delete"}}
      assert Repo.reload(reply) == nil
    end
  end

  describe "a reply to a private message" do
    setup c do
      deployment_target_fixture(c.scope)

      carl =
        remote_account_fixture(%{
          uri: "https://other.example/users/carl",
          inbox: "https://other.example/users/carl/inbox"
        })

      message =
        mention_fixture(c.site,
          remote_account: c.ana,
          visibility: :direct,
          content: "Psst",
          named_accounts: [carl.uri]
        )

      %{message: message, carl: carl}
    end

    test "goes only to the accounts the message names and starts no deploy", c do
      reply = reply!(c.scope, c.message, "Only for you")

      assert_received {:delivered, "example.social", create}
      assert_received {:delivered, "other.example", ^create}
      refute_received {:delivered, _host, _activity}
      refute_received {:deploy_requested, _target}

      assert create["to"] == [c.ana.uri, c.carl.uri]
      refute Map.has_key?(create, "cc")
      refute Map.has_key?(create["object"], "url")

      assert create["object"]["tag"] == [
               %{"type" => "Mention", "href" => c.ana.uri},
               %{"type" => "Mention", "href" => c.carl.uri}
             ]

      assert %MemberReply{visibility: :direct, post_id: nil} = reply
    end

    test "has no document on the site", c do
      reply = reply!(c.scope, c.message, "Only for you")

      paths = RecordingSink.paths(export(c.site))

      refute document_path(reply) in paths
      refute Enum.any?(paths, &String.starts_with?(&1, "activitypub/replies"))
    end

    test "is stored encrypted, its recipients in clear text", c do
      reply!(c.scope, c.message, "Only for you")

      [[content, recipients]] =
        Repo.query!("SELECT content, recipients FROM fediverse_member_replies").rows

      refute content =~ "Only for you"
      assert recipients =~ c.carl.uri
    end

    test "is deleted at once, its Delete only to the accounts it went to", c do
      reply = reply!(c.scope, c.message, "Only for you")
      assert_received {:delivered, "example.social", %{"type" => "Create"}}
      assert_received {:delivered, "other.example", %{"type" => "Create"}}

      assert :ok = Fediverse.delete_member_reply(c.scope, reply)

      assert_received {:delivered, "example.social", delete}
      assert_received {:delivered, "other.example", ^delete}
      refute_received {:delivered, _host, _activity}
      refute_received {:deploy_requested, _target}
      assert delete["to"] == [c.ana.uri, c.carl.uri]
      assert Repo.reload(reply) == nil
    end
  end

  test "a site without a fediverse name sends no reply", c do
    scope = site_scope_fixture()
    mention = mention_fixture(scope.site, remote_account: c.ana)

    assert {:error, :not_an_account} =
             Fediverse.reply_to_mention(scope, mention, %{"content" => "Hi"})

    refute_received {:delivered, _host, _activity}
    refute Repo.exists?(MemberReply)
  end

  test "a reply to a followers-only reply is not public either", c do
    reply =
      reply!(
        c.scope,
        mention_fixture(c.site,
          remote_account: c.ana,
          post_id: c.post.id,
          visibility: :followers
        ),
        "Hi"
      )

    assert_received {:delivered, "example.social", %{"to" => to}}
    refute_received {:delivered, "followers.example", _activity}
    assert to == [c.ana.uri]
    assert %MemberReply{visibility: :direct, post_id: nil} = reply
  end

  test "a reply to a public mention that answers no post is public, without a page", c do
    reply = reply!(c.scope, mention_fixture(c.site, remote_account: c.ana), "Hi")

    assert_received {:delivered, "example.social", %{"object" => note}}
    assert note["to"] == [@public]
    refute Map.has_key?(note, "url")
    assert %MemberReply{visibility: :public, post_id: nil} = reply
  end

  test "a reply to a reply waiting for approval goes out without a place in the thread", c do
    waiting = mention_fixture(c.site, remote_account: c.ana, post_id: c.post.id)
    reply = reply!(c.scope, waiting, "Hi")

    assert_received {:delivered, "example.social", %{"object" => note}}
    assert note["to"] == [@public]
    refute Map.has_key?(note, "url")
    assert %MemberReply{visibility: :public, post_id: post_id} = reply
    assert post_id == c.post.id
  end

  describe "replies to a member's reply" do
    test "land in Mentions like replies to the site's posts", c do
      answered = approved_reply_fixture(c.site, c.post, remote_account: c.ana, picture: false)
      reply = reply!(c.scope, answered, "Thank you, Ana!")
      carl = remote_account_fixture()

      object = %{
        "id" => carl.uri <> "/statuses/1",
        "type" => "Note",
        "attributedTo" => carl.uri,
        "inReplyTo" => "https://timon.blog/activitypub/replies/#{reply.public_id}",
        "content" => "<p>Me too</p>",
        "to" => [@public]
      }

      assert Mentions.addresses?(c.site, object)
      :ok = Mentions.file(c.site, carl, object)

      assert %Mention{post_id: post_id, visibility: :public} =
               Repo.get_by!(Mention, remote_account_id: carl.id)

      assert post_id == c.post.id
    end
  end

  test "lists the members' replies newest first, orphans too, not those being deleted", c do
    mention = mention_fixture(c.site, remote_account: c.ana, post_id: c.post.id)
    followed = followed_account_fixture(c.site, remote_account: c.ana)
    to_mention = member_reply_fixture(mention, "Thank you, Ana!")
    to_post = member_reply_fixture(timeline_post_fixture(followed), "Nice post")
    gone = mention_fixture(c.site, remote_account: c.ana, post_id: c.post.id)
    orphan = member_reply_fixture(gone, "Thanks again")
    :ok = Mentions.delete(c.site, c.ana, gone.uri)

    mention
    |> member_reply_fixture("Oops")
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
    |> Repo.update!()

    member_reply_fixture(mention_fixture(fediverse_site_fixture(%{domain: "pumbaa.blog"})))

    for {reply, minutes} <- [{to_mention, 3}, {to_post, 2}, {orphan, 1}] do
      reply
      |> Ecto.Changeset.change(inserted_at: DateTime.add(DateTime.utc_now(), -minutes, :minute))
      |> Repo.update!()
    end

    assert [listed_orphan, listed_to_post, listed_to_mention] =
             Fediverse.paginate_member_replies(c.scope, 1).entries

    assert {listed_orphan.id, listed_orphan.mention, listed_orphan.post.id} ==
             {orphan.id, nil, c.post.id}

    assert listed_to_post.id == to_post.id
    assert listed_to_post.timeline_post.followed_account.remote_account.uri == c.ana.uri
    assert listed_to_mention.id == to_mention.id
    assert listed_to_mention.mention.remote_account.uri == c.ana.uri
  end
end
