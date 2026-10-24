defmodule Feather.Fediverse.MentionsTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Fediverse
  alias Feather.Fediverse.{Mention, Mentions, Pictures, Tombstone}
  alias Feather.Publishing.Notifications
  alias Vix.Vips.{Image, Operation}

  @moduletag :capture_log

  @account "https://timon.blog/activitypub/timon"
  @public "https://www.w3.org/ns/activitystreams#Public"
  @picture_url "https://files.mastodon.example/ana.png"

  setup do
    scope = fediverse_scope_fixture(%{domain: "timon.blog"})
    %{scope: scope, site: scope.site}
  end

  defp note(author, n, attrs \\ %{}) do
    Map.merge(
      %{
        "id" => author.uri <> "/statuses/#{n}",
        "type" => "Note",
        "attributedTo" => author.uri,
        "content" => "<p>Hello @timon</p>",
        "to" => [@account]
      },
      attrs
    )
  end

  defp count(site), do: Repo.aggregate(from(m in Mention, where: m.site_id == ^site.id), :count)

  describe "addresses?/2" do
    test "a note to the account, mentioning it or replying to one of its posts", c do
      post = post_fixture(c.scope)
      other = post_fixture(site_scope_fixture())
      ana = remote_account_fixture()
      post_url = "https://timon.blog/activitypub/posts/#{post.public_id}"

      assert Mentions.addresses?(c.site, note(ana, 1))
      assert Mentions.addresses?(c.site, note(ana, 1, %{"type" => "Article", "cc" => @account}))

      assert Mentions.addresses?(
               c.site,
               note(ana, 1, %{"to" => [], "tag" => [%{"type" => "Mention", "href" => @account}]})
             )

      assert Mentions.addresses?(c.site, note(ana, 1, %{"to" => [], "inReplyTo" => post_url}))

      for object <- [
            note(ana, 1, %{"to" => ["https://pumbaa.blog/activitypub/pumbaa"]}),
            note(ana, 1, %{"to" => [], "inReplyTo" => String.replace(post_url, "timon", "x")}),
            note(ana, 1, %{
              "to" => [],
              "inReplyTo" => "https://timon.blog/activitypub/posts/#{other.public_id}"
            }),
            note(ana, 1, %{"type" => "Question"}),
            @account
          ] do
        refute Mentions.addresses?(c.site, object), inspect(object)
      end
    end

    test "a reply to any address the post's document had", c do
      post = post_fixture(c.scope)

      Repo.update_all(from(p in Feather.Content.Post, where: p.id == ^post.id),
        set: [fediverse_generation: 2]
      )

      ana = remote_account_fixture()
      post_url = "https://timon.blog/activitypub/posts/#{post.public_id}"

      for url <- [post_url, post_url <> "-2"] do
        assert Mentions.addresses?(c.site, note(ana, 1, %{"to" => [], "inReplyTo" => url})), url
      end

      for suffix <- ["-3", "-1", "-0", "-02", "-x", "-2-2"] do
        object = note(ana, 1, %{"to" => [], "inReplyTo" => post_url <> suffix})
        refute Mentions.addresses?(c.site, object), suffix
      end
    end
  end

  describe "file/3" do
    test "caps an account that does not follow the site at 20 mentions a day", c do
      ana = remote_account_fixture()
      follower = remote_account_fixture()
      follower_fixture(c.site, follower)

      for n <- 1..21, do: :ok = Mentions.file(c.site, ana, note(ana, n))
      for n <- 1..21, do: :ok = Mentions.file(c.site, follower, note(follower, n))

      assert Repo.aggregate(from(m in Mention, where: m.remote_account_id == ^ana.id), :count) ==
               20

      assert count(c.site) == 41
    end

    test "caps the accounts of a server at 100 mentions a day, its followers too", c do
      for _n <- 1..100, do: mention_fixture(c.site)
      follower = remote_account_fixture()
      follower_fixture(c.site, follower)
      carl = remote_account_fixture(%{uri: "https://other.example/users/carl"})

      :ok = Mentions.file(c.site, follower, note(follower, 1))
      :ok = Mentions.file(c.site, carl, note(carl, 1))
      assert count(c.site) == 101

      Repo.update_all(Mention, set: [inserted_at: DateTime.add(DateTime.utc_now(), -25, :hour)])

      :ok = Mentions.file(c.site, follower, note(follower, 2))
      assert count(c.site) == 102
    end

    test "files an object once", c do
      ana = remote_account_fixture()

      :ok = Mentions.file(c.site, ana, note(ana, 1))
      :ok = Mentions.file(c.site, ana, note(ana, 1, %{"content" => "Again"}))

      assert [%Mention{content: "Hello @timon"}] = Repo.all(Mention)
    end

    test "keeps the other accounts it names", c do
      ana = remote_account_fixture()
      carl = "https://other.example/users/carl"

      tags = [
        %{"type" => "Mention", "href" => @account},
        %{"type" => "Mention", "href" => ana.uri},
        %{"type" => "Mention", "href" => carl},
        %{"type" => "Mention", "href" => carl},
        %{"type" => "Mention", "href" => "http://insecure.example/users/dan"},
        %{"type" => "Hashtag", "href" => "https://other.example/tags/hakuna"}
      ]

      :ok = Mentions.file(c.site, ana, note(ana, 1, %{"tag" => tags}))

      assert [%Mention{named_accounts: [^carl]}] = Repo.all(Mention)
    end

    test "refuses an object whose text takes more than 100 KB, also in an Update", c do
      ana = remote_account_fixture()
      too_large = String.duplicate("a", 100_001)

      :ok = Mentions.file(c.site, ana, note(ana, 1, %{"content" => too_large}))
      assert count(c.site) == 0

      at_most = %{"content" => String.duplicate("a", 99_990), "summary" => "Spoiler"}
      :ok = Mentions.file(c.site, ana, note(ana, 2, at_most))
      :ok = Mentions.update(c.site, ana, note(ana, 2, %{at_most | "summary" => "Long spoiler"}))

      assert [%Mention{summary: "Spoiler"}] = Repo.all(Mention)
    end

    test "dates a mention from the future at its arrival", c do
      ana = remote_account_fixture()

      :ok = Mentions.file(c.site, ana, note(ana, 1, %{"published" => "2099-01-01T00:00:00Z"}))

      assert [%Mention{published_at: published_at}] = Repo.all(Mention)
      assert DateTime.diff(DateTime.utc_now(), published_at) < 5
    end
  end

  describe "the Mentions of a site" do
    test "lists them newest first, all or the private messages only", c do
      old = mention_fixture(c.site, published_at: ~U[2026-10-01 10:00:00Z])
      private = mention_fixture(c.site, visibility: :direct)
      _other_site = mention_fixture(fediverse_site_fixture())

      assert %{entries: [first, second], total_entries: 2} =
               Fediverse.paginate_mentions(c.scope, 1, :all)

      assert {first.id, second.id} == {private.id, old.id}
      assert first.remote_account.uri == private.remote_account.uri

      assert %{entries: [%Mention{id: id}]} = Fediverse.paginate_mentions(c.scope, 1, :private)
      assert id == private.id
    end

    test "counts the unread ones until they are marked read", c do
      first = mention_fixture(c.site)
      _second = mention_fixture(c.site)
      other_site = fediverse_scope_fixture(%{domain: "pumbaa.blog"})
      other = mention_fixture(other_site.site)

      assert Fediverse.count_unread_mentions(c.scope) == 2

      :ok = Fediverse.mark_mentions_read(c.scope, [first, other])

      assert Fediverse.count_unread_mentions(c.scope) == 1
      assert Fediverse.count_unread_mentions(other_site) == 1
    end
  end

  describe "approval" do
    setup c do
      target = deployment_target_fixture(c.scope)
      post = post_fixture(c.scope, %{title: "Hakuna matata"})

      ana =
        remote_account_fixture(%{
          name: "Ana",
          handle: "@ana@mastodon.example",
          picture_url: @picture_url
        })

      %{target: target, post: post, ana: ana}
    end

    defp serve_picture(body) do
      test_pid = self()

      Req.Test.stub(Feather.Fediverse, fn conn ->
        send(test_pid, {:fetched, "https://#{conn.host}#{conn.request_path}"})
        send_resp(conn, 200, body)
      end)
    end

    defp reply(c, attrs \\ %{}),
      do: mention_fixture(c.site, Map.merge(%{remote_account: c.ana, post_id: c.post.id}, attrs))

    defp approve(c, mention),
      do: Fediverse.approve_reply(c.scope, mention, Mention.version(mention))

    defp public_reply_object(c, mention, attrs) do
      Map.merge(
        %{
          "id" => mention.uri,
          "type" => "Note",
          "attributedTo" => c.ana.uri,
          "inReplyTo" => Fediverse.post_url(c.site, c.post),
          "content" => "<p>Edited</p>",
          "to" => [@public]
        },
        attrs
      )
    end

    defp picture_kept?(name), do: File.regular?(Pictures.path(name))

    defp unused_until_deploy?(c, name),
      do: picture_kept?(name) and name in Pictures.unused(c.site)

    test "approving a public reply keeps its author's picture and starts a deploy", c do
      serve_picture(test_image_binary(200, 160, ".jpg"))
      mention = reply(c, %{content: "Nice <b>post</b>"})

      assert mention.approval == :waiting
      assert {:ok, approved} = approve(c, mention)

      assert_received {:fetched, @picture_url}
      assert_received {:deploy_requested, %{id: target_id}}
      assert target_id == c.target.id

      assert %Mention{
               approval: :approved,
               approved_content: "Nice <b>post</b>",
               approved_name: "Ana",
               approved_handle: "@ana@mastodon.example",
               approved_picture: picture
             } = approved

      assert picture_kept?(picture)

      {:ok, {image, _flags}} = Operation.webpload(Pictures.path(picture))
      assert {Image.width(image), Image.height(image)} == {96, 96}
    end

    test "the site shows the snapshot of the approval, not a later profile", c do
      serve_picture(test_image_binary())
      {:ok, approved} = approve(c, reply(c))
      c.ana |> Ecto.Changeset.change(name: "Ana Renamed") |> Repo.update!()

      post_id = c.post.id
      assert %{^post_id => [shown]} = Fediverse.approved_replies(c.site, [c.post])

      assert {shown.id, shown.approved_name} == {approved.id, "Ana"}
      assert shown.remote_account.uri == c.ana.uri
    end

    defp kept_pictures do
      case File.ls(Path.join([Feather.Media.storage_root(), "fediverse", "pictures"])) do
        {:ok, names} -> MapSet.new(names)
        {:error, :enoent} -> MapSet.new()
      end
    end

    # Runs `meanwhile` while the author's picture downloads.
    defp serve_picture_meanwhile(meanwhile) do
      Req.Test.stub(Feather.Fediverse, fn conn ->
        meanwhile.()
        send_resp(conn, 200, test_image_binary())
      end)
    end

    test "a reply deleted while it is approved is not approved, and its picture not kept", c do
      mention = reply(c)
      kept = kept_pictures()
      serve_picture_meanwhile(fn -> :ok = Mentions.delete(c.site, c.ana, mention.uri) end)

      assert approve(c, mention) == {:error, :changed}

      refute Repo.reload(mention)
      assert kept_pictures() == kept
      refute_received {:deploy_requested, _target}
    end

    test "of two approvals at once, the later one keeps neither its picture nor the other's", c do
      mention = reply(c)
      kept = kept_pictures()

      serve_picture_meanwhile(fn ->
        {:ok, picture} = Pictures.put(test_image_binary())

        mention
        |> Mention.approval_changeset(:approved, %{approved_picture: picture})
        |> Repo.update!()
      end)

      assert approve(c, mention) == {:error, :changed}

      assert %Mention{approval: :approved, approved_picture: picture} = Repo.reload!(mention)
      assert MapSet.difference(kept_pictures(), kept) == MapSet.new([picture])
      refute_received {:deploy_requested, _target}
    end

    test "a reply that changed since the member saw it is not approved", c do
      serve_picture(test_image_binary())
      seen = reply(c)

      :ok = Mentions.update(c.site, c.ana, public_reply_object(c, seen, %{}))
      changed = Repo.reload!(seen)

      assert Fediverse.approve_reply(c.scope, changed, Mention.version(seen)) ==
               {:error, :changed}

      assert %Mention{approval: :waiting, content: "Edited"} = Repo.reload!(seen)
      refute_received {:fetched, _url}
      refute_received {:deploy_requested, _target}
    end

    test "approving an approved reply again replaces its picture, the old one after a deploy",
         c do
      serve_picture(test_image_binary())
      approved = approved_reply_fixture(c.site, c.post, remote_account: c.ana)

      assert {:ok, %Mention{approved_picture: picture}} = approve(c, approved)

      assert picture != approved.approved_picture
      assert picture_kept?(picture)
      assert unused_until_deploy?(c, approved.approved_picture)
    end

    test "a site without a deployment target deletes a picture it no longer uses at once" do
      scope = fediverse_scope_fixture(%{domain: "pumbaa.blog"})
      approved = approved_reply_fixture(scope.site, post_fixture(scope))

      {:ok, _hidden} = Fediverse.hide_reply(scope, approved)

      refute picture_kept?(approved.approved_picture)
      assert Pictures.unused(scope.site) == []
    end

    test "a reply whose author's name, handle or picture changed since the member saw it is not approved",
         c do
      for change <- [
            [name: "Buy pills"],
            [handle: "@pills@mastodon.example"],
            [picture_url: "https://files.mastodon.example/pills.png"]
          ] do
        ana = remote_account_fixture(%{name: "Ana", picture_url: @picture_url})
        seen = reply(c, %{remote_account: ana})
        ana |> Ecto.Changeset.change(change) |> Repo.update!()

        assert Fediverse.approve_reply(c.scope, Repo.reload!(seen), Mention.version(seen)) ==
                 {:error, :changed}

        assert Repo.reload!(seen).approval == :waiting
      end

      refute_received {:deploy_requested, _target}
    end

    test "an author who changed since their account was cached is not approved as cached", c do
      stale = DateTime.add(DateTime.utc_now(), -25, :hour)
      ana = Repo.update!(Ecto.Changeset.change(c.ana, name: "Ana Old", fetched_at: stale))
      seen = reply(c, %{remote_account: ana})
      serve_remote_accounts([{"ana@mastodon.example", ana.uri}])

      assert approve(c, seen) == {:error, :changed}
      refute_received {:fediverse_request, "GET", @picture_url, _body}

      assert %{name: "Ana", picture_url: nil} = Repo.reload!(ana)
      assert {:ok, %Mention{approved_name: "Ana"}} = approve(c, Mentions.get!(c.scope, seen.id))
    end

    test "approves a reply without a picture when its author's picture cannot be kept", c do
      serve_picture("<svg xmlns=\"http://www.w3.org/2000/svg\"/>")

      assert {:ok, %Mention{approval: :approved, approved_picture: nil}} =
               approve(c, reply(c))
    end

    test "a reply that is not public, or a mention that answers no post, cannot be approved", c do
      for mention <- [
            reply(c, %{visibility: :followers}),
            reply(c, %{visibility: :direct}),
            mention_fixture(c.site, remote_account: c.ana)
          ] do
        assert approve(c, mention) == {:error, :not_approvable}
        assert Repo.reload!(mention).approval == :waiting
      end

      refute_received {:deploy_requested, _target}
    end

    test "hiding takes an approved reply off the site with a deploy, its picture after it", c do
      approved = approved_reply_fixture(c.site, c.post)
      waiting = reply(c)

      assert {:ok, %Mention{approval: :hidden, approved_picture: nil}} =
               Fediverse.hide_reply(c.scope, approved)

      assert unused_until_deploy?(c, approved.approved_picture)
      assert_received {:deploy_requested, _target}

      assert {:ok, %Mention{approval: :hidden}} = Fediverse.hide_reply(c.scope, waiting)
      refute_received {:deploy_requested, _target}
      assert Fediverse.approved_replies(c.site, [c.post]) == %{}
    end

    test "approving changes no post and so is not reported to IndexNow and archive.org", c do
      serve_picture(test_image_binary())
      since = DateTime.utc_now()

      {:ok, _approved} = approve(c, reply(c))

      assert Notifications.changed_urls(Repo.reload!(c.site), since, DateTime.utc_now()) == []
    end

    test "an Update returns an approved reply to waiting; the site keeps it until the next deploy",
         c do
      approved = approved_reply_fixture(c.site, c.post, remote_account: c.ana)

      :ok = Mentions.update(c.site, c.ana, public_reply_object(c, approved, %{}))

      assert %Mention{
               approval: :waiting,
               content: "Edited",
               approved_content: nil,
               approved_picture: nil
             } = Repo.reload!(approved)

      assert unused_until_deploy?(c, approved.approved_picture)
      refute_received {:deploy_requested, _target}
    end

    test "an Update that makes an approved reply private takes it off the site at once", c do
      approved = approved_reply_fixture(c.site, c.post, remote_account: c.ana)
      followers_only = public_reply_object(c, approved, %{"to" => [c.ana.uri <> "/followers"]})

      :ok =
        Mentions.update(
          c.site,
          %{c.ana | followers_url: c.ana.uri <> "/followers"},
          followers_only
        )

      assert %Mention{approval: :waiting, visibility: :followers} = Repo.reload!(approved)
      assert_received {:deploy_requested, _target}
    end

    test "a Delete removes an approved reply, deploys and leaves a tombstone", c do
      approved = approved_reply_fixture(c.site, c.post, remote_account: c.ana)

      :ok = Mentions.delete(c.site, c.ana, approved.uri)

      refute Repo.reload(approved)
      assert unused_until_deploy?(c, approved.approved_picture)
      assert_received {:deploy_requested, _target}
      assert Repo.get_by(Tombstone, site_id: c.site.id, uri: approved.uri)

      :ok = Mentions.file(c.site, c.ana, public_reply_object(c, approved, %{}))
      assert count(c.site) == 0
    end

    test "deleting a waiting mention deploys nothing", c do
      waiting = reply(c)

      :ok = Mentions.delete(c.site, c.ana, waiting.uri)

      refute Repo.reload(waiting)
      refute_received {:deploy_requested, _target}
    end

    test "the deletion of an author removes their mentions, the sites showing one deploy", c do
      approved = approved_reply_fixture(c.site, c.post, remote_account: c.ana)
      other_scope = fediverse_scope_fixture(%{domain: "pumbaa.blog"})
      _other = mention_fixture(other_scope.site, remote_account: c.ana)

      :ok = Mentions.delete_by_author(c.ana)

      assert Repo.aggregate(from(m in Mention, where: m.remote_account_id == ^c.ana.id), :count) ==
               0

      assert unused_until_deploy?(c, approved.approved_picture)
      assert_received {:deploy_requested, %{id: target_id}}
      assert target_id == c.target.id
      refute_received {:deploy_requested, _target}
    end

    test "lists the approved public replies of the given posts, oldest first", c do
      other_post = post_fixture(c.scope)
      newer = approved_reply_fixture(c.site, c.post, published_at: ~U[2026-10-02 10:00:00Z])
      older = approved_reply_fixture(c.site, c.post, published_at: ~U[2026-10-01 10:00:00Z])
      _waiting = reply(c)
      _other_post = approved_reply_fixture(c.site, other_post)

      assert %{} = replies = Fediverse.approved_replies(c.site, [c.post])
      assert Map.keys(replies) == [c.post.id]
      assert Enum.map(replies[c.post.id], & &1.id) == [older.id, newer.id]
    end

    test "the waiting filter lists the public replies that wait for approval", c do
      waiting = reply(c)
      _approved = approved_reply_fixture(c.site, c.post)
      _followers_only = reply(c, %{visibility: :followers})
      _mention = mention_fixture(c.site)

      assert %{entries: [%Mention{id: id}]} = Fediverse.paginate_mentions(c.scope, 1, :waiting)
      assert id == waiting.id
    end
  end
end
