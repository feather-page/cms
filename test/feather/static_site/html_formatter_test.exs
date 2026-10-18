defmodule Feather.StaticSite.HTMLFormatterTest do
  use ExUnit.Case, async: true

  alias Feather.StaticSite.HTMLFormatter

  defp body(html) do
    [_, inner] = Regex.run(~r{<body>\n(.*)  </body>}s, HTMLFormatter.format(html))
    inner
  end

  test "indents nested blocks two spaces per level, one per line, without blank lines" do
    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>

    <title>Home</title>
    </head>
    <body>


    <main><section><h1>Hello</h1><p>Some text</p></section></main>

    </body>
    </html>
    """

    assert HTMLFormatter.format(html) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <title>Home</title>
             </head>
             <body>
               <main>
                 <section>
                   <h1>Hello</h1>
                   <p>Some text</p>
                 </section>
               </main>
             </body>
           </html>
           """
  end

  test "keeps the whitespace between inline elements" do
    assert body("<p><b>a</b> <i>b</i></p>") == "    <p><b>a</b> <i>b</i></p>\n"
    assert body("<p><b>a</b><i>b</i></p>") == "    <p><b>a</b><i>b</i></p>\n"
  end

  test "indents inline content that the source breaks over lines" do
    html = """
    <p class="links">
            <a href="/a">
              <svg viewBox="0 0 1 1"><path d="M0 0"></path></svg>
            </a>
    <a href="/b">B</a>
    </p>
    """

    assert body(html) == """
               <p class="links">
                 <a href="/a">
                   <svg viewBox="0 0 1 1"><path d="M0 0"/></svg>
                 </a>
                 <a href="/b">B</a>
               </p>
           """
  end

  test "puts text next to blocks on its own line" do
    assert body("<div>Hello <b>you</b><p>x</p> bye</div>") == """
               <div>
                 Hello <b>you</b>
                 <p>x</p>
                 bye
               </div>
           """
  end

  test "keeps the content of pre byte for byte" do
    code =
      ~s{<code class="language-elixir"><span class="hl-k">def</span> run(a, b) do\n} <>
        ~s{  a &lt;&gt; b   \n\n<span class="hl-k">end</span>\n</code>}

    assert body("<div><pre>#{code}</pre></div>") == """
               <div>
                 <pre>#{code}</pre>
               </div>
           """

    assert body("<pre>\n\n  indented</pre>") == "    <pre>\n\n  indented</pre>\n"
  end

  test "keeps the content of textarea, script and style" do
    html =
      "<body><style>a > b { color: red; }\n  p {}</style>" <>
        "<script>if (a < b && c) {\n  run()\n}</script>" <>
        "<form><textarea>  two\n\n lines</textarea></form>"

    assert body(html) == """
               <style>a > b { color: red; }
             p {}</style>
               <script>if (a < b && c) {
             run()
           }</script>
               <form><textarea>  two

            lines</textarea></form>
           """
  end

  test "writes empty elements without a closing slash and starts with the doctype" do
    html =
      ~s(<html><head><meta charset="utf-8" /><link rel="icon" href="/i.svg"/></head>) <>
        ~s(<body><p>a<br/>b</p><img src="/a.png" alt="" /><hr></body></html>)

    assert HTMLFormatter.format(html) == """
           <!DOCTYPE html>
           <html>
             <head>
               <meta charset="utf-8">
               <link rel="icon" href="/i.svg">
             </head>
             <body>
               <p>a<br>b</p>
               <img src="/a.png" alt="">
               <hr>
             </body>
           </html>
           """
  end

  test "drops comments" do
    assert body("<!-- one --><p>a<!-- two -->b</p>") == "    <p>ab</p>\n"
  end

  test "escapes text and attributes, and writes boolean attributes bare" do
    html =
      ~s(<details open=""><summary title="&quot;a&quot; &amp; &lt;b&gt;">Tom &amp; Jerry&#39;s &lt;3&nbsp;</summary></details>)

    assert body(html) == """
               <details open>
                 <summary title="&quot;a&quot; &amp; &lt;b&gt;">Tom &amp; Jerry's &lt;3&nbsp;</summary>
               </details>
           """
  end

  test "escapes the text of textarea and keeps the text of other raw text elements" do
    html = "<form><textarea>&lt;/textarea&gt; &amp;</textarea></form><xmp>a <b> & c</xmp>"

    assert body(html) == """
               <form><textarea>&lt;/textarea&gt; &amp;</textarea></form>
               <xmp>a <b> & c</xmp>
           """
  end

  test "writes HTML inside an SVG foreignObject with end tags" do
    html = ~s(<p><svg><foreignObject><div></div><span>after</span></foreignObject></svg></p>)

    assert body(html) ==
             "    <p><svg><foreignObject><div></div><span>after</span></foreignObject></svg></p>\n"
  end

  test "formats text with a very long run of whitespace" do
    spaces = String.duplicate(" ", 10_000)

    assert body("<p>x#{spaces}y</p>") == "    <p>x#{spaces}y</p>\n"
    assert body("<p>#{spaces}y#{spaces}</p>") == "    <p>#{spaces}y#{spaces}</p>\n"
  end
end
