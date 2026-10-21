defmodule Feather.StaticSite.ExportDeliveryTest do
  use Feather.DataCase

  alias Feather.StaticSite.{Export, RecordingSink, Routes}
  alias Feather.StaticSite.Themes.{FeatherPage, SimpleSidebar}

  defp export(theme) do
    scope = site_scope_fixture(%{theme: theme})
    image = image_fixture(scope, width: 800, height: 600)
    page_fixture(scope, %{title: "About", slug: "/about"})

    post_fixture(scope, %{
      title: "Hello",
      slug: "/hello",
      emoji: "🦊",
      header_image_id: image.id,
      content: [image_block(image, "An image"), embed_block()]
    })

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink
  end

  defp embed_block do
    %{
      "type" => "embed",
      "service" => "youtube",
      "source" => "https://www.youtube.com/watch?v=abc",
      "embed" => "https://www.youtube.com/embed/abc",
      "width" => 580,
      "height" => 320,
      "caption" => "Video"
    }
  end

  defp html_pages(sink), do: sink |> RecordingSink.paths() |> Enum.filter(&(&1 =~ ~r/\.html\z/))

  defp attributes(doc, selector, name),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

  defp none?(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.empty?()

  defp scripts(doc), do: doc |> LazyHTML.query("script") |> LazyHTML.attributes()

  defp own_file_urls(doc) do
    srcsets = attributes(doc, "img[srcset], source[srcset]", "srcset")

    attributes(doc, ~s(link[rel="stylesheet"], link[rel="preload"]), "href") ++
      attributes(doc, "img", "src") ++ Enum.flat_map(srcsets, &srcset_urls/1)
  end

  defp srcset_urls(srcset) do
    srcset |> String.split(",") |> Enum.map(&(&1 |> String.trim() |> String.split() |> hd()))
  end

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

  describe "the pages" do
    test "load only what the content security policy of the .htaccess allows" do
      for theme <- ["feather", "simple_sidebar"] do
        sink = export(theme)

        for path <- html_pages(sink) do
          doc = LazyHTML.from_document(RecordingSink.get(sink, path))

          assert none?(doc, "style, base, form, object, embed"), path
          # Structured data is a data block browsers do not run; the policy allows no script.
          assert Enum.all?(scripts(doc), &(&1 == [{"type", "application/ld+json"}])), path
          assert Enum.all?(own_file_urls(doc), &(&1 =~ ~r{\A/[^/]})), path
          assert [icon] = attributes(doc, ~s(link[rel="icon"]), "href")
          assert icon =~ ~r"\A(/images/[0-9a-f]{64}\.png\z|data:image/svg\+xml,)", path
          assert Enum.all?(attributes(doc, "iframe", "src"), &String.starts_with?(&1, "https://"))
        end

        home = LazyHTML.from_document(RecordingSink.get(sink, "index.html"))
        post = LazyHTML.from_document(RecordingSink.get(sink, "hello/index.html"))

        assert [_structured_data] = scripts(home)
        assert [_structured_data] = scripts(post)
        assert ["/images/" <> _favicon] = attributes(home, ~s(link[rel="icon"]), "href")
        assert ["data:image/svg+xml," <> _emoji] = attributes(post, ~s(link[rel="icon"]), "href")
        assert [_header, _content] = attributes(post, "img", "src")
        assert [_embed] = attributes(post, "iframe", "src")
        assert [_aspect_ratio] = attributes(post, "iframe", "style")
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

    test "sends the security headers on every response with mod_headers, diagrams with their own policy",
         %{htaccess: htaccess} do
      assert htaccess =~ """
             <IfModule mod_headers.c>
               Header always set Strict-Transport-Security "max-age=31536000"
               Header always set X-Content-Type-Options "nosniff"
               Header always set Referrer-Policy "strict-origin-when-cross-origin"
               Header always set Content-Security-Policy "default-src 'none'; img-src 'self' data:; style-src 'self'; style-src-attr 'unsafe-inline'; font-src 'self'; frame-src https:; base-uri 'none'; form-action 'none'; frame-ancestors 'self'"
               <FilesMatch "\\.svg(\\.br|\\.gz)?$">
                 Header always set Content-Security-Policy "default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:; frame-ancestors 'self'"
               </FilesMatch>
             </IfModule>
             """
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

    test "lets browsers cache style.css, images, drawn images and fonts for a year, with mod_headers",
         %{htaccess: htaccess} do
      assert htaccess =~ """
             <IfModule mod_headers.c>
               <FilesMatch "^style\\.css(\\.br|\\.gz)?$">
                 Header set Cache-Control "public, max-age=31536000, immutable"
               </FilesMatch>
               <FilesMatch "\\.(webp|jpg|png|woff2)$">
                 Header set Cache-Control "public, max-age=31536000, immutable"
               </FilesMatch>
             </IfModule>
             """
    end
  end
end
