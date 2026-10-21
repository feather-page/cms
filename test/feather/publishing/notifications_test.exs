defmodule Feather.Publishing.NotificationsTest do
  use Feather.DataCase

  alias Feather.{Content, Sites}
  alias Feather.Publishing.Notifications

  setup do
    scope = site_scope_fixture()
    %{scope: scope, root: "https://#{scope.site.domain}/"}
  end

  defp site(scope), do: Repo.reload!(scope.site)

  describe "changed_urls/3" do
    test "lists the home page and what was published or became due since", c do
      post_fixture(c.scope, %{slug: "/old"})
      post_fixture(c.scope, %{slug: "/scheduled", publish_at: in_seconds(5)})
      since = DateTime.utc_now()

      post_fixture(c.scope, %{slug: "/new"})
      page_fixture(c.scope, %{slug: "/about"})
      project_fixture(c.scope, %{slug: "/tool"})
      post_fixture(c.scope, %{slug: "/draft", draft: true})
      post_fixture(c.scope, %{slug: "/later", publish_at: in_seconds(3600)})
      homepage = Content.get_homepage(c.scope)
      {:ok, homepage} = Content.update_page(c.scope, homepage, %{content: [paragraph("Hi.")]})
      {:ok, _homepage} = Content.publish(c.scope, homepage)

      urls = Notifications.changed_urls(site(c.scope), since, DateTime.add(since, 10))

      assert urls == [
               c.root,
               c.root <> "scheduled/",
               c.root <> "new/",
               c.root <> "about/",
               c.root <> "projects/tool/"
             ]
    end

    test "leaves out what was published after the export started", c do
      since = DateTime.utc_now()
      post_fixture(c.scope, %{slug: "/before"})
      now = DateTime.utc_now()
      post_fixture(c.scope, %{slug: "/after"})

      assert Notifications.changed_urls(site(c.scope), since, now) == [
               c.root,
               c.root <> "before/"
             ]
    end

    test "is empty without changes, and the home page alone after a settings change", c do
      since = DateTime.utc_now()
      assert Notifications.changed_urls(site(c.scope), since, DateTime.utc_now()) == []

      {:ok, _site} = Sites.update_site(c.scope, c.scope.site, %{title: "Renamed"})
      assert Notifications.changed_urls(site(c.scope), since, DateTime.utc_now()) == [c.root]
    end

    test "lists the home page when the homepage changed", c do
      since = DateTime.utc_now()
      homepage = Content.get_homepage(c.scope)
      {:ok, homepage} = Content.update_page(c.scope, homepage, %{content: [paragraph("Hi.")]})
      {:ok, _homepage} = Content.publish(c.scope, homepage)

      assert Notifications.changed_urls(site(c.scope), since, DateTime.utc_now()) == [c.root]
    end

    test "lists everything published at the first deploy", c do
      post_fixture(c.scope, %{slug: "/one"})

      assert Notifications.changed_urls(site(c.scope), nil, DateTime.utc_now()) ==
               [c.root, c.root <> "one/"]
    end
  end

  describe "run/4" do
    setup do
      test = self()

      Req.Test.stub(Feather.IndexNow, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test, {:indexnow, Jason.decode!(body)["urlList"]})
        Plug.Conn.send_resp(conn, 200, "")
      end)

      Req.Test.stub(Feather.ArchiveOrg, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test, {:archive_org, URI.decode_query(body)["url"]})
        Req.Test.json(conn, %{"job_id" => "spn2-1"})
      end)

      :ok
    end

    test "sends nothing when nothing changed", c do
      assert Notifications.run(site(c.scope), DateTime.utc_now(), DateTime.utc_now()) == :ok
      refute_received {:indexnow, _urls}
    end

    test "logs keys that do not decrypt and still notifies IndexNow", c do
      Repo.query!("UPDATE sites SET archive_org_keys = ?1 WHERE id = ?2", [
        {:blob, <<1, 2, 3>>},
        c.scope.site.id
      ])

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert Notifications.run(site(c.scope), nil, DateTime.utc_now(),
                   archive_org_interval: 0
                 ) ==
                   :ok
        end)

      assert log =~ "its keys could not be loaded"
      assert_received {:indexnow, [_home]}
      refute_received {:archive_org, _url}
    end
  end

  defp in_seconds(seconds), do: DateTime.add(DateTime.utc_now(), seconds)
end
