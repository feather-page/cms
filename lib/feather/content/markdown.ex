defmodule Feather.Content.Markdown do
  @moduledoc """
  Markdown syntax for content, as CommonMark and GitHub read it: escaped
  text, emphasis, links, images, headings, code spans and fenced code
  blocks. `Feather.Content.HTML.to_markdown/2` converts inline HTML with
  it, `Feather.StaticSite.MarkdownAlternate` renders the blocks of a
  Markdown alternate and `Feather.StaticSite.LlmsTxt` the `llms.txt`.

  Text is escaped where it would be Markdown: `\\`, `` ` ``, `*`, `_`, `[`,
  `]`, `<` and `~` everywhere, `&` where it starts a character reference,
  and `#`, `>`, `-`, `+`, `=` or a number followed by `.` or `)` at the
  start of a line. A pipe is escaped only in tables.
  """

  @inline_syntax ~r/[\\`*_\[\]<~]|&(?=#?[A-Za-z0-9]+;)/
  @reference_start ~r/&(?=#?[A-Za-z0-9]+;)/
  @block_start ~r/^[#>+=-]/m
  @list_number ~r/^(\d{1,9})([.)])(?=\s|$)/m
  @whitespace ~r/[ \t\n\f\r]+/
  @line_separators ~r/[\x0B\x{85}\x{2028}\x{2029}]/u

  @doc """
  Escapes plain text, collapsing its whitespace to single spaces as a
  browser shows it, without whitespace at the edges. Vertical tabs, next
  lines and line and paragraph separators, which some readers take for
  line breaks, collapse too.
  """
  @spec escape(String.t() | nil) :: String.t()
  def escape(nil), do: ""

  def escape(text) do
    text
    |> String.replace(@line_separators, " ")
    |> collapse_whitespace()
    |> String.trim()
    |> escape_inline()
    |> escape_block_starts()
  end

  @doc "Escapes the characters of text that are Markdown anywhere in a line."
  @spec escape_inline(String.t()) :: String.t()
  def escape_inline(text), do: Regex.replace(@inline_syntax, text, "\\\\\\0")

  @doc "Turns runs of whitespace into single spaces, as a browser shows them."
  @spec collapse_whitespace(String.t()) :: String.t()
  def collapse_whitespace(text), do: Regex.replace(@whitespace, text, " ")

  @doc """
  Finishes inline Markdown whose line breaks are newlines: drops spaces
  around them and line breaks and spaces at the edges, escapes what would
  start a block at the start of each line and writes each newline as a
  hard line break (a backslash before it).
  """
  @spec inline(String.t()) :: String.t()
  def inline(markdown) do
    markdown
    |> String.replace(~r/ *\n */, "\n")
    |> String.replace(~r/\A[ \n]+|[ \n]+\z/, "")
    |> escape_block_starts()
    |> String.replace("\n", "\\\n")
  end

  defp escape_block_starts(markdown) do
    markdown
    |> String.replace(@block_start, "\\\\\\0")
    |> String.replace(@list_number, "\\1\\\\\\2")
  end

  @doc """
  Wraps inline Markdown in an emphasis delimiter (`*` or `**`), with the
  whitespace at its edges outside, since a delimiter next to whitespace
  emphasizes nothing. Blank Markdown stays as it is.
  """
  @spec emphasis(String.t(), String.t()) :: String.t()
  def emphasis(markdown, delimiter) do
    case edges(markdown) do
      {_leading, "", _trailing} -> markdown
      {leading, core, trailing} -> leading <> delimiter <> core <> delimiter <> trailing
    end
  end

  @doc """
  Splits inline Markdown into its leading whitespace (any Unicode
  whitespace, like spaces, line breaks and no-break spaces), the rest and
  its trailing whitespace.
  """
  @spec edges(String.t()) :: {String.t(), String.t(), String.t()}
  def edges(markdown) do
    [_, leading, core, trailing] = Regex.run(~r/\A(\s*)(.*?)(\s*)\z/su, markdown)
    {leading, core, trailing}
  end

  @doc """
  A link of inline Markdown to a URL, resolved against `base_url` when it
  is relative and `base_url` is absolute.
  """
  @spec link(String.t(), String.t(), String.t() | nil) :: String.t()
  def link(label, url, base_url \\ nil),
    do: "[" <> label <> "](" <> destination(absolute_url(url, base_url)) <> ")"

  @doc "An image with its alt text (escaped plain text)."
  @spec image(String.t(), String.t()) :: String.t()
  def image(alt, url), do: "!" <> link(alt, url)

  @doc "An ATX heading of the level with inline Markdown on one line."
  @spec heading(1..6, String.t()) :: String.t()
  def heading(level, markdown) do
    # A heading would drop a closing sequence of #s.
    String.duplicate("#", level) <> " " <> Regex.replace(~r/(\s)(#+)\z/, markdown, "\\1\\\\\\2")
  end

  @doc "A URL resolved against `base_url` when it is relative and `base_url` is absolute."
  @spec absolute_url(String.t(), String.t() | nil) :: String.t()
  def absolute_url(url, base_url) when is_binary(base_url) do
    if URI.parse(base_url).scheme && URI.parse(url).scheme == nil,
      do: base_url |> URI.merge(url) |> URI.to_string(),
      else: url
  end

  def absolute_url(url, nil), do: url

  # Angle brackets keep a URL with parentheses or backslashes as it is, a
  # backslash an ampersand that would start a character reference.
  defp destination(url) do
    url = URI.encode(url, &(&1 > 0x20 and &1 != 0x7F))

    url =
      if url =~ ~r/[()<>\\]/,
        do: "<" <> Regex.replace(~r/[<>\\]/, url, "\\\\\\0") <> ">",
        else: url

    Regex.replace(@reference_start, url, "\\\\&")
  end

  @doc """
  A code span, fenced with more backticks than any run in the code and
  padded with spaces where the code starts or ends with a backtick or a
  space. Line breaks become spaces; blank code stays as it is.
  """
  @spec code_span(String.t()) :: String.t()
  def code_span(code) do
    code = String.replace(code, ~r/\r\n?|\n/, " ")

    if String.trim(code) == "" do
      code
    else
      fence = String.duplicate("`", longest_backtick_run(code) + 1)
      pad = if code =~ ~r/\A[` ]|[` ]\z/, do: " ", else: ""
      fence <> pad <> code <> pad <> fence
    end
  end

  @doc """
  A fenced code block with the language as its info string (none for
  nil), its fence longer than any run of backticks in the code.
  """
  @spec code_block(String.t(), String.t() | nil) :: String.t()
  def code_block(code, language) do
    fence = String.duplicate("`", max(3, longest_backtick_run(code) + 1))
    body = if code == "" or String.ends_with?(code, "\n"), do: code, else: code <> "\n"
    fence <> (language || "") <> "\n" <> body <> fence
  end

  defp longest_backtick_run(code) do
    ~r/`+/
    |> Regex.scan(code)
    |> Enum.map(fn [run] -> String.length(run) end)
    |> Enum.max(fn -> 0 end)
  end
end
