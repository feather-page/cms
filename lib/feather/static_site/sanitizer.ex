defmodule Feather.StaticSite.Sanitizer do
  @moduledoc """
  Sanitizes the inline HTML of Editor.js content (paragraphs, headers, list
  items, quotes, captions, table cells) before it is written into a static
  site. This is a security boundary: the output is inserted unescaped.

  Only `b`, `i`, `u`, `a` and `code` survive, and only `href` on `a`.
  Other elements are removed but their text is kept (like Loofah's strip
  scrubber Rails used); the content of `script` and `style` is dropped.
  Comments, processing instructions and doctypes are dropped.

  An `href` survives only when it is relative (path, query or fragment) or
  uses `http`, `https`, `mailto` or `tel`.

  Safety does not depend on the parser agreeing with browsers: the input is
  tokenized (entities decoded) and the output is rebuilt from the tokens,
  with every text and attribute value escaped and every allowed element
  closed. The `href` a browser sees is therefore exactly the decoded value
  checked here.

  The tokens come from Floki's mochiweb tokenizer (`:floki_mochi_html.tokens/1`)
  rather than `Floki.parse_fragment/1`: building the tree drops
  whitespace-only text, which would glue `<b>a</b> <i>b</i>` together.
  """

  @allowed_tags ~w(b i u a code)
  @dropped_content_tags ~w(script style)
  @allowed_schemes ~w(http https mailto tel)

  @doc """
  Returns the sanitized HTML of an inline HTML string. nil becomes `""`.
  """
  @spec sanitize(String.t() | nil) :: String.t()
  def sanitize(nil), do: ""

  def sanitize(html) when is_binary(html) do
    html = String.replace_invalid(html, "")

    case tokens(html) do
      {:ok, tokens} -> tokens |> walk([], nil, []) |> IO.iodata_to_binary()
      :error -> escape(html)
    end
  end

  def sanitize(other), do: other |> to_string() |> sanitize()

  defp tokens(html) do
    {:ok, :floki_mochi_html.tokens(html)}
  rescue
    _exception -> :error
  end

  @doc """
  Returns true if `url` may be used as a link target: a relative URL or one
  with the scheme `http`, `https`, `mailto` or `tel`. The check ignores
  whitespace, control characters and case the way browsers do when they
  parse a URL (and stricter: any of them anywhere is ignored).
  """
  @spec safe_url?(String.t() | nil) :: boolean()
  def safe_url?(url) when is_binary(url) do
    String.valid?(url) and
      url
      |> String.replace(~r/[\x00-\x20\x7F-\x9F\p{Z}\p{Cf}]/u, "")
      |> String.downcase()
      |> allowed_scheme?()
  end

  def safe_url?(_url), do: false

  # Everything before the first ":" that is not preceded by "/", "?" or "#"
  # is a scheme to a browser (or an invalid URL); without one the URL is
  # relative.
  defp allowed_scheme?(normalized) do
    case Regex.run(~r/\A([^\/?#]*?):/u, normalized) do
      nil -> true
      [_, scheme] -> scheme in @allowed_schemes
    end
  end

  # walk(tokens, open allowed tags (innermost first), tag whose content is
  # being dropped or nil, output in reverse)

  defp walk([], open, _dropping, acc), do: Enum.reverse(acc, Enum.map(open, &close/1))

  # Inside script/style: everything up to its end tag is dropped.
  defp walk([{:end_tag, tag} | rest], open, dropping, acc) when is_binary(dropping) do
    if String.downcase(tag) == dropping,
      do: walk(rest, open, nil, acc),
      else: walk(rest, open, dropping, acc)
  end

  defp walk([_token | rest], open, dropping, acc) when is_binary(dropping),
    do: walk(rest, open, dropping, acc)

  defp walk([{:data, text, _whitespace?} | rest], open, nil, acc),
    do: walk(rest, open, nil, [escape(text) | acc])

  defp walk([{:start_tag, tag, attributes, self_closing?} | rest], open, nil, acc) do
    tag = String.downcase(tag)

    cond do
      tag in @allowed_tags and self_closing? ->
        walk(rest, open, nil, [[open_tag(tag, attributes), close(tag)] | acc])

      tag in @allowed_tags ->
        walk(rest, [tag | open], nil, [open_tag(tag, attributes) | acc])

      tag in @dropped_content_tags and not self_closing? ->
        walk(rest, open, tag, acc)

      true ->
        walk(rest, open, nil, acc)
    end
  end

  # An end tag closes its element and everything opened inside it; end
  # tags of elements that are not open are ignored.
  defp walk([{:end_tag, tag} | rest], open, nil, acc) do
    tag = String.downcase(tag)

    case Enum.split_while(open, &(&1 != tag)) do
      {inner, [^tag | outer]} -> walk(rest, outer, nil, [Enum.map(inner ++ [tag], &close/1) | acc])
      {_inner, []} -> walk(rest, open, nil, acc)
    end
  end

  # Comments, processing instructions, doctypes.
  defp walk([_token | rest], open, nil, acc), do: walk(rest, open, nil, acc)

  defp open_tag("a", attributes) do
    href =
      Enum.find_value(attributes, fn {name, value} ->
        value = IO.iodata_to_binary(value)
        if String.downcase(to_string(name)) == "href" and safe_url?(value), do: value
      end)

    if href, do: [~s(<a href="), escape(href), ~s(">)], else: "<a>"
  end

  defp open_tag(tag, _attributes), do: ["<", tag, ">"]

  defp close(tag), do: ["</", tag, ">"]

  defp escape(text) do
    text
    |> String.replace_invalid("")
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
