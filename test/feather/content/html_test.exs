defmodule Feather.Content.HTMLTest do
  use ExUnit.Case, async: true

  import Feather.Content.HTML, only: [sanitize: 1, sanitize: 2, safe_url?: 1]

  # No markup that could execute survives: no event handlers, no script or
  # style elements, no dangerous URLs, no elements outside the allow list.
  defp assert_inert(html) do
    output = sanitize(html)
    {:ok, nodes} = Floki.parse_fragment(output)

    for {tag, attributes, _children} <- Floki.find(nodes, "*") do
      assert tag in ~w(b i u a code), "unexpected <#{tag}> in #{inspect(output)}"

      for {name, value} <- attributes do
        assert {tag, name} == {"a", "href"}, "unexpected #{name} in #{inspect(output)}"
        assert safe_url?(value), "unsafe href #{inspect(value)} in #{inspect(output)}"
      end
    end

    # Text such as "onerror=" may remain, but only escaped: no raw tag.
    refute output =~ ~r/<(?!\/?(b|i|u|a|code)\b)/i
    output
  end

  describe "allowed markup" do
    test "keeps b, i, u, code and links with href" do
      html =
        ~S|Some <b>bold</b>, <i>it</i>, <u>u</u>, <code>x</code> and <a href="https://example.com">a link</a>.|

      assert sanitize(html) == html
    end

    test "keeps relative, fragment, mailto and tel links" do
      for href <- ~w(/about about#x #top ?q=1 mailto:me@example.com tel:+49123 //example.com/x) do
        assert sanitize(~s(<a href="#{href}">x</a>)) == ~s(<a href="#{href}">x</a>)
      end
    end

    test "lowercases tags and attributes" do
      assert sanitize(~S|<B>x</B><A HREF="http://x">y</A>|) ==
               ~S|<b>x</b><a href="http://x">y</a>|
    end

    test "keeps whitespace between elements and entities" do
      assert sanitize("<b>a</b> <i>b</i>") == "<b>a</b> <i>b</i>"
      assert sanitize("x &amp; &lt; &#65;") == "x &amp; &lt; A"
      assert sanitize("<b>a</b>\n<i>b</i>") == "<b>a</b>\n<i>b</i>"
      assert sanitize("Some <b>bold</b> <script>x</script>text.") == "Some <b>bold</b> text."
    end

    test "nil and empty input" do
      assert sanitize(nil) == ""
      assert sanitize("") == ""
    end
  end

  describe "stripping" do
    test "removes other elements but keeps their text" do
      assert sanitize("<p>para</p><div>d<span>s</span></div>") == "parads"
      assert sanitize("x<br>y") == "xy"
      assert sanitize(~S|<h1 class="c">Title</h1>|) == "Title"
    end

    test "drops script and style with their content" do
      assert sanitize("<script>alert('<b>x</b>')</script>after") == "after"
      assert sanitize("<style>b { color: red }</style>s") == "s"
      assert sanitize("<SCRIPT>alert(1)</SCRIPT>t") == "t"
    end

    test "drops comments, CDATA markup and processing instructions" do
      assert sanitize("<!-- <script>x</script> --><b>c</b>") == "<b>c</b>"
      assert sanitize("<![CDATA[<script>x</script>]]>t") == "&lt;script&gt;x&lt;/script&gt;t"
      assert sanitize("<?xml version=\"1.0\"?>t") |> String.ends_with?("t")
    end

    test "removes every attribute but href on links" do
      assert sanitize(~S|<b class="x" onclick="alert(1)">b</b>|) == "<b>b</b>"

      assert sanitize(~S|<a href="/x" onclick="alert(1)" target="_blank" style="x">y</a>|) ==
               ~S|<a href="/x">y</a>|
    end

    test "closes unclosed tags and ignores stray end tags" do
      assert sanitize("<b><i>unclosed") == "<b><i>unclosed</i></b>"
      assert sanitize("</b>stray close") == "stray close"
    end
  end

  describe "escaping" do
    test "text is escaped, entities decoded once" do
      assert sanitize("1 < 2 and 3 > 2") == "1 &lt; 2 and 3 &gt; 2"
      assert sanitize("a &amp; b &lt;x&gt;") == "a &amp; b &lt;x&gt;"

      assert sanitize("&lt;script&gt;alert(1)&lt;/script&gt;") ==
               "&lt;script&gt;alert(1)&lt;/script&gt;"
    end

    test "quotes in href values are escaped" do
      assert sanitize(~S|<a href='/a"b'>q</a>|) == ~S|<a href="/a&quot;b">q</a>|

      assert sanitize(~S|<a href="/x&quot; onmouseover=&quot;alert(1)">q</a>|) ==
               ~S|<a href="/x&quot; onmouseover=&quot;alert(1)">q</a>|
    end
  end

  describe "XSS vectors" do
    @vectors [
      "<script>alert(1)</script>",
      "<img src=x onerror=alert(1)>",
      "<IMG SRC=x ONERROR=alert(1)>",
      "<svg onload=alert(1)><a href='x'>y</a></svg>",
      "<svg><script>alert(1)</script></svg>",
      "<body onload=alert(1)>",
      "<iframe src=javascript:alert(1)></iframe>",
      "<a href=\"javascript:alert(1)\">x</a>",
      "<a href=\"JaVaScRiPt:alert(1)\">x</a>",
      "<a href=\" javascript:alert(1)\">x</a>",
      "<a href=\"jav&#x09;ascript:alert(1)\">x</a>",
      "<a href=\"jav&#x0A;ascript:alert(1)\">x</a>",
      "<a href=\"jav\tascript:alert(1)\">x</a>",
      "<a href=\"&#x20;javascript:alert(1)\">x</a>",
      "<a href=&#106;avascript:alert(1)>x</a>",
      "<a href='&#0000106&#0000097vascript:alert(1)'>x</a>",
      "<a href=\"&#x6A;&#x61;&#x76;&#x61;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;&#x3A;alert(1)\">x</a>",
      "<a href=\"javascript&colon;alert(1)\">x</a>",
      "<a href=\"data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==\">x</a>",
      "<a href=\"vbscript:msgbox(1)\">x</a>",
      "<a href=\"java\u0000script:alert(1)\">x</a>",
      "<a href=\"​javascript:alert(1)\">x</a>",
      "<a href=\"x\" \" onclick=\"alert(1)\">z</a>",
      "<a href=x onmouseover=alert(1)>z</a>",
      "<b onmouseover=alert(1)>b</b>",
      "<code><script>alert(1)</script></code>",
      "<<script>script>alert(1)<</script>/script>",
      "<scr<script>ipt>alert(1)</script>",
      "<noscript><p title=\"</noscript><img src=x onerror=alert(1)>\"></noscript>",
      "<textarea><img src=x onerror=alert(1)></textarea>",
      "<math><mi><a href=javascript:alert(1)>x</a></mi></math>",
      "<b>unterminated <a href='javascript:alert(1)",
      "<a href=\"javascript:alert(1)\"<b>x</b>",
      "<style>@import 'javascript:alert(1)';</style>",
      "<div style=\"background:url(javascript:alert(1))\">x</div>",
      "<object data=\"javascript:alert(1)\"></object>",
      "<form action=javascript:alert(1)><input type=submit></form>",
      "<details open ontoggle=alert(1)>",
      "<!--><img src=x onerror=alert(1)>-->",
      "<![CDATA[><img src=x onerror=alert(1)>]]>"
    ]

    test "no vector survives as active markup" do
      for vector <- @vectors, do: assert_inert(vector)
    end

    test "dangerous hrefs are removed, the link text stays" do
      assert sanitize(~S|<a href="javascript:alert(1)">x</a>|) == "<a>x</a>"
      assert sanitize(~S|<a href="jav&#x09;ascript:alert(1)">x</a>|) == "<a>x</a>"
      assert sanitize(~S|<a href="data:text/html,x">x</a>|) == "<a>x</a>"
    end

    test "entities the parser leaves alone stay literal text in the href" do
      # A browser reads &amp;#0000106 as the literal text "&#0000106", not
      # as "j", so the URL is relative and harmless.
      assert sanitize("<a href='&#0000106&#0000097vascript:alert(1)'>q</a>") ==
               ~S|<a href="&amp;#0000106&amp;#0000097vascript:alert(1)">q</a>|
    end

    test "invalid UTF-8 is removed" do
      assert sanitize(<<"a", 0xFF, "b">>) == "ab"
    end
  end

  describe "escaping like innerHTML" do
    test "quotes and apostrophes in text stay literal, no-break spaces become &nbsp;" do
      assert sanitize(~S|It's "quoted"|) == ~S|It's "quoted"|
      assert sanitize("a&nbsp;b\u00A0c") == "a&nbsp;b&nbsp;c"
    end

    test "sanitizing is idempotent" do
      for html <- [
            ~S|<b>x</b> &amp; &lt;y&gt; it's&nbsp;<a href="/a?b=1&amp;c=2">l</a>|,
            "<img src=x onerror=alert(1)>t<br>u",
            ~S|<a href="javascript:alert(1)" target="_blank">x</a>|
          ],
          mode <- [:published, :editor] do
        once = sanitize(html, mode)
        assert sanitize(once, mode) == once
      end
    end
  end

  describe "editor mode" do
    test "keeps line breaks and link targets" do
      html =
        ~S|a<br><code>c</code> <u>u</u> | <>
          ~S|<a href="https://e.com" target="_blank" rel="nofollow">l</a>|

      assert sanitize(html, :editor) == html
    end

    test "drops the classes of the former editor's inline tools" do
      assert sanitize(
               ~S|<code class="inline-code">c</code> <u class="cdx-underline">u</u>|,
               :editor
             ) ==
               "<code>c</code> <u>u</u>"
    end

    test "the published mode strips the editor extras" do
      html =
        ~S|a<br><code>c</code> <a href="/x" target="_blank" rel="nofollow">l</a>|

      assert sanitize(html) == ~S|a<code>c</code> <a href="/x">l</a>|
    end

    test "other attribute values and elements are removed" do
      assert sanitize(~S|<code class="x" onclick="a()">c</code>|, :editor) == "<code>c</code>"

      assert sanitize(~S|<a href="/x" target="evil" rel="opener">l</a>|, :editor) ==
               ~S|<a href="/x">l</a>|

      assert sanitize(~S|<br onclick="x()">|, :editor) == "<br>"
      assert sanitize("<img src=x onerror=alert(1)><p>p</p>", :editor) == "p"
    end

    test "no XSS vector survives" do
      for vector <- @vectors do
        output = sanitize(vector, :editor)
        {:ok, nodes} = Floki.parse_fragment(output)

        for {tag, attributes, _children} <- Floki.find(nodes, "*") do
          assert tag in ~w(b i u a code br), "unexpected <#{tag}> in #{inspect(output)}"

          for {name, value} <- attributes do
            assert name in ~w(href target rel), "unexpected #{name} in #{inspect(output)}"
            if name == "href", do: assert(safe_url?(value))
          end
        end
      end
    end
  end

  describe "safe_url?/1" do
    test "accepts relative and allowed schemes" do
      for url <- ~w(/x x x/y #f ?q https://e.com HTTP://e.com mailto:a@b tel:1 //e.com /a:b) do
        assert safe_url?(url), url
      end
    end

    test "rejects other schemes, also obfuscated" do
      for url <- [
            "javascript:alert(1)",
            " javascript:alert(1)",
            "java\nscript:alert(1)",
            "java\tscript:x",
            "JAVASCRIPT:x",
            "data:text/html,x",
            "vbscript:x",
            "file:///etc/passwd",
            "ftp://x",
            "foo:bar",
            " javascript:x",
            "java​script:x"
          ] do
        refute safe_url?(url), inspect(url)
      end
    end

    test "rejects non-strings and invalid UTF-8" do
      refute safe_url?(nil)
      refute safe_url?(<<0xFF>>)
    end
  end
end
