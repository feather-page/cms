defmodule Feather.Content.HTML do
  @moduledoc """
  Sanitizes the inline HTML of content (paragraphs, headers, list items,
  quotes, captions, table cells). This is a security boundary twice over:

    * `Feather.Content.Blocks.normalize/1` sanitizes every inline HTML
      field with `sanitize(html, :editor)` before content is stored (admin
      editor, content API, import) and before it is handed to the admin
      editor.
    * The static site inserts `sanitize(html)` unescaped into its pages.

  `to_markdown/2` converts the sanitized markup to Markdown for the
  Markdown alternates of the static site.

  In the default `:published` mode only `b`, `i`, `u`, `a`, `code` and
  `br` survive, and only `href` on `a` (the allow list of the Rails
  renderers, plus the line breaks the editor writes). The `:editor` mode
  keeps what the admin editor writes on top of that and is harmless:
  `target="_blank"` and `rel="nofollow"`/`"noopener"`/`"noreferrer"` on
  links. Other attributes
  (such as the classes the former editor put on `code` and `u`) are
  dropped. Other elements are removed but their text is
  kept (like Loofah's strip scrubber Rails used); the content of `script`
  and `style` is dropped. Comments, processing instructions and doctypes
  are dropped.

  An `href` survives only when it is relative (path, query or fragment) or
  uses `http`, `https`, `mailto` or `tel`.

  Safety does not depend on the parser agreeing with browsers: the input is
  tokenized (entities decoded) and the output is rebuilt from the tokens,
  with every text and attribute value escaped and every allowed element
  closed. The `href` a browser sees is therefore exactly the decoded value
  checked here.

  Escaping follows the browsers' `innerHTML` serialization (`&`, `<`, `>`
  and no-break spaces in text; `&`, `"`, `<`, `>` and no-break spaces in
  attribute values), so HTML serialized by a browser passes unchanged and
  sanitizing is idempotent. The output is meant for element content, never
  for an attribute value.

  The tokens come from Floki's mochiweb tokenizer (`:floki_mochi_html.tokens/1`)
  rather than `Floki.parse_fragment/1`: building the tree drops
  whitespace-only text, which would glue `<b>a</b> <i>b</i>` together.
  """

  alias Feather.Content.Markdown

  @type mode :: :published | :editor

  @allowed_tags %{
    published: ~w(b i u a code br),
    editor: ~w(b i u a code br)
  }
  @void_tags ~w(br)
  @dropped_content_tags ~w(script style)
  @allowed_schemes ~w(http https mailto tel)

  # Link attributes the admin editor writes, kept in :editor mode with
  # these values only (besides href).
  @editor_rel_tokens ~w(nofollow noopener noreferrer)

  @emphasis_delimiters %{"b" => "**", "i" => "*"}

  @doc """
  Returns the sanitized HTML of an inline HTML string. nil becomes `""`.

  `mode` is `:published` (default: the static site) or `:editor` (stored
  content and the admin editor), see the module documentation.
  """
  @spec sanitize(String.t() | nil, mode()) :: String.t()
  def sanitize(html, mode \\ :published)

  def sanitize(nil, _mode), do: ""

  def sanitize(html, mode) when is_binary(html) and mode in [:published, :editor] do
    html = String.replace_invalid(html, "")

    case tokens(html) do
      {:ok, tokens} -> tokens |> walk(mode, [], nil, []) |> IO.iodata_to_binary()
      :error -> escape_text(html)
    end
  end

  def sanitize(other, mode), do: other |> to_string() |> sanitize(mode)

  defp tokens(html) do
    {:ok, :floki_mochi_html.tokens(html)}
  rescue
    _exception -> :error
  end

  @doc """
  Converts inline HTML to Markdown (see `Feather.Content.Markdown`). It is
  sanitized in `:editor` mode first, so only the allowed markup remains:
  `b` becomes `**…**`, `i` `*…*`, `code` a code span, a link `[…](href)`
  (its URL as text when it has none) and `br` a hard line break; `u` keeps
  only its text, as does a link inside a link. Neighbouring elements of the
  same kind merge, whitespace collapses as a browser shows it and moves out
  of the delimiters at the edges of an element, and text is escaped.
  Relative hrefs are resolved against `base_url` when it is absolute.
  """
  @spec to_markdown(String.t() | nil, String.t() | nil) :: String.t()
  def to_markdown(html, base_url \\ nil) do
    html
    |> sanitize(:editor)
    |> :floki_mochi_html.tokens()
    |> inline_nodes()
    |> markdown(base_url, false)
    |> IO.iodata_to_binary()
    |> Markdown.inline()
  end

  # The sanitized markup is well-formed: every element is closed in order.
  defp inline_nodes(tokens) do
    {nodes, _rest} = inline_nodes(tokens, [])
    nodes
  end

  defp inline_nodes([], acc), do: {merge_neighbours(acc), []}
  defp inline_nodes([{:end_tag, _tag} | rest], acc), do: {merge_neighbours(acc), rest}

  # Text arrives in pieces (`&amp;nbsp;` as `&` and `nbsp;`); it is escaped as a whole.
  defp inline_nodes([{:data, text, _whitespace?} | rest], [{:text, previous} | acc]),
    do: inline_nodes(rest, [{:text, previous <> text} | acc])

  defp inline_nodes([{:data, text, _whitespace?} | rest], acc),
    do: inline_nodes(rest, [{:text, text} | acc])

  defp inline_nodes([{:start_tag, tag, _attributes, _self_closing?} | rest], acc)
       when tag in @void_tags,
       do: inline_nodes(rest, [:break | acc])

  defp inline_nodes([{:start_tag, tag, attributes, _self_closing?} | rest], acc) do
    {children, rest} = inline_nodes(rest, [])
    inline_nodes(rest, [{tag, attributes, children} | acc])
  end

  defp inline_nodes([_token | rest], acc), do: inline_nodes(rest, acc)

  # `<b>a</b><b>b</b>` would become `**a****b**`, which is no emphasis.
  defp merge_neighbours(reversed) do
    Enum.reduce(reversed, [], fn
      {tag, [], children}, [{tag, [], more} | rest] -> [{tag, [], children ++ more} | rest]
      node, acc -> [node | acc]
    end)
  end

  defp markdown(nodes, base_url, in_link?),
    do: Enum.map(nodes, &node_markdown(&1, base_url, in_link?))

  defp node_markdown({:text, text}, _base_url, _in_link?),
    do: text |> Markdown.collapse_whitespace() |> Markdown.escape_inline()

  defp node_markdown(:break, _base_url, _in_link?), do: "\n"

  defp node_markdown({tag, _attributes, children}, base_url, in_link?)
       when is_map_key(@emphasis_delimiters, tag) do
    children
    |> markdown(base_url, in_link?)
    |> IO.iodata_to_binary()
    |> Markdown.emphasis(Map.fetch!(@emphasis_delimiters, tag))
  end

  defp node_markdown({"code", _attributes, children}, _base_url, _in_link?),
    do: children |> plain_text() |> Markdown.code_span()

  defp node_markdown({"a", attributes, children}, base_url, false) do
    label = children |> markdown(base_url, true) |> IO.iodata_to_binary()

    case List.keyfind(attributes, "href", 0) do
      {"href", href} -> link_markdown(label, IO.iodata_to_binary(href), base_url)
      nil -> label
    end
  end

  defp node_markdown({_tag, _attributes, children}, base_url, in_link?),
    do: markdown(children, base_url, in_link?)

  defp link_markdown(label, href, base_url) do
    case Markdown.edges(label) do
      {_leading, "", _trailing} ->
        url = Markdown.absolute_url(href, base_url)
        Markdown.link(Markdown.escape(url), url)

      {leading, core, trailing} ->
        leading <> Markdown.link(core, href, base_url) <> trailing
    end
  end

  defp plain_text(nodes) do
    Enum.map_join(nodes, fn
      {:text, text} -> text
      :break -> " "
      {_tag, _attributes, children} -> plain_text(children)
    end)
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

  # walk(tokens, mode, open allowed tags (innermost first), tag whose
  # content is being dropped or nil, output in reverse)

  defp walk([], _mode, open, _dropping, acc), do: Enum.reverse(acc, Enum.map(open, &close/1))

  # Inside script/style: everything up to its end tag is dropped.
  defp walk([{:end_tag, tag} | rest], mode, open, dropping, acc) when is_binary(dropping) do
    if String.downcase(tag) == dropping,
      do: walk(rest, mode, open, nil, acc),
      else: walk(rest, mode, open, dropping, acc)
  end

  defp walk([_token | rest], mode, open, dropping, acc) when is_binary(dropping),
    do: walk(rest, mode, open, dropping, acc)

  defp walk([{:data, text, _whitespace?} | rest], mode, open, nil, acc),
    do: walk(rest, mode, open, nil, [escape_text(text) | acc])

  defp walk([{:start_tag, tag, attributes, self_closing?} | rest], mode, open, nil, acc) do
    tag = String.downcase(tag)

    if tag in Map.fetch!(@allowed_tags, mode) do
      {open, html} = keep_start_tag(tag, attributes, self_closing?, mode, open)
      walk(rest, mode, open, nil, [html | acc])
    else
      walk(rest, mode, open, dropping(tag, self_closing?), acc)
    end
  end

  # An end tag closes its element and everything opened inside it; end
  # tags of elements that are not open are ignored.
  defp walk([{:end_tag, tag} | rest], mode, open, nil, acc) do
    tag = String.downcase(tag)

    case Enum.split_while(open, &(&1 != tag)) do
      {inner, [^tag | outer]} ->
        walk(rest, mode, outer, nil, [[Enum.map(inner, &close/1), close(tag)] | acc])

      {_inner, []} ->
        walk(rest, mode, open, nil, acc)
    end
  end

  # Comments, processing instructions, doctypes.
  defp walk([_token | rest], mode, open, nil, acc), do: walk(rest, mode, open, nil, acc)

  defp keep_start_tag(tag, _attributes, _self_closing?, _mode, open) when tag in @void_tags,
    do: {open, ["<", tag, ">"]}

  defp keep_start_tag(tag, attributes, true, mode, open),
    do: {open, [open_tag(tag, attributes, mode), close(tag)]}

  defp keep_start_tag(tag, attributes, false, mode, open),
    do: {[tag | open], open_tag(tag, attributes, mode)}

  defp dropping(tag, false) when tag in @dropped_content_tags, do: tag
  defp dropping(_tag, _self_closing?), do: nil

  defp open_tag(tag, attributes, mode) do
    attributes =
      Map.new(attributes, fn {name, value} ->
        {name |> to_string() |> String.downcase(), IO.iodata_to_binary(value)}
      end)

    candidates = [{"href", attributes["href"]} | editor_attributes(tag, attributes, mode)]

    kept =
      Enum.flat_map(candidates, fn {name, value} ->
        case keep_attribute(tag, name, value) do
          nil -> []
          kept_value -> [[" ", name, ~s(="), escape_attribute(kept_value), ~s(")]]
        end
      end)

    ["<", tag, kept, ">"]
  end

  defp editor_attributes("a", attributes, :editor),
    do: [{"target", attributes["target"]}, {"rel", attributes["rel"]}]

  defp editor_attributes(_tag, _attributes, _mode), do: []

  defp keep_attribute("a", "href", href) when is_binary(href),
    do: if(safe_url?(href), do: href)

  defp keep_attribute("a", "target", "_blank"), do: "_blank"

  defp keep_attribute("a", "rel", rel) when is_binary(rel) do
    tokens = rel |> String.downcase() |> String.split()
    if tokens != [] and Enum.all?(tokens, &(&1 in @editor_rel_tokens)), do: Enum.join(tokens, " ")
  end

  defp keep_attribute(_tag, _name, _value), do: nil

  defp close(tag), do: ["</", tag, ">"]

  @nbsp " "

  defp escape_text(text) do
    text
    |> String.replace_invalid("")
    |> String.replace(["&", "<", ">", @nbsp], fn
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      @nbsp -> "&nbsp;"
    end)
  end

  defp escape_attribute(value) do
    value
    |> String.replace_invalid("")
    |> String.replace(["&", "\"", "<", ">", @nbsp], fn
      "&" -> "&amp;"
      "\"" -> "&quot;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      @nbsp -> "&nbsp;"
    end)
  end
end
