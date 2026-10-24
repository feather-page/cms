defmodule Feather.StaticSite.ExportFediverseTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content, Encryption, Fediverse, Media, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @public "https://www.w3.org/ns/activitystreams#Public"
  @published_at ~U[2026-10-01 10:00:00.000000Z]

  defp fediverse_site(attrs \\ %{}) do
    scope =
      site_scope_fixture(
        Map.merge(
          %{
            domain: "timon.blog",
            title: "Timon's Blog",
            language_code: "de",
            bio: "I write.\r\nMostly short posts.\r\n\r\nTimon & Pumbaa."
          },
          attrs
        )
      )

    portrait = test_image_path(600, 600)
    {:ok, site} = Sites.put_portrait(scope, portrait, "me.png")
    File.rm(portrait)

    {:ok, site} =
      Fediverse.update_name(Scope.put_site(scope, site), %{"fediverse_name" => "timon"})

    Scope.put_site(scope, site)
  end

  defp export(scope) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    routes = Routes.new(scope.site, canonical_url: "https://#{scope.site.domain}/")
    :ok = Export.run(Repo.reload!(scope.site), routes, sink)
    sink
  end

  defp json(sink, path) do
    assert content = RecordingSink.get(sink, path), "#{path} missing"
    Jason.decode!(content)
  end

  defp path_of(url), do: String.replace_prefix(url, "https://timon.blog/", "")

  defp content(scope) do
    image = image_fixture(scope, width: 1600, height: 1200)
    {:ok, image} = Media.update_image_alt(scope, image, %{alt: "A warthog in the grass"})
    captioned = image_fixture(scope, width: 800, height: 600)

    short =
      post_fixture(scope, %{
        title: "",
        slug: nil,
        publish_at: @published_at,
        content: [
          paragraph("Hakuna <b>matata</b>."),
          image_block(image, "Ignored, the image has an alt text"),
          image_block(captioned, "A <i>meerkat</i>")
        ]
      })

    titled =
      post_fixture(scope, %{
        title: "Hello",
        slug: "/hello",
        description: "Why I say hello.",
        publish_at: DateTime.add(@published_at, 1, :day),
        content: [paragraph("Hello, world.")]
      })

    book = book_fixture(scope, %{title: "Dune", author: "Frank Herbert", read_at: ~D[2026-09-01]})

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{
        title: "",
        slug: "/dune",
        content: [paragraph("Loved it.")],
        publish_at: DateTime.add(@published_at, -1, :day)
      })

    {:ok, review} = Content.publish(scope, review)

    scheduled =
      post_fixture(scope, %{title: "Soon", publish_at: DateTime.add(DateTime.utc_now(), 3600)})

    page_fixture(scope, %{title: "About", slug: "/about"})
    project_fixture(scope, %{title: "CMS", slug: "/cms"})

    %{
      short: short,
      titled: titled,
      review: review,
      scheduled: scheduled,
      image: image,
      captioned: captioned
    }
  end

  describe "a site with a fediverse name" do
    setup do
      scope = fediverse_site()
      records = content(scope)
      Map.merge(records, %{scope: scope, sink: export(scope)})
    end

    test "answers every WebFinger query with the site's account", %{sink: sink} do
      assert json(sink, ".well-known/webfinger") == %{
               "subject" => "acct:timon@timon.blog",
               "aliases" => ["https://timon.blog/activitypub/timon"],
               "links" => [
                 %{
                   "rel" => "self",
                   "type" => "application/activity+json",
                   "href" => "https://timon.blog/activitypub/timon"
                 },
                 %{
                   "rel" => "http://webfinger.net/rel/profile-page",
                   "type" => "text/html",
                   "href" => "https://timon.blog/"
                 }
               ]
             }
    end

    test "writes the account with the site's title, bio and portrait and its inbox on the CMS",
         %{sink: sink, scope: scope} do
      site = scope.site |> Repo.reload!() |> Repo.preload(:portrait_image)
      account = json(sink, "activitypub/timon")

      assert account["@context"] == [
               "https://www.w3.org/ns/activitystreams",
               "https://w3id.org/security/v1"
             ]

      assert account["id"] == "https://timon.blog/activitypub/timon"
      assert account["type"] == "Person"
      assert account["preferredUsername"] == "timon"
      assert account["name"] == "Timon's Blog"

      assert account["summary"] ==
               "<p>I write.<br>Mostly short posts.</p><p>Timon &amp; Pumbaa.</p>"

      assert account["url"] == "https://timon.blog/"
      assert account["inbox"] == "http://localhost:4002/fediverse/inbox/#{site.public_id}"
      assert account["outbox"] == "https://timon.blog/activitypub/outbox"
      assert account["followers"] == "https://timon.blog/activitypub/followers"
      assert account["following"] == "https://timon.blog/activitypub/following"

      assert account["publicKey"] == %{
               "id" => "https://timon.blog/activitypub/timon#main-key",
               "owner" => "https://timon.blog/activitypub/timon",
               "publicKeyPem" => site.fediverse_public_key
             }

      assert %{"type" => "Image", "mediaType" => "image/jpeg", "url" => picture} = account["icon"]
      assert picture == "https://timon.blog/images/#{site.portrait_image.public_id}/400.jpg"
      assert {:copy, _original} = RecordingSink.get(sink, path_of(picture))
    end

    test "writes an outbox that lists the recent posts, newest first", c do
      outbox = json(c.sink, "activitypub/outbox")

      assert outbox["id"] == "https://timon.blog/activitypub/outbox"
      assert outbox["type"] == "OrderedCollection"
      assert outbox["totalItems"] == 3

      assert [titled, short, review] = outbox["orderedItems"]

      for {item, post} <- [{titled, c.titled}, {short, c.short}, {review, c.review}] do
        url = "https://timon.blog/activitypub/posts/#{post.public_id}"

        assert item["type"] == "Create"
        assert item["id"] == url <> "#create"
        assert item["actor"] == "https://timon.blog/activitypub/timon"
        assert item["to"] == [@public]
        assert item["object"]["id"] == url
        assert item["object"] == Map.delete(json(c.sink, path_of(url)), "@context")
      end
    end

    test "writes the followers with their number only", c do
      for _n <- 1..2, do: follower_fixture(c.scope.site)

      assert json(export(c.scope), "activitypub/followers") == %{
               "@context" => "https://www.w3.org/ns/activitystreams",
               "id" => "https://timon.blog/activitypub/followers",
               "type" => "OrderedCollection",
               "totalItems" => 2
             }
    end

    test "writes the accounts it follows with their number only, counting accepted follows",
         c do
      for _n <- 1..2, do: followed_account_fixture(c.scope.site)
      followed_account_fixture(c.scope.site, accepted: false)

      assert json(export(c.scope), "activitypub/following") == %{
               "@context" => "https://www.w3.org/ns/activitystreams",
               "id" => "https://timon.blog/activitypub/following",
               "type" => "OrderedCollection",
               "totalItems" => 2
             }
    end

    test "writes a short post as a Note with its images as attachments", c do
      url = "https://timon.blog/activitypub/posts/#{c.short.public_id}"
      note = json(c.sink, path_of(url))

      assert note["@context"] == "https://www.w3.org/ns/activitystreams"
      assert note["id"] == url
      assert note["type"] == "Note"
      assert note["attributedTo"] == "https://timon.blog/activitypub/timon"
      assert note["published"] == "2026-10-01T10:00:00Z"
      assert note["url"] == "https://timon.blog/posts/#{String.downcase(c.short.public_id)}/"
      assert note["to"] == [@public]
      assert note["content"] =~ "<p>Hakuna <b>matata</b>.</p>"
      refute note["content"] =~ "<img"
      assert note["contentMap"] == %{"de" => note["content"]}
      refute Map.has_key?(note, "name")
      refute Map.has_key?(note, "summary")
      refute Map.has_key?(note, "updated")

      assert [warthog, meerkat] = note["attachment"]

      assert %{"type" => "Image", "mediaType" => "image/webp", "name" => "A warthog in the grass"} =
               warthog

      assert warthog["url"] == "https://timon.blog/images/#{c.image.public_id}/1600.webp"
      assert meerkat["name"] == "A meerkat"
      assert meerkat["url"] == "https://timon.blog/images/#{c.captioned.public_id}/960.webp"

      for %{"url" => url} <- note["attachment"] do
        assert {:copy, _original} = RecordingSink.get(c.sink, path_of(url))
      end
    end

    test "writes a post with a title as an Article with its title, description and page", c do
      article = json(c.sink, "activitypub/posts/#{c.titled.public_id}")

      assert article["type"] == "Article"
      assert article["name"] == "Hello"
      assert article["summary"] == "Why I say hello."
      assert article["url"] == "https://timon.blog/hello/"
      assert article["content"] =~ "Hello, world."
      refute Map.has_key?(article, "attachment")
    end

    test "makes the links in a post's content absolute, like its Markdown alternate", c do
      post =
        post_fixture(c.scope, %{
          title: "Links",
          slug: "/links",
          publish_at: @published_at,
          content: [
            paragraph(
              ~s(See <a href="/about">about</a>, <a href="more">more</a> and <a href="#notes">notes</a>.)
            ),
            %{
              "type" => "list",
              "style" => "ul",
              "items" => [~s(<a href="mailto:timon@timon.blog">Mail</a>)]
            }
          ]
        })

      sink = export(c.scope)
      content = json(sink, "activitypub/posts/#{post.public_id}")["content"]

      assert content
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("a")
             |> LazyHTML.attribute("href") ==
               [
                 "https://timon.blog/about",
                 "https://timon.blog/links/more",
                 "https://timon.blog/links/#notes",
                 "mailto:timon@timon.blog"
               ]

      assert RecordingSink.get(sink, "links/index.md") =~ "(https://timon.blog/links/more)"
    end

    test "leaves code highlighting and diagram images out of a post's content", c do
      Feather.FakeChroma.install()
      Feather.FakeD2.install()

      post =
        post_fixture(c.scope, %{
          title: "Code",
          slug: "/code",
          publish_at: @published_at,
          content: [
            %{"type" => "code", "code" => "puts 1 < 2", "language" => "ruby"},
            %{"type" => "diagram", "code" => "a -> b", "caption" => "Flow"}
          ]
        })

      sink = export(c.scope)
      page = RecordingSink.get(sink, "code/index.html")
      assert page =~ Feather.FakeChroma.html("puts 1 < 2")
      assert page =~ ~s(src="/diagrams/)

      content = json(sink, "activitypub/posts/#{post.public_id}")["content"]

      assert content ==
               ~s(<pre data-language="ruby"><code class="language-ruby">puts 1 &lt; 2</code></pre>) <>
                 ~s(<pre data-language="d2"><code class="language-d2">a -&gt; b</code></pre>)
    end

    test "dates a post that was published again after its publication as updated", c do
      {:ok, titled} = Content.update_post(c.scope, c.titled, %{content: [paragraph("Hi.")]})
      {:ok, titled} = Content.publish(c.scope, titled)

      article = json(export(c.scope), "activitypub/posts/#{titled.public_id}")

      assert article["updated"] ==
               titled.published_version.published_at
               |> DateTime.truncate(:second)
               |> DateTime.to_iso8601()

      assert article["published"] == "2026-10-02T10:00:00Z"
    end

    test "writes the same documents in every theme", c do
      cover = image_fixture(c.scope, width: 600, height: 900)
      book = book_fixture(c.scope, %{title: "Emma", cover_image_id: cover.id})

      post_fixture(c.scope, %{
        title: "",
        slug: nil,
        publish_at: @published_at,
        content: [
          image_block(c.image, "Grass"),
          %{"type" => "book", "book_public_id" => book.public_id}
        ]
      })

      documents = fn sink ->
        for path <- RecordingSink.paths(sink),
            String.starts_with?(path, ["activitypub/", ".well-known/"]),
            into: %{},
            do: {path, RecordingSink.get(sink, path)}
      end

      before = documents.(export(c.scope))
      site = Repo.reload!(c.scope.site)
      {:ok, site} = Sites.update_site(c.scope, site, %{theme: "simple_sidebar"})

      assert documents.(export(Scope.put_site(c.scope, site))) == before
    end

    test "writes a document for every post that is due, reviews included, and nothing else", c do
      documents =
        c.sink
        |> RecordingSink.paths()
        |> Enum.filter(&String.starts_with?(&1, "activitypub/"))
        |> Enum.sort()

      posts = Enum.map([c.short, c.titled, c.review], &"activitypub/posts/#{&1.public_id}")

      assert documents ==
               Enum.sort([
                 "activitypub/timon",
                 "activitypub/outbox",
                 "activitypub/followers",
                 "activitypub/following" | posts
               ])
    end

    test "never writes the private key", %{sink: sink, scope: scope} do
      private_key = Fediverse.private_key(scope.site)
      [_header, key_body | _rest] = String.split(private_key, "\n")

      for path <- RecordingSink.paths(sink) do
        content = RecordingSink.get(sink, path)

        if is_binary(content) do
          refute content =~ "PRIVATE KEY", path
          refute content =~ key_body, path
        end
      end
    end

    test "publishes a pending key in the account, never its private half", c do
      {:ok, site} = Fediverse.rotate_key(c.scope)
      sink = export(Scope.put_site(c.scope, site))

      [[stored]] =
        Repo.query!("SELECT fediverse_pending_private_key FROM sites WHERE id = ?", [site.id]).rows

      {:ok, private_key} = Encryption.decrypt(stored)
      [_header, key_body | _rest] = String.split(private_key, "\n")

      assert json(sink, "activitypub/timon")["publicKey"]["publicKeyPem"] ==
               site.fediverse_pending_public_key

      for path <- RecordingSink.paths(sink),
          content = RecordingSink.get(sink, path),
          is_binary(content) do
        refute content =~ "PRIVATE KEY", path
        refute content =~ key_body, path
      end
    end

    test "links each post's document and the account from the pages", c do
      post_page = LazyHTML.from_document(RecordingSink.get(c.sink, "hello/index.html"))
      home = LazyHTML.from_document(RecordingSink.get(c.sink, "index.html"))
      about = LazyHTML.from_document(RecordingSink.get(c.sink, "about/index.html"))
      selector = ~s(link[rel="alternate"][type="application/activity+json"])

      assert post_page |> LazyHTML.query(selector) |> LazyHTML.attribute("href") ==
               ["https://timon.blog/activitypub/posts/#{c.titled.public_id}"]

      assert home |> LazyHTML.query(selector) |> LazyHTML.attribute("href") ==
               ["https://timon.blog/activitypub/timon"]

      assert about |> LazyHTML.query(selector) |> Enum.empty?()
    end

    test "serves the documents, plain and precompressed, as application/activity+json",
         %{sink: sink} do
      htaccess = RecordingSink.get(sink, ".htaccess")

      assert htaccess =~ """
             <If "%{REQUEST_URI} =~ m#^/activitypub/#">
               ForceType application/activity+json
             </If>
             <FilesMatch "^webfinger(\\.br|\\.gz)?$">
               ForceType application/jrd+json
               <IfModule mod_headers.c>
                 Header always set Access-Control-Allow-Origin "*"
               </IfModule>
             </FilesMatch>
             """

      [_, guarded] =
        String.split(htaccess, "<IfModule mod_rewrite.c>\n  <IfModule mod_headers.c>\n")

      for suffix <- [".br", ".gz"] do
        assert guarded =~ """
                   RewriteCond %{REQUEST_FILENAME}#{suffix} -f
                   RewriteRule ^(activitypub/.+|\\.well-known/webfinger)$ $1#{suffix} [L]
               """
      end

      assert guarded =~
               "RewriteRule ^activitypub/.+\\.(br|gz)$ - [T=application/activity+json,E=no-gzip:1,E=no-brotli:1]"

      assert guarded =~
               "RewriteRule ^\\.well-known/webfinger\\.(br|gz)$ - [T=application/jrd+json,E=no-gzip:1,E=no-brotli:1]"

      assert guarded =~ """
                 <If "%{REQUEST_URI} =~ m#^/(activitypub/|\\.well-known/webfinger)#">
                   Header always merge Vary Accept-Encoding
                 </If>
             """
    end
  end

  describe "a site without a fediverse name" do
    test "writes no WebFinger, account or post documents and links none" do
      scope = site_scope_fixture()
      post_fixture(scope, %{title: "Hello", slug: "/hello"})
      sink = export(scope)

      refute Enum.any?(
               RecordingSink.paths(sink),
               &String.starts_with?(&1, ["activitypub/", ".well-known/"])
             )

      refute RecordingSink.get(sink, "hello/index.html") =~ "application/activity+json"
      refute RecordingSink.get(sink, "index.html") =~ "application/activity+json"
      refute RecordingSink.get(sink, ".htaccess") =~ "activitypub"
    end

    test "leaves the portrait out unless its theme shows it" do
      scope = fediverse_site(%{domain: "pumbaa.blog"})
      {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => ""})
      portrait = Repo.preload(site, :portrait_image).portrait_image
      sink = export(Scope.put_site(scope, site))

      refute Enum.any?(
               RecordingSink.paths(sink),
               &String.starts_with?(&1, "images/#{portrait.public_id}/")
             )
    end
  end
end
