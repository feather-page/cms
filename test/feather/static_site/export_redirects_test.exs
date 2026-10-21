defmodule Feather.StaticSite.ExportRedirectsTest do
  use Feather.DataCase

  alias Feather.{Content, Redirects}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  setup do
    %{scope: site_scope_fixture()}
  end

  defp htaccess(scope) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    RecordingSink.get(sink, ".htaccess")
  end

  defp rules(htaccess), do: List.flatten(Regex.scan(~r/^ *RewriteRule .*\[R=.*$/m, htaccess))

  test "writes one rule per active redirect with its status, in its own block before the precompression rules",
       %{scope: scope} do
    post_fixture(scope, %{slug: "/rule-of-72"})
    post_fixture(scope, %{slug: "/now"})
    draft = page_fixture(scope, %{slug: "/later", draft: true})
    redirect_fixture(scope, old_path: "/posts/rule-of-72", target: "/rule-of-72/")
    redirect_fixture(scope, old_path: "/current", target: "/now/", kind: "temporary")
    redirect_fixture(scope, old_path: "/soon", target: draft.slug)

    htaccess = htaccess(scope)

    assert rules(htaccess) == [
             "  RewriteRule ^current(/(index\\.html)?)?$ /now/ [R=302,L]",
             "  RewriteRule ^current/index\\.md$ /now/index.md [R=302,L]",
             "  RewriteRule ^posts/rule\\-of\\-72(/(index\\.html)?)?$ /rule-of-72/ [R=301,L]",
             "  RewriteRule ^posts/rule\\-of\\-72/index\\.md$ /rule-of-72/index.md [R=301,L]"
           ]

    assert htaccess =~ """
           <IfModule mod_rewrite.c>
             RewriteEngine On
             RewriteRule ^current(/(index\\.html)?)?$ /now/ [R=302,L]
             RewriteRule ^current/index\\.md$ /now/index.md [R=302,L]
             RewriteRule ^posts/rule\\-of\\-72(/(index\\.html)?)?$ /rule-of-72/ [R=301,L]
             RewriteRule ^posts/rule\\-of\\-72/index\\.md$ /rule-of-72/index.md [R=301,L]
           </IfModule>

           <IfModule mod_rewrite.c>
             <IfModule mod_headers.c>
           """
  end

  test "matches an old path with an extension exactly, the target as published", %{scope: scope} do
    post = post_fixture(scope, %{slug: "/how-to-manage"})
    redirect_fixture(scope, old_path: "/2013/01/22/how-to-manage.html", target: "/how-to-manage/")
    redirect_fixture(scope, old_path: "/atom.xml", target: "/feed.xml")
    {:ok, _} = Content.update_post(scope, post, %{slug: "/unpublished-slug"})

    assert rules(htaccess(scope)) == [
             "  RewriteRule ^2013/01/22/how\\-to\\-manage\\.html$ /how-to-manage/ [R=301,L]",
             "  RewriteRule ^atom\\.xml$ /feed.xml [R=301,L]"
           ]
  end

  test "catches an old path without an extension also as its index.html, after the rules of old paths with one",
       %{scope: scope} do
    post_fixture(scope, %{slug: "/neu"})
    post_fixture(scope, %{slug: "/other"})
    redirect_fixture(scope, old_path: "/alt", target: "/neu/")
    redirect_fixture(scope, old_path: "/alt/index.html", target: "/other/")
    redirect_fixture(scope, old_path: "/b.html", target: "/neu/")

    assert rules(htaccess(scope)) == [
             "  RewriteRule ^alt/index\\.html$ /other/ [R=301,L]",
             "  RewriteRule ^b\\.html$ /neu/ [R=301,L]",
             "  RewriteRule ^alt(/(index\\.html)?)?$ /neu/ [R=301,L]",
             "  RewriteRule ^alt/index\\.md$ /neu/index.md [R=301,L]"
           ]
  end

  test "sends an old path's index.md to the Markdown alternate of the target, or to a target without one",
       %{scope: scope} do
    post = post_fixture(scope, %{slug: "/alt"})
    {:ok, post} = Content.update_post(scope, post, %{slug: "/neu"})
    {:ok, _post} = Content.publish(scope, post)
    page_fixture(scope, %{slug: "/about"})
    project_fixture(scope, %{slug: "/cms"})
    redirect_fixture(scope, old_path: "/me", target: "/about/")
    redirect_fixture(scope, old_path: "/work", target: "/projects/cms/")
    redirect_fixture(scope, old_path: "/start", target: "/", kind: "temporary")
    redirect_fixture(scope, old_path: "/rss", target: "/feed.xml")

    assert rules(htaccess(scope)) == [
             "  RewriteRule ^alt(/(index\\.html)?)?$ /neu/ [R=301,L]",
             "  RewriteRule ^alt/index\\.md$ /neu/index.md [R=301,L]",
             "  RewriteRule ^me(/(index\\.html)?)?$ /about/ [R=301,L]",
             "  RewriteRule ^me/index\\.md$ /about/index.md [R=301,L]",
             "  RewriteRule ^rss(/(index\\.html)?)?$ /feed.xml [R=301,L]",
             "  RewriteRule ^rss/index\\.md$ /feed.xml [R=301,L]",
             "  RewriteRule ^start(/(index\\.html)?)?$ / [R=302,L]",
             "  RewriteRule ^start/index\\.md$ /index.md [R=302,L]",
             "  RewriteRule ^work(/(index\\.html)?)?$ /projects/cms/ [R=301,L]",
             "  RewriteRule ^work/index\\.md$ /projects/cms/index.md [R=301,L]"
           ]
  end

  test "escapes the characters of an old path that mean something in a pattern",
       %{scope: scope} do
    post_fixture(scope, %{slug: "/x"})
    redirect_fixture(scope, old_path: "/a$b(c)+d'e", target: "/x/")

    assert rules(htaccess(scope)) == [
             "  RewriteRule ^a\\$b\\(c\\)\\+d'e(/(index\\.html)?)?$ /x/ [R=301,L]",
             "  RewriteRule ^a\\$b\\(c\\)\\+d'e/index\\.md$ /x/index.md [R=301,L]"
           ]
  end

  test "leaves out a redirect while its target record is unpublished", %{scope: scope} do
    page = page_fixture(scope, %{slug: "/target"})
    redirect_fixture(scope, old_path: "/old", target: "/target/")

    {:ok, page} = Content.unpublish(scope, page)
    htaccess = htaccess(scope)
    assert rules(htaccess) == []
    refute htaccess =~ "RewriteEngine On\n</IfModule>"

    {:ok, _} = Content.publish(scope, page)

    assert rules(htaccess(scope)) == [
             "  RewriteRule ^old(/(index\\.html)?)?$ /target/ [R=301,L]",
             "  RewriteRule ^old/index\\.md$ /target/index.md [R=301,L]"
           ]
  end

  test "renaming a published post twice redirects both old URLs to the current one in a single step",
       %{scope: scope} do
    post = post_fixture(scope, %{slug: "/ssh-copy-id"})
    {:ok, post} = Content.update_post(scope, post, %{slug: "/install-ssh-key"})
    {:ok, post} = Content.publish(scope, post)
    {:ok, post} = Content.update_post(scope, post, %{slug: "/ssh-key"})
    {:ok, _post} = Content.publish(scope, post)

    assert scope |> Redirects.list_redirects() |> Enum.map(& &1.old_path) ==
             ["/install-ssh-key", "/ssh-copy-id"]

    assert rules(htaccess(scope)) == [
             "  RewriteRule ^install\\-ssh\\-key(/(index\\.html)?)?$ /ssh-key/ [R=301,L]",
             "  RewriteRule ^install\\-ssh\\-key/index\\.md$ /ssh-key/index.md [R=301,L]",
             "  RewriteRule ^ssh\\-copy\\-id(/(index\\.html)?)?$ /ssh-key/ [R=301,L]",
             "  RewriteRule ^ssh\\-copy\\-id/index\\.md$ /ssh-key/index.md [R=301,L]"
           ]
  end
end
