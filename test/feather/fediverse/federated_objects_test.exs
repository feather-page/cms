defmodule Feather.Fediverse.FederatedObjectsTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Accounts.Scope
  alias Feather.{Content, Fediverse, Media, Sites}
  alias Feather.StaticSite.{Export, FileSink, Routes}

  @moduletag :tmp_dir
  @moduletag :capture_log

  @activity_streams "https://www.w3.org/ns/activitystreams"
  @public "https://www.w3.org/ns/activitystreams#Public"
  @account "https://timon.blog/activitypub/timon"
  @inboxes ["mastodon.example/inbox", "micro.example/cleo/inbox"]

  setup %{tmp_dir: tmp_dir} do
    scope = site_scope_fixture(%{domain: "timon.blog", title: "Timon's Blog"})
    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
    :ok = Fediverse.record_online(site, DateTime.utc_now())
    site = Repo.reload!(site)

    for {uri, inbox, shared_inbox} <- [
          {"https://mastodon.example/users/ana", "https://mastodon.example/users/ana/inbox",
           "https://mastodon.example/inbox"},
          {"https://mastodon.example/users/bob", "https://mastodon.example/users/bob/inbox",
           "https://mastodon.example/inbox"},
          {"https://micro.example/cleo", "https://micro.example/cleo/inbox", nil}
        ] do
      account =
        remote_account_fixture(%{
          uri: uri,
          key_id: uri <> "#main-key",
          inbox: inbox,
          shared_inbox: shared_inbox
        })

      follower_fixture(site, account)
    end

    capture_deliveries()
    %{scope: Scope.put_site(scope, site), tmp_dir: tmp_dir}
  end

  defp capture_deliveries do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      send(test_pid, {:delivered, conn.host <> conn.request_path, Jason.decode!(body)})
      send_resp(conn, 202, "")
    end)
  end

  # As a deploy does once its upload succeeded: export, then compare with the federated objects.
  defp deploy(c, opts \\ []) do
    site = Repo.reload!(c.scope.site)
    sink = FileSink.new(c.tmp_dir)
    routes = Routes.new(site, canonical_url: "https://timon.blog/")
    :ok = Export.run(site, routes, sink, opts)
    :ok = Fediverse.federate(site, FileSink.dir(sink))
    FileSink.dir(sink)
  end

  defp document(dir, path), do: dir |> Path.join(path) |> File.read!() |> Jason.decode!()

  defp post_document(dir, post), do: document(dir, "activitypub/posts/#{post.public_id}")

  defp delivered do
    receive do
      {:delivered, inbox, activity} -> [{inbox, activity} | delivered()]
    after
      0 -> []
    end
  end

  # The one activity every follower received, once per shared inbox.
  defp delivered_to_all do
    deliveries = delivered()
    assert deliveries |> Enum.map(&elem(&1, 0)) |> Enum.sort() == @inboxes
    assert [activity] = deliveries |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
    activity
  end

  defp later?(time, than) do
    {:ok, time, 0} = DateTime.from_iso8601(time)
    {:ok, than, 0} = DateTime.from_iso8601(than)
    DateTime.after?(time, than)
  end

  defp not_before?(time, than) do
    {:ok, time, 0} = DateTime.from_iso8601(time)
    {:ok, than, 0} = DateTime.from_iso8601(than)
    not DateTime.before?(time, than)
  end

  defp short_post(scope, text, attrs \\ %{}),
    do: post_fixture(scope, Map.merge(%{title: "", slug: nil, content: [paragraph(text)]}, attrs))

  test "the deploy that puts the account online sends nothing: earlier posts are not sent", c do
    short_post(c.scope, "Before I joined.")

    deploy(c)
    assert delivered() == []

    deploy(c)
    assert delivered() == []
  end

  test "a post goes out with the deploy that puts it on the site, in a Create", c do
    deploy(c)
    post = short_post(c.scope, "Hakuna matata.")
    assert delivered() == []

    dir = deploy(c)
    note = post_document(dir, post)

    assert delivered_to_all() == %{
             "@context" => @activity_streams,
             "id" => note["id"] <> "#create",
             "type" => "Create",
             "actor" => @account,
             "published" => note["published"],
             "to" => [@public],
             "object" => Map.delete(note, "@context")
           }

    deploy(c)
    assert delivered() == []
  end

  test "a post with a title goes out as an Article", c do
    deploy(c)
    post = post_fixture(c.scope, %{title: "Hello", slug: "/hello"})

    dir = deploy(c)

    assert %{"type" => "Create", "object" => %{"type" => "Article"} = article} =
             delivered_to_all()

    assert article == dir |> post_document(post) |> Map.delete("@context")
  end

  test "a scheduled post goes out with the first deploy after it became due", c do
    deploy(c)
    publish_at = DateTime.add(DateTime.utc_now(), 3600)
    post = short_post(c.scope, "Later.", %{publish_at: publish_at})

    deploy(c)
    assert delivered() == []

    dir = deploy(c, now: DateTime.add(publish_at, 60))
    assert %{"type" => "Create", "object" => note} = delivered_to_all()
    assert note["id"] == post_document(dir, post)["id"]
  end

  test "a changed post goes out in an Update of its document", c do
    post = short_post(c.scope, "First draft.")
    deploy(c)

    {:ok, post} = Content.update_post(c.scope, post, %{content: [paragraph("Second thoughts.")]})
    {:ok, post} = Content.publish(c.scope, post)
    dir = deploy(c)
    note = post_document(dir, post)

    assert %{
             "@context" => @activity_streams,
             "id" => id,
             "type" => "Update",
             "actor" => @account,
             "to" => [@public],
             "object" => object
           } = delivered_to_all()

    assert String.starts_with?(id, note["id"] <> "#updates/")
    assert Map.delete(object, "updated") == Map.drop(note, ["@context", "updated"])
    assert object["content"] =~ "Second thoughts."
    assert not_before?(object["updated"], note["updated"])

    deploy(c)
    assert delivered() == []
  end

  test "an edit without a new version goes out in an Update with a later updated", c do
    deploy(c)
    photo = image_fixture(c.scope, width: 1600, height: 1200)

    short_post(c.scope, "Look.", %{content: [paragraph("Look."), image_block(photo)]})
    deploy(c)
    assert %{"type" => "Create", "object" => created} = delivered_to_all()
    refute created["updated"]

    {:ok, photo} = Media.update_image_alt(c.scope, photo, %{alt: "A warthog"})
    deploy(c)

    assert %{
             "type" => "Update",
             "object" => %{"attachment" => [%{"name" => "A warthog"}]} = first
           } =
             delivered_to_all()

    assert later?(first["updated"], created["published"])

    {:ok, _photo} = Media.update_image_alt(c.scope, photo, %{alt: "A warthog in the grass"})
    deploy(c)
    assert %{"type" => "Update", "object" => second} = delivered_to_all()
    assert later?(second["updated"], first["updated"])

    deploy(c)
    assert delivered() == []
  end

  test "a removed post goes out in a Delete, once, and in a Create when it comes back", c do
    unpublished = short_post(c.scope, "Changed my mind.")
    deleted = short_post(c.scope, "Never mind.")
    deploy(c)

    {:ok, unpublished} = Content.unpublish(c.scope, unpublished)
    {:ok, _deleted} = Content.delete_post(c.scope, deleted)
    deploy(c)

    deletes = delivered()
    assert length(deletes) == 4

    for post <- [unpublished, deleted] do
      uri = "https://timon.blog/activitypub/posts/#{post.public_id}"

      delete = %{
        "@context" => @activity_streams,
        "id" => uri <> "#delete",
        "type" => "Delete",
        "actor" => @account,
        "to" => [@public],
        "object" => %{"id" => uri, "type" => "Tombstone"}
      }

      for inbox <- @inboxes, do: assert({inbox, delete} in deletes)
    end

    deploy(c)
    assert delivered() == []

    {:ok, _unpublished} = Content.publish(c.scope, unpublished)
    dir = deploy(c)

    assert %{"type" => "Create", "object" => note} = delivered_to_all()

    assert note ==
             dir
             |> document("activitypub/posts/#{unpublished.public_id}-2")
             |> Map.delete("@context")
  end

  test "a post back after its removal goes out under a new address, which later updates use",
       c do
    post = short_post(c.scope, "Here I am.")
    deploy(c)
    old_uri = "https://timon.blog/activitypub/posts/#{post.public_id}"
    new_uri = old_uri <> "-2"

    {:ok, post} = Content.unpublish(c.scope, post)
    deploy(c)
    assert %{"type" => "Delete", "object" => %{"id" => ^old_uri}} = delivered_to_all()

    {:ok, post} = Content.publish(c.scope, post)
    dir = deploy(c)

    assert %{"id" => create_id, "type" => "Create", "object" => %{"id" => ^new_uri}} =
             delivered_to_all()

    assert create_id == new_uri <> "#create"
    refute File.exists?(Path.join(dir, "activitypub/posts/#{post.public_id}"))
    assert document(dir, "activitypub/posts/#{post.public_id}-2")["id"] == new_uri

    assert [%{"object" => %{"id" => ^new_uri}}] =
             document(dir, "activitypub/outbox")["orderedItems"]

    page =
      dir
      |> Path.join("posts/#{String.downcase(post.public_id)}/index.html")
      |> File.read!()
      |> LazyHTML.from_document()

    assert page
           |> LazyHTML.query(~s(link[rel="alternate"][type="application/activity+json"]))
           |> LazyHTML.attribute("href") == [new_uri]

    {:ok, post} = Content.update_post(c.scope, post, %{content: [paragraph("Here again.")]})
    {:ok, post} = Content.publish(c.scope, post)
    deploy(c)
    assert %{"type" => "Update", "object" => %{"id" => ^new_uri}} = delivered_to_all()

    {:ok, post} = Content.unpublish(c.scope, post)
    deploy(c)
    assert %{"type" => "Delete", "object" => %{"id" => ^new_uri}} = delivered_to_all()

    {:ok, _post} = Content.publish(c.scope, post)
    deploy(c)
    newest_uri = old_uri <> "-3"
    assert %{"type" => "Create", "object" => %{"id" => ^newest_uri}} = delivered_to_all()
  end

  test "a deploy that only changes the theme sends nothing", c do
    photo = image_fixture(c.scope, width: 1600, height: 1200)
    cover = image_fixture(c.scope, width: 600, height: 900)
    book = book_fixture(c.scope, %{cover_image_id: cover.id})

    short_post(c.scope, "A picture and a book.", %{
      content: [
        paragraph("A picture and a book."),
        image_block(photo, "The grass"),
        %{"type" => "book", "book_public_id" => book.public_id}
      ]
    })

    deploy(c)

    {:ok, _site} = Sites.update_site(c.scope, c.scope.site, %{theme: "simple_sidebar"})
    deploy(c)

    assert delivered() == []
  end

  test "a changed profile goes out in an Update of the account", c do
    deploy(c)

    {:ok, _site} = Sites.update_site(c.scope, c.scope.site, %{bio: "Hakuna matata."})
    dir = deploy(c)
    account = document(dir, "activitypub/timon")

    assert %{"id" => id, "type" => "Update", "actor" => @account, "object" => object} =
             activity = delivered_to_all()

    assert activity["@context"] == account["@context"]
    assert String.starts_with?(id, @account <> "#updates/")
    assert object == Map.delete(account, "@context")
    assert object["summary"] == "<p>Hakuna matata.</p>"
  end

  test "an export whose account did not go online records and sends nothing", c do
    Repo.update_all(from(s in Sites.Site, where: s.id == ^c.scope.site.id),
      set: [fediverse_online_at: nil]
    )

    short_post(c.scope, "Nobody hears me.")
    deploy(c)

    assert delivered() == []
    assert Repo.all(Fediverse.FederatedObject) == []
  end
end
