defmodule Feather.StaticSite.ExportDeliveryTest do
  use Feather.DataCase

  alias Feather.StaticSite.{Export, RecordingSink, Routes}
  alias Feather.StaticSite.Themes.{FeatherPage, SimpleSidebar}

  defp export(theme) do
    scope = site_scope_fixture(%{theme: theme})
    page_fixture(scope, %{title: "About", slug: "/about"})
    post_fixture(scope, %{title: "Hello", slug: "/hello"})

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink
  end

  defp html_pages(sink), do: sink |> RecordingSink.paths() |> Enum.filter(&(&1 =~ ~r/\.html\z/))

  describe "the stylesheet" do
    test "is written to style.css, the font faces before the theme's CSS" do
      for {theme, module} <- [{"feather", FeatherPage}, {"simple_sidebar", SimpleSidebar}] do
        css = RecordingSink.get(export(theme), "style.css")

        assert String.starts_with?(css, "@font-face {")
        assert String.ends_with?(css, module.css())
      end
    end

    test "is linked from every formatted page with a hash of its content instead of a style element" do
      for theme <- ["feather", "simple_sidebar"] do
        sink = export(theme)
        css = RecordingSink.get(sink, "style.css")
        hash = :crypto.hash(:sha256, css) |> Base.encode16(case: :lower) |> binary_part(0, 12)
        pages = html_pages(sink)

        assert "404.html" in pages

        for path <- pages do
          html = RecordingSink.get(sink, path)
          doc = LazyHTML.from_document(html)

          assert String.starts_with?(html, "<!DOCTYPE html>\n<html"), path
          refute html =~ ~r/\n[ \t]*\n/, path
          assert doc |> LazyHTML.query("style") |> Enum.empty?(), path

          assert doc |> LazyHTML.query(~s(link[rel="stylesheet"])) |> LazyHTML.attribute("href") ==
                   ["/style.css?v=" <> hash],
                 path
        end
      end
    end
  end

  describe "the .htaccess" do
    setup do
      %{htaccess: RecordingSink.get(export("feather"), ".htaccess")}
    end

    test "sets the site's 404 page as the error document outside every module guard",
         %{htaccess: htaccess} do
      [before_guards | _] = String.split(htaccess, "<IfModule")

      assert before_guards == "ErrorDocument 404 /404.html\n\n"
    end

    test "serves the precompressed copies only with mod_rewrite and mod_headers",
         %{htaccess: htaccess} do
      [_, guarded] =
        String.split(htaccess, "<IfModule mod_rewrite.c>\n  <IfModule mod_headers.c>\n")

      [compression, _cache] = String.split(guarded, "  </IfModule>\n</IfModule>\n")

      for {encoding, suffix} <- [{"br", ".br"}, {"gzip", ".gz"}] do
        assert compression =~ """
                   RewriteCond %{HTTP:Accept-Encoding} \\b#{encoding}\\b
                   RewriteCond %{REQUEST_FILENAME}/index.html#{suffix} -f
                   RewriteRule ^(.*/)?$ $1index.html#{suffix} [L]
                   RewriteCond %{HTTP:Accept-Encoding} \\b#{encoding}\\b
                   RewriteCond %{REQUEST_FILENAME}#{suffix} -f
                   RewriteRule ^(.+\\.(html|css|js|txt|xml|svg))$ $1#{suffix} [L]
               """

        assert compression =~ "Header always set Content-Encoding #{encoding}"
      end

      for {extension, type} <- [
            {"html", "text/html"},
            {"css", "text/css"},
            {"svg", "image/svg+xml"}
          ] do
        assert compression =~
                 "RewriteRule \\.#{extension}\\.(br|gz)$ - [T=#{type},E=no-gzip:1,E=no-brotli:1]"
      end

      assert compression =~ "RemoveEncoding .br .gz"
      assert compression =~ "Header always merge Vary Accept-Encoding"
    end

    test "lets browsers cache style.css, images and fonts for a year, with mod_headers",
         %{htaccess: htaccess} do
      assert htaccess =~ """
             <IfModule mod_headers.c>
               <FilesMatch "^style\\.css(\\.br|\\.gz)?$">
                 Header set Cache-Control "public, max-age=31536000, immutable"
               </FilesMatch>
               <FilesMatch "\\.(webp|jpg|woff2)$">
                 Header set Cache-Control "public, max-age=31536000, immutable"
               </FilesMatch>
             </IfModule>
             """
    end
  end
end
