defmodule Feather.StaticSite.ExportRepliesTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Accounts.Scope
  alias Feather.Fediverse
  alias Feather.Fediverse.Mention
  alias Feather.StaticSite.{Export, Preview, RecordingSink, Routes}

  @themes ["feather", "simple_sidebar"]
  @rel "nofollow ugc noopener"

  defp export(scope) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink
  end

  defp page(sink, path), do: LazyHTML.from_document(RecordingSink.get(sink, path))

  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

  defp attribute(doc, selector, name),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

  defp none?(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.empty?()

  defp thread(theme, attrs \\ %{}) do
    domain = String.replace(theme, "_", "-") <> ".blog"
    scope = fediverse_scope_fixture(Map.merge(%{domain: domain, theme: theme}, attrs))
    post = post_fixture(scope, %{title: "Hello", slug: "/hello"})
    quiet = post_fixture(scope, %{title: "Quiet", slug: "/quiet"})

    later =
      approved_reply_fixture(scope.site, post,
        picture: false,
        remote_account: remote_account_fixture(%{name: "Bob"}),
        content: "Me too",
        published_at: ~U[2026-10-12 09:00:00Z]
      )

    first =
      approved_reply_fixture(scope.site, post,
        content: ~s(Nice! <a href="https://e.example/">A link</a>),
        url: "https://mastodon.example/@ana/1",
        published_at: ~U[2026-10-11 09:00:00Z]
      )

    mention_fixture(scope.site, post_id: post.id, content: "Waiting for approval")

    {:ok, _hidden} =
      Fediverse.hide_reply(
        scope,
        mention_fixture(scope.site, post_id: post.id, content: "Hidden")
      )

    %{scope: scope, post: post, quiet: quiet, first: first, later: later}
  end

  describe "a site with a fediverse name" do
    test "shows the approved replies in a thread below the post, in both themes" do
      for theme <- @themes do
        c = thread(theme)
        sink = export(c.scope)
        doc = page(sink, "hello/index.html")
        picture = "images/replies/" <> c.first.approved_picture

        assert text(doc, "#replies h2") == "Replies", theme

        assert [first, later] =
                 doc |> LazyHTML.query("#replies .reply-list > li") |> Enum.to_list()

        assert attribute(first, "img.reply-picture", "src") == ["/" <> picture]
        assert RecordingSink.get(sink, picture), theme
        assert text(first, ".reply-author") == "Ana"

        assert attribute(first, "a.reply-handle", "href") == [c.first.remote_account.uri]
        assert attribute(first, "a.reply-handle", "rel") == [@rel]
        assert text(first, "a.reply-handle") == "@ana@mastodon.example"

        assert attribute(first, "a.reply-date", "href") == ["https://mastodon.example/@ana/1"]
        assert attribute(first, "a.reply-date time", "datetime") == ["2026-10-11"]
        assert attribute(first, ~s(.reply-content a[href="https://e.example/"]), "rel") == [@rel]
        assert text(first, ".reply-content") == "Nice! A link"

        assert none?(later, "img")
        assert attribute(later, "a.reply-author", "href") == [c.later.remote_account.uri]
        assert text(later, "a.reply-author") == "Bob"
        assert text(later, ".reply-content") == "Me too"

        refute text(doc, "#replies") =~ "Waiting for approval"
        refute text(doc, "#replies") =~ "Hidden"
      end
    end

    test "shows a reply with its author's picture from the deploy its approval starts" do
      scope = fediverse_scope_fixture(%{domain: "timon.blog"})
      deployment_target_fixture(scope)
      post = post_fixture(scope, %{title: "Hello", slug: "/hello"})

      ana =
        remote_account_fixture(%{
          name: "Ana",
          handle: "@ana@mastodon.example",
          picture_url: "https://files.mastodon.example/ana.png"
        })

      reply = mention_fixture(scope.site, remote_account: ana, post_id: post.id, content: "Hi!")
      Req.Test.stub(Feather.Fediverse, &send_resp(&1, 200, test_image_binary(64, 64, ".png")))

      refute text(page(export(scope), "hello/index.html"), "#replies") =~ "Hi!"

      {:ok, approved} = Fediverse.approve_reply(scope, reply, Mention.version(reply))
      assert_received {:deploy_requested, _target}

      sink = export(scope)
      doc = page(sink, "hello/index.html")

      assert text(doc, "#replies .reply-content") == "Hi!"
      assert text(doc, "#replies .reply-handle") == "@ana@mastodon.example"
      assert RecordingSink.get(sink, "images/replies/" <> approved.approved_picture)
    end

    test "tells readers how to reply, on a post without replies too, in both themes" do
      for theme <- @themes do
        %{scope: scope} = thread(theme)
        handle = Fediverse.handle(scope.site)
        sink = export(scope)

        for path <- ["hello/index.html", "quiet/index.html"] do
          doc = page(sink, path)

          assert text(doc, "#replies .replies-invitation") ==
                   "To reply from the fediverse, follow #{handle} " <>
                     "or look up the address of this post from your account.",
                 "#{theme} #{path}"

          assert text(doc, "#replies .replies-invitation strong") == handle
        end

        assert none?(page(sink, "quiet/index.html"), "#replies .reply-list")
      end
    end

    test "tells it in the site's language" do
      sink = export(thread("feather", %{language_code: "de"}).scope)
      doc = page(sink, "quiet/index.html")

      assert text(doc, "#replies h2") == "Antworten"
      assert text(doc, "#replies .replies-invitation") =~ "Antworten aus dem Fediverse"
    end

    test "keeps the replies and the line off the Markdown alternate, the feed and llms.txt" do
      sink = export(thread("feather").scope)

      for path <- ["hello/index.md", "index.md", "feed.xml", "llms.txt"] do
        content = RecordingSink.get(sink, path)

        refute content =~ "Nice!", path
        refute content =~ "To reply from the fediverse", path
      end
    end

    test "loads the pictures from the site, as its content security policy demands" do
      for theme <- @themes do
        doc = page(export(thread(theme).scope), "hello/index.html")

        assert [src] = attribute(doc, "#replies img", "src")
        assert src =~ ~r"\A/images/replies/[0-9A-Za-z]{12}\.webp\z"
      end
    end
  end

  describe "markup from the fediverse" do
    test "renders inert on the exported site and in the preview, in both themes" do
      name = ~s{<b>Ana</b><script>alert(1)</script>}
      handle = ~s{@<img src="x" onerror="alert(2)">@mastodon.example}

      content =
        ~s{<script>alert(3)</script><img src="x" onerror="alert(4)">} <>
          ~s{<a href="javascript:alert(5)" onclick="alert(6)">Nice</a>}

      for theme <- @themes do
        c = thread(theme)
        author = remote_account_fixture(%{name: name, handle: handle})

        approved_reply_fixture(c.scope.site, c.post,
          picture: false,
          remote_account: author,
          content: content,
          published_at: ~U[2026-10-13 09:00:00Z]
        )

        {:html, preview} = Preview.render(c.scope.site, "hello")

        for doc <- [
              page(export(c.scope), "hello/index.html"),
              LazyHTML.from_document(IO.iodata_to_binary(preview))
            ] do
          shown = doc |> LazyHTML.query("#replies .reply-list > li") |> Enum.at(2)

          assert text(shown, ".reply-author") == name, theme
          assert text(shown, ".reply-handle") == handle, theme
          assert text(shown, ".reply-content") == "Nice", theme

          for selector <- [
                "script",
                "b",
                "img",
                "[onerror]",
                "[onclick]",
                ~s(a[href^="javascript"])
              ],
              do: assert(none?(shown, selector), "#{theme} #{selector}")
        end
      end
    end
  end

  describe "members' replies" do
    test "show in the thread, marked as by the author, indented below the reply they answer" do
      for theme <- @themes do
        c = thread(theme)
        answer = member_reply_fixture(c.first, "Thank you, Ana!\nHakuna matata.")
        doc = page(export(c.scope), "hello/index.html")

        assert [first, later] =
                 doc |> LazyHTML.query("#replies .reply-list > li") |> Enum.to_list()

        assert [shown] = first |> LazyHTML.query(".reply-answers > li") |> Enum.to_list()

        assert LazyHTML.attribute(shown, "id") == ["reply-#{answer.public_id}"], theme
        assert text(shown, ".reply-author") == c.scope.site.title
        assert text(shown, ".reply-badge") == "Author"
        assert attribute(shown, "a.reply-date", "href") == ["#reply-#{answer.public_id}"]
        assert text(shown, ".reply-content") == "Thank you, Ana!Hakuna matata."
        refute none?(shown, ".reply-content br")
        assert none?(later, ".reply-answers")
      end
    end

    test "show the site's portrait as the author's picture" do
      c = thread("simple_sidebar")
      portrait = test_image_path(600, 600)
      {:ok, site} = Feather.Sites.put_portrait(c.scope, portrait, "me.png")
      File.rm(portrait)
      member_reply_fixture(c.first)

      sink = export(Scope.put_site(c.scope, site))
      doc = page(sink, "hello/index.html")

      assert [src] = attribute(doc, "#replies .reply-answers img.reply-picture", "src")
      assert RecordingSink.get(sink, String.trim_leading(src, "/"))
    end

    test "say in the site's language that they are by the author" do
      c = thread("feather", %{language_code: "de"})
      member_reply_fixture(c.first)

      doc = page(export(c.scope), "hello/index.html")

      assert text(doc, "#replies .reply-badge") == "Autor"
    end

    test "show only below replies the site shows, and only while they are not deleted" do
      c = thread("feather")
      waiting = mention_fixture(c.scope.site, post_id: c.post.id)
      private = mention_fixture(c.scope.site, post_id: c.post.id, visibility: :direct)
      member_reply_fixture(waiting, "To a waiting reply")
      member_reply_fixture(private, "To a private reply")

      c.first
      |> member_reply_fixture("Deleted")
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
      |> Repo.update!()

      doc = page(export(c.scope), "hello/index.html")

      assert none?(doc, "#replies .reply-answers")
      refute text(doc, "#replies") =~ "To a"
    end

    test "point to their place in the thread only while the thread shows the reply they answer" do
      c = thread("feather")
      shown = member_reply_fixture(c.first, "Shown")
      to_waiting = member_reply_fixture(mention_fixture(c.scope.site, post_id: c.post.id))
      {:ok, hidden} = Fediverse.hide_reply(c.scope, c.later)
      to_hidden = member_reply_fixture(hidden)

      sink = export(c.scope)

      document =
        &(sink |> RecordingSink.get("activitypub/replies/#{&1.public_id}") |> Jason.decode!())

      assert document.(shown)["url"] == "/hello/#reply-#{shown.public_id}"
      refute Map.has_key?(document.(to_waiting), "url")
      refute Map.has_key?(document.(to_hidden), "url")
    end

    test "each public one has a document, the others none" do
      c = thread("feather")
      public = member_reply_fixture(c.first, "Thank you!")
      elsewhere = member_reply_fixture(mention_fixture(c.scope.site), "Hi")
      private = member_reply_fixture(mention_fixture(c.scope.site, visibility: :direct), "Psst")

      deleted =
        c.later
        |> member_reply_fixture("Deleted")
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
        |> Repo.update!()

      sink = export(c.scope)
      path = &"activitypub/replies/#{&1.public_id}"

      document = sink |> RecordingSink.get(path.(public)) |> Jason.decode!()

      assert document["id"] == "/" <> path.(public)
      assert document["type"] == "Note"
      assert document["inReplyTo"] == c.first.uri
      assert document["url"] == "/hello/#reply-#{public.public_id}"
      assert document["content"] == "<p>Thank you!</p>"

      refute "url" in Map.keys(sink |> RecordingSink.get(path.(elsewhere)) |> Jason.decode!())
      refute RecordingSink.exists?(sink, path.(private))
      refute RecordingSink.exists?(sink, path.(deleted))
    end
  end

  describe "a site without a fediverse name" do
    test "shows neither the replies nor the line" do
      for theme <- @themes do
        c = thread(theme, %{online: false})
        {:ok, site} = Fediverse.update_name(c.scope, %{"fediverse_name" => ""})
        sink = export(Scope.put_site(c.scope, site))

        assert none?(page(sink, "hello/index.html"), "#replies"), theme
        refute RecordingSink.get(sink, "images/replies/" <> c.first.approved_picture)
      end
    end
  end

  describe "the preview" do
    test "serves the pictures of the replies the site shows, and only those" do
      c = thread("feather")
      other = thread("feather", %{domain: "pumbaa.blog"})
      hidden = approved_reply_fixture(c.scope.site, c.post)
      picture = hidden.approved_picture
      {:ok, %Mention{}} = Fediverse.hide_reply(c.scope, hidden)

      assert {:file, path, "image/webp"} =
               Preview.render(c.scope.site, "images/replies/" <> c.first.approved_picture)

      assert File.regular?(path)

      for name <- [picture, other.first.approved_picture, "../../etc/passwd"] do
        assert {:not_found, _page} = Preview.render(c.scope.site, "images/replies/" <> name)
      end

      assert {:html, html} = Preview.render(c.scope.site, "hello")
      assert IO.iodata_to_binary(html) =~ "/preview/#{c.scope.site.public_id}/images/replies/"
    end
  end
end
