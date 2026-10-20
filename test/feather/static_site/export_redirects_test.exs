defmodule Feather.StaticSite.ExportRedirectsTest do
  use Feather.DataCase

  alias Feather.Content
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
             "  RewriteRule ^current/?$ /now/ [R=302,L]",
             "  RewriteRule ^posts/rule\\-of\\-72/?$ /rule-of-72/ [R=301,L]"
           ]

    assert htaccess =~ """
           <IfModule mod_rewrite.c>
             RewriteEngine On
             RewriteRule ^current/?$ /now/ [R=302,L]
             RewriteRule ^posts/rule\\-of\\-72/?$ /rule-of-72/ [R=301,L]
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

  test "escapes the characters of an old path that mean something in a pattern",
       %{scope: scope} do
    post_fixture(scope, %{slug: "/x"})
    redirect_fixture(scope, old_path: "/a$b(c)+d'e", target: "/x/")

    assert rules(htaccess(scope)) == ["  RewriteRule ^a\\$b\\(c\\)\\+d'e/?$ /x/ [R=301,L]"]
  end

  test "leaves out a redirect while its target record is unpublished", %{scope: scope} do
    page = page_fixture(scope, %{slug: "/target"})
    redirect_fixture(scope, old_path: "/old", target: "/target/")

    {:ok, page} = Content.unpublish(scope, page)
    htaccess = htaccess(scope)
    assert rules(htaccess) == []
    refute htaccess =~ "RewriteEngine On\n</IfModule>"

    {:ok, _} = Content.publish(scope, page)
    assert rules(htaccess(scope)) == ["  RewriteRule ^old/?$ /target/ [R=301,L]"]
  end
end
