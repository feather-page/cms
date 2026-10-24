defmodule FeatherWeb.MentionLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import Plug.Conn

  alias Feather.Accounts.Scope
  alias Feather.{Content, Fediverse, Repo}
  alias Feather.Fediverse.{MemberReply, Mention, Mentions, Pictures}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp make_account(%{scope: scope}) do
    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => "timon"})
    %{site: site, scope: Scope.put_site(scope, site)}
  end

  defp mentions_path(site), do: ~p"/sites/#{site.public_id}/mentions"

  defp nav_entry(site), do: ~s(nav[aria-label=Main] a[href="#{mentions_path(site)}"])

  # Deliveries wait until a deploy has put the account online.
  defp capture_deliveries(lv, site) do
    :ok = Fediverse.record_online(site, DateTime.utc_now())
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = read_body(conn)
      send(test_pid, {:delivered, conn.host, Jason.decode!(body)})
      send_resp(conn, 202, "")
    end)

    Req.Test.allow(Feather.Fediverse, self(), lv.pid)
  end

  # Holds every request to a fediverse server until the test sends :go to the process that made it.
  defp hold_requests(lv) do
    test_pid = self()

    Req.Test.stub(Feather.Fediverse, fn conn ->
      send(test_pid, {:requesting, self()})

      receive do
        :go -> send_resp(conn, 202, "")
      end
    end)

    Req.Test.allow(Feather.Fediverse, self(), lv.pid)
  end

  # The background work requests the deploy and ends before it would receive the request.
  defp trace_deploy_requests(lv), do: :erlang.trace(lv.pid, true, [:send, :set_on_spawn])

  defp listed_ids(lv) do
    lv
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#mentions > li")
    |> LazyHTML.attribute("id")
  end

  test "a site without a fediverse name has no Fediverse section", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    refute has_element?(lv, nav_entry(site))
  end

  describe "Mentions" do
    setup :make_account

    test "the navigation counts the unread mentions", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      assert has_element?(lv, nav_entry(site), "Mentions")
      refute has_element?(lv, nav_entry(site) <> " span.tabular-nums")

      for _n <- 1..2, do: mention_fixture(site)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

      assert has_element?(lv, nav_entry(site) <> " span.tabular-nums", "2")
    end

    test "lists them newest first, marks them new and then read",
         %{conn: conn, site: site, scope: scope} do
      older = mention_fixture(site, published_at: ~U[2026-10-01 10:00:00Z])
      newer = mention_fixture(site)

      {:ok, lv, _html} = live(conn, mentions_path(site))

      assert listed_ids(lv) == ["mention-#{newer.id}", "mention-#{older.id}"]
      assert has_element?(lv, "#mention-#{newer.id}-author", "New")
      assert has_element?(lv, nav_entry(site), "Mentions")
      refute has_element?(lv, nav_entry(site) <> " span.tabular-nums")
      assert Fediverse.count_unread_mentions(scope) == 0

      {:ok, lv, _html} = live(conn, mentions_path(site))
      refute has_element?(lv, "#mention-#{newer.id}-author", "New")
    end

    test "shows the author, the post it answers and the content",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, %{title: "Hakuna matata"})

      ana =
        remote_account_fixture(%{
          name: "Ana <b>A</b>",
          handle: "@ana@mastodon.example"
        })

      mention =
        mention_fixture(site,
          remote_account: ana,
          post_id: post.id,
          content: ~s|Nice! <a href="https://e.example/">link</a><script>alert(1)</script>|,
          url: "https://mastodon.example/@ana/1"
        )

      {:ok, lv, _html} = live(conn, mentions_path(site))
      id = "#mention-#{mention.id}"

      assert has_element?(lv, id <> "-author", "Ana <b>A</b>")
      assert has_element?(lv, id <> "-author", "@ana@mastodon.example")
      refute has_element?(lv, id <> "-author b")

      assert has_element?(
               lv,
               ~s(#{id}-post a[href="/sites/#{site.public_id}/posts/#{post.public_id}/edit"]),
               "Hakuna matata"
             )

      assert has_element?(lv, ~s(#{id}-content a[href="https://e.example/"][rel~="ugc"]), "link")
      refute has_element?(lv, id <> "-content script")
      assert has_element?(lv, ~s(#{id} a[href="https://mastodon.example/@ana/1"]))
    end

    test "shows a content warning and the alt texts of attachments as text",
         %{conn: conn, site: site} do
      mention =
        mention_fixture(site,
          visibility: :direct,
          summary: "Spoiler <i>ahead</i>",
          attachments: [
            %{
              "url" => "https://files.example/a.png",
              "media_type" => "image/png",
              "name" => "A <b>cat</b>"
            }
          ]
        )

      {:ok, lv, _html} = live(conn, mentions_path(site))
      id = "#mention-#{mention.id}"

      assert has_element?(lv, id <> "-summary summary", "Spoiler <i>ahead</i>")
      refute has_element?(lv, id <> "-summary summary i")

      assert has_element?(
               lv,
               ~s(#{id}-summary a[href="https://files.example/a.png"]),
               "A <b>cat</b>"
             )

      assert has_element?(lv, id <> "-author", "Private message")
    end

    test "filters the private messages", %{conn: conn, site: site} do
      public = mention_fixture(site)
      private = mention_fixture(site, visibility: :direct)

      {:ok, lv, _html} = live(conn, mentions_path(site))

      lv |> element("#mention-filter a", "Private messages") |> render_click()

      assert_patch(lv, mentions_path(site) <> "?filter=private")
      assert listed_ids(lv) == ["mention-#{private.id}"]

      lv |> element("#mention-filter a", "All") |> render_click()
      assert listed_ids(lv) == ["mention-#{private.id}", "mention-#{public.id}"]
    end

    test "approves and hides a public reply to a post, each with a deploy",
         %{conn: conn, site: site, scope: scope} do
      target_id = deployment_target_fixture(scope).id
      post = post_fixture(scope, %{title: "Hakuna matata"})
      reply = mention_fixture(site, post_id: post.id)
      private = mention_fixture(site, post_id: post.id, visibility: :direct)
      mention = mention_fixture(site)
      id = "#mention-#{reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      trace_deploy_requests(lv)

      assert has_element?(lv, id <> "-approval", "Waiting for approval")
      refute has_element?(lv, "#mention-#{private.id}-approval")
      refute has_element?(lv, "#mention-#{mention.id}-approval")

      lv |> element(id <> "-approve") |> render_click()
      render_async(lv)

      assert has_element?(lv, id <> "-approval", "Approved")
      refute has_element?(lv, id <> "-approve")
      assert Repo.reload!(reply).approval == :approved
      assert_receive {:trace, _pid, :send, {:deploy_requested, %{id: ^target_id}}, _to}

      lv |> element(id <> "-hide") |> render_click()

      assert has_element?(lv, id <> "-approval", "Hidden")
      assert has_element?(lv, id <> "-approve")
      refute has_element?(lv, id <> "-hide")
      assert Repo.reload!(reply).approval == :hidden
      assert_receive {:trace, _pid, :send, {:deploy_requested, %{id: ^target_id}}, _to}
    end

    test "hides an approved reply whose post was deleted, and its picture goes",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope)
      reply = approved_reply_fixture(site, post)
      {:ok, _post} = Content.delete_post(scope, post)
      picture = Pictures.path(reply.approved_picture)
      id = "#mention-#{reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))

      assert has_element?(lv, id <> "-approval", "Approved")
      refute has_element?(lv, id <> "-approve")

      lv |> element(id <> "-hide") |> render_click()

      assert Repo.reload!(reply).approval == :hidden
      refute File.exists?(picture)
      refute has_element?(lv, id <> "-approval")
    end

    test "approves a reply only as the member saw it", %{conn: conn, site: site, scope: scope} do
      deployment_target_fixture(scope)
      reply = mention_fixture(site, post_id: post_fixture(scope).id, content: "Nice post")
      id = "#mention-#{reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      reply |> Ecto.Changeset.change(content: "Buy pills") |> Repo.update!()

      lv |> element(id <> "-approve") |> render_click()

      assert render_async(lv) =~ "This reply has changed since you saw it."
      assert Repo.reload!(reply).approval == :waiting
      assert has_element?(lv, id <> "-content", "Buy pills")

      lv |> element(id <> "-approve") |> render_click()
      render_async(lv)
      assert Repo.reload!(reply).approval == :approved
    end

    test "before approval, shows the author's picture approving keeps, loaded through the CMS",
         %{conn: conn, user: user, site: site, scope: scope} do
      post = post_fixture(scope)
      ana = remote_account_fixture(%{picture_url: "https://files.mastodon.example/ana.png"})
      waiting = mention_fixture(site, post_id: post.id, remote_account: ana)
      approved = approved_reply_fixture(site, post, remote_account: ana, picture: false)
      message = mention_fixture(site, remote_account: ana, visibility: :direct)

      {:ok, lv, _html} = live(conn, mentions_path(site))

      picture =
        "/sites/#{site.public_id}/mentions/#{waiting.public_id}/picture?v=#{Mention.version(waiting)}"

      assert has_element?(lv, ~s(#mention-#{waiting.id}-picture[src="#{picture}"]))
      refute has_element?(lv, "#mention-#{approved.id}-picture")
      refute has_element?(lv, "#mention-#{message.id}-picture")
      refute render(lv) =~ "files.mastodon.example"

      png = test_image_binary(8, 8)
      Req.Test.stub(Feather.Fediverse, fn conn -> send_resp(conn, 200, png) end)

      response = get(conn, picture)
      assert response(response, 200) == png
      assert get_resp_header(response, "content-type") == ["image/png"]

      other_site = site_fixture(user)
      other_picture = "/sites/#{other_site.public_id}/mentions/#{waiting.public_id}/picture"
      assert response(get(conn, other_picture), 404)
    end

    test "approves a reply only with the author's name and picture the member saw",
         %{conn: conn, site: site, scope: scope} do
      deployment_target_fixture(scope)
      ana = remote_account_fixture(%{name: "Ana"})
      reply = mention_fixture(site, post_id: post_fixture(scope).id, remote_account: ana)
      id = "#mention-#{reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      ana |> Ecto.Changeset.change(name: "Buy pills") |> Repo.update!()

      lv |> element(id <> "-approve") |> render_click()

      assert render_async(lv) =~ "This reply has changed since you saw it."
      assert Repo.reload!(reply).approval == :waiting
      assert has_element?(lv, id <> "-author", "Buy pills")

      lv |> element(id <> "-approve") |> render_click()
      render_async(lv)
      assert %Mention{approval: :approved, approved_name: "Buy pills"} = Repo.reload!(reply)
    end

    test "approves in the background, its button busy until it is done",
         %{conn: conn, site: site, scope: scope} do
      deployment_target_fixture(scope)
      ana = remote_account_fixture(%{picture_url: "https://files.mastodon.example/ana.png"})
      reply = mention_fixture(site, post_id: post_fixture(scope).id, remote_account: ana)
      id = "#mention-#{reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      hold_requests(lv)

      lv |> element(id <> "-approve") |> render_click()

      assert_receive {:requesting, request}
      assert has_element?(lv, id <> "-approve[disabled]")

      send(request, :go)
      assert render_async(lv) =~ "Reply approved."
      assert has_element?(lv, id <> "-approval", "Approved")
    end

    test "filters the replies waiting for approval", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope)
      waiting = mention_fixture(site, post_id: post.id)
      _approved = approved_reply_fixture(site, post, picture: false)
      _mention = mention_fixture(site)

      {:ok, lv, _html} = live(conn, mentions_path(site))

      lv |> element("#mention-filter a", "Waiting") |> render_click()

      assert_patch(lv, mentions_path(site) <> "?filter=waiting")
      assert listed_ids(lv) == ["mention-#{waiting.id}"]

      {:ok, _hidden} = Fediverse.hide_reply(scope, waiting)
      {:ok, lv, _html} = live(conn, mentions_path(site) <> "?filter=waiting")
      assert has_element?(lv, "#no-mentions", "No replies waiting for approval")
    end

    test "under the Waiting filter, approved and hidden replies leave the list",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope)
      to_approve = mention_fixture(site, post_id: post.id)
      to_hide = mention_fixture(site, post_id: post.id)

      {:ok, lv, _html} = live(conn, mentions_path(site) <> "?filter=waiting")

      lv |> element("#mention-#{to_approve.id}-approve") |> render_click()
      render_async(lv)
      assert listed_ids(lv) == ["mention-#{to_hide.id}"]

      lv |> element("#mention-#{to_hide.id}-hide") |> render_click()
      assert listed_ids(lv) == []
    end

    test "replies to a public reply in public, with a deploy",
         %{conn: conn, site: site, scope: scope} do
      target_id = deployment_target_fixture(scope).id
      post = post_fixture(scope, %{title: "Hakuna matata"})
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      reply = approved_reply_fixture(site, post, remote_account: ana, picture: false)
      id = "#mention-#{reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      capture_deliveries(lv, site)
      trace_deploy_requests(lv)

      assert has_element?(lv, id <> "-reply-audience", "Public")
      assert has_element?(lv, id <> "-reply-audience", "post's thread")

      lv
      |> form(id <> "-reply-form", reply: %{content: "Thank you, Ana!"})
      |> render_submit()

      render_async(lv)

      assert_receive {:delivered, "mastodon.example", %{"type" => "Create", "object" => note}}
      assert note["content"] == "<p>Thank you, Ana!</p>"
      assert note["to"] == ["https://www.w3.org/ns/activitystreams#Public"]
      assert_receive {:trace, _pid, :send, {:deploy_requested, %{id: ^target_id}}, _to}

      [member_reply] = Repo.all(MemberReply)
      assert has_element?(lv, "#member-reply-#{member_reply.id}", "Thank you, Ana!")
      assert has_element?(lv, "#member-reply-#{member_reply.id}", "Public")
    end

    test "replies to a private message only to its sender, without a deploy",
         %{conn: conn, site: site, scope: scope} do
      deployment_target_fixture(scope)
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      message = mention_fixture(site, remote_account: ana, visibility: :direct)
      id = "#mention-#{message.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      capture_deliveries(lv, site)
      trace_deploy_requests(lv)

      assert has_element?(lv, id <> "-reply-audience", "Private")
      assert has_element?(lv, id <> "-reply-audience", "@ana@mastodon.example")

      lv |> form(id <> "-reply-form", reply: %{content: "Psst"}) |> render_submit()
      render_async(lv)

      assert_receive {:delivered, "mastodon.example", %{"to" => [to]}}
      assert to == ana.uri
      refute_receive {:trace, _pid, :send, {:deploy_requested, _target}, _to}

      [member_reply] = Repo.all(MemberReply)
      assert has_element?(lv, "#member-reply-#{member_reply.id}", "Private")
    end

    test "sends a reply in the background, its button busy until it went out",
         %{conn: conn, site: site} do
      message = mention_fixture(site, visibility: :direct)
      id = "#mention-#{message.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      :ok = Fediverse.record_online(site, DateTime.utc_now())
      hold_requests(lv)

      lv |> form(id <> "-reply-form", reply: %{content: "Psst"}) |> render_submit()

      assert_receive {:requesting, request}
      assert has_element?(lv, id <> "-reply-form button[type=submit][disabled]")
      assert has_element?(lv, id <> "-reply-content", "Psst")

      send(request, :go)
      assert render_async(lv) =~ "Reply sent."
      refute has_element?(lv, id <> "-reply-form button[type=submit][disabled]")
      refute has_element?(lv, id <> "-reply-content", "Psst")
    end

    test "names everyone a private reply goes to", %{conn: conn, site: site} do
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      bob = remote_account_fixture(%{handle: "@bob@mastodon.example"})
      carl = "https://other.example/users/carl"

      message =
        mention_fixture(site,
          remote_account: ana,
          visibility: :direct,
          named_accounts: [bob.uri, carl]
        )

      {:ok, lv, _html} = live(conn, mentions_path(site))

      assert has_element?(
               lv,
               "#mention-#{message.id}-reply-audience",
               "Private: goes only to @ana@mastodon.example, @bob@mastodon.example and #{carl}."
             )
    end

    test "says when a reply is empty and sends nothing", %{conn: conn, site: site} do
      mention = mention_fixture(site)

      {:ok, lv, _html} = live(conn, mentions_path(site))
      capture_deliveries(lv, site)

      lv
      |> form("#mention-#{mention.id}-reply-form", reply: %{content: "  "})
      |> render_submit()

      assert render_async(lv) =~ "Write a reply first."
      refute_receive {:delivered, _host, _activity}
      assert Repo.all(MemberReply) == []
    end

    test "deletes a member's reply", %{conn: conn, site: site} do
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      message = mention_fixture(site, remote_account: ana, visibility: :direct)
      member_reply = member_reply_fixture(message, "Psst")
      id = "#member-reply-#{member_reply.id}"

      {:ok, lv, _html} = live(conn, mentions_path(site))
      capture_deliveries(lv, site)

      assert has_element?(lv, id, "Psst")

      confirm_click(lv, id <> "-delete", "Delete this reply?")

      assert_receive {:delivered, "mastodon.example", %{"type" => "Delete"}}
      refute has_element?(lv, id)
      assert Repo.all(MemberReply) == []
    end

    defp listed_replies(lv) do
      lv
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#my-replies > li")
      |> LazyHTML.attribute("id")
    end

    test "lists the members' replies under My replies, also those whose mention is gone",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, %{title: "Hakuna matata"})
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      public = member_reply_fixture(mention_fixture(site, remote_account: ana, post_id: post.id))
      followed = followed_account_fixture(site, remote_account: ana)
      to_post = followed |> timeline_post_fixture() |> member_reply_fixture()
      gone = mention_fixture(site, remote_account: ana, visibility: :direct)
      orphan = member_reply_fixture(gone, "Psst")
      :ok = Mentions.delete(site, ana, gone.uri)

      {:ok, lv, _html} = live(conn, mentions_path(site))
      lv |> element("#mention-filter a", "My replies") |> render_click()

      assert_patch(lv, mentions_path(site) <> "?filter=replies")

      assert Enum.sort(listed_replies(lv)) ==
               Enum.sort(Enum.map([public, to_post, orphan], &"my-reply-#{&1.id}"))

      id = "#my-reply-#{public.id}"
      assert has_element?(lv, id <> "-meta", "Public")
      assert has_element?(lv, id <> "-answered", "Reply to @ana@mastodon.example in Mentions")

      assert has_element?(
               lv,
               ~s(#{id}-post a[href="/sites/#{site.public_id}/posts/#{post.public_id}/edit"]),
               "Hakuna matata"
             )

      assert has_element?(lv, "#my-reply-#{to_post.id}-answered", "in the Timeline")

      id = "#my-reply-#{orphan.id}"
      assert has_element?(lv, id <> "-meta", "Private")
      assert has_element?(lv, id <> "-answered", "no longer in the CMS")
      assert has_element?(lv, id <> "-content", "Psst")
      assert has_element?(lv, ~s(#{id} a[href="#{gone.uri}"]))
    end

    test "deletes a reply under My replies, a public one with a deploy first",
         %{conn: conn, site: site, scope: scope} do
      target_id = deployment_target_fixture(scope).id
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      post = post_fixture(scope)
      public = member_reply_fixture(mention_fixture(site, remote_account: ana, post_id: post.id))
      gone = mention_fixture(site, remote_account: ana, visibility: :direct)
      private = member_reply_fixture(gone, "Psst")
      :ok = Mentions.delete(site, ana, gone.uri)

      {:ok, lv, _html} = live(conn, mentions_path(site) <> "?filter=replies")
      capture_deliveries(lv, site)
      trace_deploy_requests(lv)

      confirm_click(lv, "#my-reply-#{private.id}-delete", "Delete this reply?")

      assert_receive {:delivered, "mastodon.example", %{"type" => "Delete"}}
      refute Repo.reload(private)
      assert listed_replies(lv) == ["my-reply-#{public.id}"]

      confirm_click(lv, "#my-reply-#{public.id}-delete", "Delete this reply?")

      assert_receive {:trace, _pid, :send, {:deploy_requested, %{id: ^target_id}}, _to}
      assert Repo.reload!(public).deleted_at
      assert has_element?(lv, "#no-replies")
    end

    test "blocks the author of a mention", %{conn: conn, site: site} do
      ana = remote_account_fixture(%{handle: "@ana@mastodon.example"})
      follower_fixture(site, ana)
      mention = mention_fixture(site, remote_account: ana)
      other = mention_fixture(site)

      {:ok, lv, _html} = live(conn, mentions_path(site))
      capture_deliveries(lv, site)

      html =
        confirm_click(
          lv,
          "#mention-#{mention.id}-menu-block-account",
          "Block @ana@mastodon.example?"
        )

      assert html =~ "Blocked @ana@mastodon.example."
      assert_receive {:delivered, "mastodon.example", %{"type" => "Block", "object" => object}}
      assert object == ana.uri
      assert listed_ids(lv) == ["mention-#{other.id}"]
      assert Fediverse.count_followers(Scope.for_site(site)) == 0
    end

    test "blocks the server of a mention's author", %{conn: conn, site: site} do
      mention = mention_fixture(site)
      _same_server = mention_fixture(site)

      {:ok, lv, _html} = live(conn, mentions_path(site))

      html =
        confirm_click(lv, "#mention-#{mention.id}-menu-block-server", "Block mastodon.example?")

      assert html =~ "Blocked mastodon.example."
      assert has_element?(lv, "#no-mentions")
    end

    test "says when there are none", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, mentions_path(site))

      assert has_element?(lv, "#no-mentions", "No mentions yet")
      assert has_element?(lv, "#no-mentions", "@timon@#{site.domain}")
    end
  end
end
