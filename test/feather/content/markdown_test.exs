defmodule Feather.Content.MarkdownTest do
  use ExUnit.Case, async: true

  alias Feather.Content.Markdown

  describe "escape/1" do
    test "escapes the characters that are Markdown anywhere" do
      assert Markdown.escape(~S"a\b `c` *d* _e_ [f] <g> ~h~") ==
               ~S"a\\b \`c\` \*d\* \_e\_ \[f\] \<g> \~h\~"
    end

    test "escapes an ampersand only where it starts a character reference" do
      assert Markdown.escape("Tom & Jerry &amp; &#39; &#x27; AT&T") ==
               ~S"Tom & Jerry \&amp; \&#39; \&#x27; AT&T"
    end

    test "escapes what starts a block at the start of the text" do
      for {text, escaped} <- [
            {"# Not a heading", ~S"\# Not a heading"},
            {"> Not a quote", ~S"\> Not a quote"},
            {"- Not a list", ~S"\- Not a list"},
            {"+ Not a list", ~S"\+ Not a list"},
            {"===", ~S"\==="},
            {"1. Not a list", ~S"1\. Not a list"},
            {"2024) Not a list", ~S"2024\) Not a list"},
            {"2024 was a year", "2024 was a year"},
            {"1.5 litres", "1.5 litres"},
            {"a # b - c", "a # b - c"}
          ] do
        assert Markdown.escape(text) == escaped, text
      end
    end

    test "collapses whitespace like a browser and trims it" do
      assert Markdown.escape("  a \n\t b  ") == "a b"
      assert Markdown.escape("\n - x") == ~S"\- x"
    end

    test "collapses vertical tabs, next lines and line and paragraph separators to spaces" do
      assert Markdown.escape("a\vb\u0085c\u2028 d\u2029\u2029e\u2028") == "a b c d e"
      assert Markdown.escape("x\u2028- y") == "x - y"
    end
  end

  describe "inline/1" do
    test "writes newlines as hard line breaks without the spaces around them" do
      assert Markdown.inline("a \n b\nc") == "a\\\nb\\\nc"
    end

    test "drops line breaks and spaces at the edges" do
      assert Markdown.inline(" \n a\n \n") == "a"
    end

    test "escapes what starts a block at the start of every line" do
      assert Markdown.inline("# a\n- b\n1. c") == "\\# a\\\n\\- b\\\n1\\. c"
    end
  end

  describe "emphasis/2" do
    test "wraps text in the delimiter, its edge whitespace outside" do
      assert Markdown.emphasis("a", "**") == "**a**"
      assert Markdown.emphasis(" a b\n", "*") == " *a b*\n"
    end

    test "leaves blank text as it is" do
      assert Markdown.emphasis(" ", "**") == " "
      assert Markdown.emphasis("", "*") == ""
    end

    test "treats Unicode whitespace like a no-break space as edge whitespace" do
      assert Markdown.emphasis("Wichtig:\u00A0", "**") == "**Wichtig:**\u00A0"
      assert Markdown.emphasis("\u00A0a\u2003", "*") == "\u00A0*a*\u2003"
      assert Markdown.emphasis("\u00A0\u3000", "**") == "\u00A0\u3000"
    end
  end

  describe "link/3" do
    test "links the label to the URL" do
      assert Markdown.link("a *b*", "https://example.com/x?y=1#z") ==
               "[a *b*](https://example.com/x?y=1#z)"
    end

    test "resolves a relative URL against the base URL" do
      base = "https://example.com/posts/hello/"

      assert Markdown.link("a", "/about/", base) == "[a](https://example.com/about/)"
      assert Markdown.link("a", "other/", base) == "[a](https://example.com/posts/hello/other/)"
      assert Markdown.link("a", "#top", base) == "[a](https://example.com/posts/hello/#top)"
      assert Markdown.link("a", "mailto:me@example.com", base) == "[a](mailto:me@example.com)"
      assert Markdown.link("a", "/about/", "/") == "[a](/about/)"
    end

    test "puts URLs with parentheses, angle brackets or backslashes in angle brackets" do
      assert Markdown.link("a", "https://en.wikipedia.org/wiki/Elixir_(language)") ==
               "[a](<https://en.wikipedia.org/wiki/Elixir_(language)>)"

      assert Markdown.link("a", ~S"https://e.com/<x>\y") == ~S"[a](<https://e.com/\<x\>\\y>)"
    end

    test "encodes spaces and control characters" do
      assert Markdown.link("a", "https://e.com/a b\nc") == "[a](https://e.com/a%20b%0Ac)"
    end

    test "escapes an ampersand that starts a character reference" do
      assert Markdown.link("a", "https://e.com/?a=1&copy;=2&b=3") ==
               ~S"[a](https://e.com/?a=1\&copy;=2&b=3)"

      assert Markdown.link("a", "https://e.com/(x)?&#39;") == ~S"[a](<https://e.com/(x)?\&#39;>)"
    end
  end

  describe "image/2" do
    test "an image with its alt text" do
      assert Markdown.image("A view", "https://e.com/v.webp") == "![A view](https://e.com/v.webp)"
    end
  end

  describe "heading/2" do
    test "a heading of the level, escaping a closing sequence of #s" do
      assert Markdown.heading(2, "Title") == "## Title"
      assert Markdown.heading(3, "Ranked ##") == "### Ranked \\##"
      assert Markdown.heading(1, "C#") == "# C#"
    end
  end

  describe "code_span/1" do
    test "fences code with more backticks than it contains" do
      assert Markdown.code_span("x * y") == "`x * y`"
      assert Markdown.code_span("a `b` c") == "``a `b` c``"
      assert Markdown.code_span("``") == "``` `` ```"
    end

    test "pads code that starts or ends with a backtick or a space" do
      assert Markdown.code_span("`a") == "`` `a ``"
      assert Markdown.code_span(" a ") == "`  a  `"
    end

    test "turns line breaks into spaces and leaves blank code as it is" do
      assert Markdown.code_span("a\nb") == "`a b`"
      assert Markdown.code_span("") == ""
      assert Markdown.code_span(" ") == " "
    end
  end

  describe "code_block/2" do
    test "fences code with its language" do
      assert Markdown.code_block("puts 1\n", "ruby") == "```ruby\nputs 1\n```"
      assert Markdown.code_block("x", nil) == "```\nx\n```"
    end

    test "uses a fence longer than any run of backticks in the code" do
      assert Markdown.code_block("```\nx\n````", "md") == "`````md\n```\nx\n````\n`````"
    end
  end
end
