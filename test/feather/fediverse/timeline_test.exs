defmodule Feather.Fediverse.TimelineTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Fediverse
  alias Feather.Fediverse.{MemberReply, Timeline, TimelinePost}

  @moduletag :capture_log

  @public "https://www.w3.org/ns/activitystreams#Public"

  setup do
    scope = fediverse_scope_fixture(%{domain: "timon.blog"})

    ana =
      remote_account_fixture(%{
        uri: "https://example.social/users/ana",
        inbox: "https://example.social/users/ana/inbox",
        followers_url: "https://example.social/users/ana/followers",
        picture_url: "https://files.example.social/ana.png"
      })

    follower_fixture(
      scope.site,
      remote_account_fixture(%{
        uri: "https://followers.example/users/bob",
        inbox: "https://followers.example/users/bob/inbox"
      })
    )

    followed = followed_account_fixture(scope.site, remote_account: ana)
    %{scope: scope, site: scope.site, ana: ana, followed: followed}
  end

  defp note(n, attrs \\ %{}) do
    Map.merge(
      %{
        "id" => "https://example.social/users/ana/statuses/#{n}",
        "type" => "Note",
        "attributedTo" => "https://example.social/users/ana",
        "content" => "<p>Note #{n}</p>",
        "to" => [@public]
      },
      attrs
    )
  end

  defp serve(responses) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      url = "https://#{conn.host}#{conn.request_path}"

      case Map.fetch(responses, url) do
        {:ok, {content_type, content}} ->
          conn |> put_resp_content_type(content_type) |> send_resp(200, content)

        :error ->
          send(test_pid, {:delivered, conn.host, Jason.decode!(body)})
          send_resp(conn, 202, "")
      end
    end)
  end

  test "broadcasts the posts it files, changes and removes", %{scope: scope, site: site, ana: ana} do
    :ok = Fediverse.subscribe_timeline(scope)

    :ok = Timeline.file(site, ana, note(1))
    assert [%TimelinePost{id: id}] = Repo.all(TimelinePost)
    assert_received {:timeline_post, :created, ^id}

    :ok = Timeline.update(site, ana, note(1, %{"content" => "<p>Edited</p>"}))
    assert_received {:timeline_post, :updated, ^id}

    :ok = Timeline.update(site, ana, note(1, %{"to" => ["https://timon.blog/activitypub/timon"]}))
    assert_received {:timeline_post, :deleted, ^id}
    assert Repo.all(TimelinePost) == []
  end

  test "refuses a post whose text takes more than 100 KB", %{site: site, ana: ana} do
    :ok =
      Timeline.file(
        site,
        ana,
        note(1, %{"name" => "Title", "content" => String.duplicate("a", 99_995)})
      )

    assert [%TimelinePost{name: "Title"}] = Repo.all(TimelinePost)

    :ok =
      Timeline.file(
        site,
        ana,
        note(2, %{"name" => "Long title", "content" => String.duplicate("a", 99_995)})
      )

    assert [%TimelinePost{}] = Repo.all(TimelinePost)
  end

  test "drops the posts kept for more than 30 days", %{followed: followed} do
    expired = timeline_post_fixture(followed)
    kept = timeline_post_fixture(followed)
    long_ago = DateTime.add(DateTime.utc_now(), -31, :day)

    Repo.update_all(from(t in TimelinePost, where: t.id == ^expired.id),
      set: [inserted_at: long_ago]
    )

    assert :ok = Fediverse.run_due()

    assert Enum.map(Repo.all(TimelinePost), & &1.id) == [kept.id]
  end

  describe "a member's reply" do
    setup do
      serve(%{})
      :ok
    end

    test "to a public post goes in public, outside any thread, with a deploy", c do
      target = deployment_target_fixture(c.scope)
      post = timeline_post_fixture(c.followed)

      assert {:ok, %MemberReply{} = reply} =
               Fediverse.reply_to_timeline_post(c.scope, post, %{"content" => "Hakuna matata!"})

      assert {reply.visibility, reply.timeline_post_id, reply.post_id, reply.mention_id} ==
               {:public, post.id, nil, nil}

      assert_received {:delivered, "example.social", %{"type" => "Create", "object" => note}}
      assert_received {:delivered, "followers.example", %{"type" => "Create"}}
      assert note["inReplyTo"] == post.uri
      assert note["to"] == [@public]
      refute Map.has_key?(note, "url")
      target_id = target.id
      assert_received {:deploy_requested, %{id: ^target_id}}
    end

    test "to a post to its author's followers goes only to its author", c do
      deployment_target_fixture(c.scope)
      post = timeline_post_fixture(c.followed, visibility: :followers)

      assert {:ok, %MemberReply{visibility: :direct}} =
               Fediverse.reply_to_timeline_post(c.scope, post, %{"content" => "Psst"})

      assert_received {:delivered, "example.social", %{"to" => [to]}}
      assert to == c.ana.uri
      refute_received {:delivered, "followers.example", _activity}
      refute_received {:deploy_requested, _target}
    end
  end

  describe "pictures" do
    test "load an attachment and the author's picture through the checked requests", c do
      png = test_image_binary(8, 8)
      gif = "GIF89a" <> :binary.copy(<<0>>, 32)

      serve(%{
        "https://files.example.social/1.png" => {"image/png", png},
        "https://files.example.social/ana.png" => {"image/gif", gif}
      })

      post =
        timeline_post_fixture(c.followed,
          attachments: [%{"url" => "https://files.example.social/1.png", "name" => "A cat"}]
        )

      assert Fediverse.timeline_picture(c.scope, post.public_id, 0) == {:ok, png, "image/png"}
      assert Fediverse.timeline_picture(c.scope, post.public_id, 1) == {:error, :not_found}

      assert Fediverse.followed_account_picture(c.scope, c.followed.public_id) ==
               {:ok, gif, "image/gif"}
    end

    test "refuse what is no JPEG, PNG, WebP or GIF, and the posts of other sites", c do
      serve(%{"https://files.example.social/1.svg" => {"image/svg+xml", "<svg></svg>"}})

      post =
        timeline_post_fixture(c.followed,
          attachments: [%{"url" => "https://files.example.social/1.svg", "name" => nil}]
        )

      assert Fediverse.timeline_picture(c.scope, post.public_id, 0) ==
               {:error, :unsupported_format}

      other = fediverse_scope_fixture(%{domain: "pumbaa.blog", fediverse_name: "pumbaa"})
      assert Fediverse.timeline_picture(other, post.public_id, 0) == {:error, :not_found}

      assert Fediverse.followed_account_picture(other, c.followed.public_id) ==
               {:error, :not_found}
    end
  end
end
