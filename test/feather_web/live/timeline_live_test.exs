defmodule FeatherWeb.TimelineLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Accounts.Scope
  alias Feather.{Fediverse, Repo}
  alias Feather.Fediverse.{Blocks, FollowedAccount, MemberReply, Timeline, TimelinePost}

  @moduletag :capture_log

  @public "https://www.w3.org/ns/activitystreams#Public"

  setup [:register_and_log_in_user, :create_site_for_user, :make_account]

  defp make_account(%{scope: scope}) do
    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
    :ok = Fediverse.record_online(site, DateTime.utc_now())
    site = Repo.reload!(site)

    ana =
      remote_account_fixture(%{
        uri: "https://example.social/users/ana",
        inbox: "https://example.social/users/ana/inbox",
        name: "Ana",
        handle: "@ana@example.social",
        picture_url: "https://files.example.social/ana.png"
      })

    %{
      site: site,
      scope: Scope.put_site(scope, site),
      ana: ana,
      followed: followed_account_fixture(site, remote_account: ana)
    }
  end

  defp timeline_path(site), do: ~p"/sites/#{site.public_id}/timeline"

  defp listed_ids(lv) do
    lv
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#timeline > li")
    |> LazyHTML.attribute("id")
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

  defp serve(lv, pictures) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      url = "https://#{conn.host}#{conn.request_path}"
      send(test_pid, {:fediverse_request, conn.method, url, body})

      case Map.fetch(pictures, url) do
        {:ok, picture} -> Plug.Conn.send_resp(conn, 200, picture)
        :error -> Plug.Conn.send_resp(conn, 202, "")
      end
    end)

    if lv, do: Req.Test.allow(Feather.Fediverse, self(), lv.pid)
  end

  # Holds every request to a fediverse server until the test sends :go to the process that made it.
  defp hold_requests(lv) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:requesting, self()})

      receive do
        :go -> Plug.Conn.send_resp(conn, 202, "")
      end
    end)

    Req.Test.allow(Feather.Fediverse, self(), lv.pid)
  end

  defp delivered(inbox) do
    receive do
      {:fediverse_request, "POST", ^inbox, body} -> Jason.decode!(body)
    after
      0 -> nil
    end
  end

  test "the navigation leads to the Timeline, which leads to the followed accounts",
       %{conn: conn, site: site} do
    follower_fixture(site)
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, ~s(nav[aria-label=Main] a[href="#{timeline_path(site)}"]), "Timeline")

    {:ok, lv, _html} = live(conn, timeline_path(site))

    assert has_element?(lv, "#timeline-stats", "1 following")
    assert has_element?(lv, "#timeline-stats", "1 follower")

    assert has_element?(
             lv,
             ~s(#timeline-stats a[href="/sites/#{site.public_id}/following"]),
             "Manage"
           )
  end

  test "follows several handles at once and says which could not be followed",
       %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, timeline_path(site))
    serve_remote_accounts(["bob@example.social", "cleo@micro.example"])
    Req.Test.allow(Feather.Fediverse, self(), lv.pid)

    lv
    |> form("#follow-form",
      follow: %{
        handles: "@bob@example.social\ncleo@micro.example, @manton @nobody@example.social"
      }
    )
    |> render_submit()

    render_async(lv)

    assert %{"type" => "Follow"} = delivered("https://example.social/users/bob/inbox")
    assert %{"type" => "Follow"} = delivered("https://micro.example/users/cleo/inbox")

    uris =
      FollowedAccount
      |> Repo.all()
      |> Repo.preload(:remote_account)
      |> Enum.map(& &1.remote_account.uri)
      |> Enum.sort()

    assert uris == [
             "https://example.social/users/ana",
             "https://example.social/users/bob",
             "https://micro.example/users/cleo"
           ]

    assert has_element?(lv, "#follow-failures", "@manton")
    assert has_element?(lv, "#follow-failures", "@nobody@example.social")
    refute has_element?(lv, "#follow-failures", "@bob@example.social")
    assert render(lv) =~ "Followed 2 accounts."

    assert lv |> element("#follow-form textarea") |> render() =~
             "@manton\n@nobody@example.social"

    assert has_element?(lv, ~s(#follow-dialog[data-show="true"]))
  end

  test "follows in a dialog the header's button opens, which closes when all were followed",
       %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, timeline_path(site))
    serve_remote_accounts(["bob@example.social"])
    Req.Test.allow(Feather.Fediverse, self(), lv.pid)

    refute has_element?(lv, ~s(#follow-dialog[data-show="true"]))

    lv |> element("#open-follow") |> render_click()
    assert has_element?(lv, ~s(#follow-dialog[data-show="true"]))

    lv |> form("#follow-form", follow: %{handles: "@bob@example.social"}) |> render_submit()
    render_async(lv)

    assert has_element?(lv, ~s(#follow-dialog[data-show="false"]))
    refute has_element?(lv, "#follow-failures")

    lv |> element("#open-follow") |> render_click()
    assert has_element?(lv, ~s(#follow-dialog[data-show="true"]))

    render_hook(lv, "close_follow", %{})
    assert has_element?(lv, ~s(#follow-dialog[data-show="false"]))
  end

  test "shows the posts newest first and new ones as they come",
       %{conn: conn, site: site, ana: ana, followed: followed} do
    older = timeline_post_fixture(followed, published_at: ~U[2026-10-01 10:00:00Z])

    newer =
      timeline_post_fixture(followed,
        name: "Hakuna <b>matata</b>",
        content: ~s(No worries <a href="https://e.example/">link</a>)
      )

    {:ok, lv, _html} = live(conn, timeline_path(site))

    assert listed_ids(lv) == ["timeline-post-#{newer.id}", "timeline-post-#{older.id}"]
    id = "#timeline-post-#{newer.id}"
    assert has_element?(lv, id <> "-author", "Ana")
    assert has_element?(lv, id <> "-author", "@ana@example.social")
    assert has_element?(lv, id <> "-name", "Hakuna <b>matata</b>")
    assert has_element?(lv, ~s(#{id}-content a[href="https://e.example/"][rel~="ugc"]), "link")

    :ok = Timeline.file(site, ana, note(1))

    live_post = Repo.get_by!(TimelinePost, uri: note(1)["id"])

    assert hd(listed_ids(lv)) == "timeline-post-#{live_post.id}"
    assert has_element?(lv, "#timeline-post-#{live_post.id}-content", "Note 1")

    :ok = Timeline.update(site, ana, note(1, %{"content" => "<p>Edited</p>"}))
    assert has_element?(lv, "#timeline-post-#{live_post.id}-content", "Edited")

    :ok = Timeline.delete(site, ana, note(1)["id"])
    refute has_element?(lv, "#timeline-post-#{live_post.id}")
  end

  test "keeps the first page at its size as new posts come",
       %{conn: conn, site: site, ana: ana, followed: followed} do
    [oldest | _newer] =
      for minute <- 1..20,
          do:
            timeline_post_fixture(followed,
              published_at: DateTime.add(~U[2026-10-01 10:00:00Z], minute, :minute)
            )

    {:ok, lv, _html} = live(conn, timeline_path(site))
    assert length(listed_ids(lv)) == 20

    :ok = Timeline.file(site, ana, note(1))

    live_post = Repo.get_by!(TimelinePost, uri: note(1)["id"])
    ids = listed_ids(lv)
    assert length(ids) == 20
    assert hd(ids) == "timeline-post-#{live_post.id}"
    refute "timeline-post-#{oldest.id}" in ids

    :ok =
      Timeline.update(site, ana, %{
        "id" => oldest.uri,
        "type" => "Note",
        "content" => "<p>Edited</p>",
        "to" => [@public]
      })

    refute "timeline-post-#{oldest.id}" in listed_ids(lv)
  end

  test "says so when its last post goes", %{conn: conn, site: site, ana: ana} do
    {:ok, lv, _html} = live(conn, timeline_path(site))
    assert has_element?(lv, "#no-timeline-posts")

    :ok = Timeline.file(site, ana, note(1))
    refute has_element?(lv, "#no-timeline-posts")

    :ok = Timeline.delete(site, ana, note(1)["id"])
    assert has_element?(lv, "#no-timeline-posts")
  end

  test "loads the pictures of the posts and their authors through the CMS",
       %{conn: conn, user: user, site: site, followed: followed} do
    png = test_image_binary(8, 8)

    post =
      timeline_post_fixture(followed,
        attachments: [
          %{
            "url" => "https://files.example.social/1.png",
            "media_type" => "image/png",
            "name" => "A cat"
          },
          %{
            "url" => "https://files.example.social/1.mp4",
            "media_type" => "video/mp4",
            "name" => "A clip"
          }
        ]
      )

    {:ok, lv, _html} = live(conn, timeline_path(site))

    picture = "/sites/#{site.public_id}/timeline/#{post.public_id}/pictures/0"
    portrait = "/sites/#{site.public_id}/following/#{followed.public_id}/picture"
    id = "#timeline-post-#{post.id}"

    assert has_element?(lv, ~s(#{id} img[src="#{picture}"][alt="A cat"]))
    assert has_element?(lv, ~s(#{id} img[src="#{portrait}"]))
    assert has_element?(lv, ~s(#{id} a[href="https://files.example.social/1.mp4"]), "A clip")
    refute render(lv) =~ "https://files.example.social/1.png"
    refute render(lv) =~ "https://files.example.social/ana.png"

    serve(nil, %{
      "https://files.example.social/1.png" => png,
      "https://files.example.social/ana.png" => "<script>alert(1)</script>"
    })

    response = get(conn, picture)
    assert response(response, 200) == png
    assert get_resp_header(response, "content-type") == ["image/png"]
    assert get_resp_header(response, "cache-control") == ["private, max-age=86400"]
    assert get_resp_header(response, "x-content-type-options") == ["nosniff"]

    assert get_resp_header(response, "content-security-policy") == [
             FeatherWeb.ContentSecurityPolicy.header()
           ]

    assert response(get(conn, portrait), 404)

    assert response(
             get(conn, "/sites/#{site.public_id}/timeline/#{post.public_id}/pictures/-1"),
             404
           )

    other_site = site_fixture(user)
    other_picture = "/sites/#{other_site.public_id}/timeline/#{post.public_id}/pictures/0"
    assert response(get(conn, other_picture), 404)
  end

  test "the pictures of a site without a fediverse name are not found",
       %{conn: conn, user: user, scope: scope, ana: ana} do
    scope = Scope.put_site(scope, site_fixture(user))
    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "pumbaa"})
    followed = followed_account_fixture(site, remote_account: ana)

    post =
      timeline_post_fixture(followed,
        attachments: [%{"url" => "https://files.example.social/1.png", "name" => "A cat"}]
      )

    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => ""})

    assert response(
             get(conn, "/sites/#{site.public_id}/timeline/#{post.public_id}/pictures/0"),
             404
           )

    assert response(
             get(conn, "/sites/#{site.public_id}/following/#{followed.public_id}/picture"),
             404
           )
  end

  test "replies to a post", %{conn: conn, site: site, followed: followed} do
    post = timeline_post_fixture(followed)
    id = "#timeline-post-#{post.id}"

    {:ok, lv, _html} = live(conn, timeline_path(site))
    serve(lv, %{})

    assert has_element?(lv, id <> "-reply-audience", "Public")
    assert has_element?(lv, id <> "-reply-audience", "@ana@example.social")

    lv |> form(id <> "-reply-form", reply: %{content: "Thank you, Ana!"}) |> render_submit()
    render_async(lv)

    assert_receive {:fediverse_request, "POST", "https://example.social/users/ana/inbox", body}
    assert %{"type" => "Create", "object" => %{"inReplyTo" => in_reply_to}} = Jason.decode!(body)
    assert in_reply_to == post.uri

    [reply] = Repo.all(MemberReply)
    assert has_element?(lv, "#member-reply-#{reply.id}", "Thank you, Ana!")
  end

  test "sends a reply in the background, its button busy until it went out",
       %{conn: conn, site: site, followed: followed} do
    post = timeline_post_fixture(followed)
    id = "#timeline-post-#{post.id}"

    {:ok, lv, _html} = live(conn, timeline_path(site))
    hold_requests(lv)

    lv |> form(id <> "-reply-form", reply: %{content: "Thank you, Ana!"}) |> render_submit()

    assert_receive {:requesting, request}
    assert has_element?(lv, id <> "-reply-form button[type=submit][disabled]")
    assert has_element?(lv, id <> "-reply-content", "Thank you, Ana!")

    send(request, :go)
    assert render_async(lv) =~ "Reply sent."
    refute has_element?(lv, id <> "-reply-form button[type=submit][disabled]")
    refute has_element?(lv, id <> "-reply-content", "Thank you, Ana!")
  end

  test "names everyone a reply to a followers-only post goes to",
       %{conn: conn, site: site, followed: followed} do
    bob = remote_account_fixture(%{handle: "@bob@example.social"})
    post = timeline_post_fixture(followed, %{visibility: :followers, named_accounts: [bob.uri]})

    {:ok, lv, _html} = live(conn, timeline_path(site))

    assert has_element?(
             lv,
             "#timeline-post-#{post.id}-reply-audience",
             "Private: goes only to @ana@example.social and @bob@example.social."
           )
  end

  test "blocks the author of a post", %{conn: conn, site: site, followed: followed, ana: ana} do
    post = timeline_post_fixture(followed)

    {:ok, lv, _html} = live(conn, timeline_path(site))
    serve(lv, %{})

    html =
      confirm_click(
        lv,
        "#timeline-post-#{post.id}-menu-block-account",
        "Block @ana@example.social?"
      )

    assert html =~ "Blocked @ana@example.social."
    assert has_element?(lv, "#no-timeline-posts")
    assert has_element?(lv, "#timeline-stats", "0 following")
    assert Blocks.blocked?(site, ana.uri)
  end

  test "says when there is nothing yet", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, timeline_path(site))

    assert has_element?(lv, "#no-timeline-posts", "Nothing here yet")
  end
end
