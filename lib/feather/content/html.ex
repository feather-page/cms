defmodule Feather.Content.HTML do
  @moduledoc """
  Sanitizes the inline HTML of content (paragraphs, headers, list items,
  quotes, captions, table cells). This is a security boundary twice over:

    * `Feather.Content.Blocks.normalize/1` sanitizes every inline HTML
      field with `sanitize(html, :editor)` before content is stored (admin
      editor, content API, import) and before it is handed to the admin
      editor, which renders it with `innerHTML`.
    * The static site inserts `sanitize(html)` unescaped into its pages.

  In the default `:published` mode only `b`, `i`, `u`, `a` and `code`
  survive, and only `href` on `a` (the allow list of the Rails renderers).
  The `:editor` mode keeps what the admin editor (Editor.js) writes on top
  of that and is harmless: `br`, `target="_blank"` and
  `rel="nofollow"`/`"noopener"`/`"noreferrer"` on links, and the marker
  classes of the inline tools (`code class="inline-code"`,
  `u class="cdx-underline"`). Other elements are removed but their text is
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
  attribute values), so the output of the admin editor passes unchanged and
  sanitizing is idempotent. The output is meant for element content, never
  for an attribute value.

  The tokens come from Floki's mochiweb tokenizer (`:floki_mochi_html.tokens/1`)
  rather than `Floki.parse_fragment/1`: building the tree drops
  whitespace-only text, which would glue `<b>a</b> <i>b</i>` together.
  """

  @type mode :: :published | :editor

  @allowed_tags %{
    published: ~w(b i u a code),
    editor: ~w(b i u a code br)
  }
  @void_tags ~w(br)
  @dropped_content_tags ~w(script style)
  @allowed_schemes ~w(http https mailto tel)

  # Attributes the admin editor writes, kept in :editor mode with these
  # values only (besides href on links).
  @editor_classes %{"code" => "inline-code", "u" => "cdx-underline"}
  @editor_rel_tokens ~w(nofollow noopener noreferrer)

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
    allowed? = tag in Map.fetch!(@allowed_tags, mode)

    cond do
      allowed? and tag in @void_tags ->
        walk(rest, mode, open, nil, [["<", tag, ">"] | acc])

      allowed? and self_closing? ->
        walk(rest, mode, open, nil, [[open_tag(tag, attributes, mode), close(tag)] | acc])

      allowed? ->
        walk(rest, mode, [tag | open], nil, [open_tag(tag, attributes, mode) | acc])

      tag in @dropped_content_tags and not self_closing? ->
        walk(rest, mode, open, tag, acc)

      true ->
        walk(rest, mode, open, nil, acc)
    end
  end

  # An end tag closes its element and everything opened inside it; end
  # tags of elements that are not open are ignored.
  defp walk([{:end_tag, tag} | rest], mode, open, nil, acc) do
    tag = String.downcase(tag)

    case Enum.split_while(open, &(&1 != tag)) do
      {inner, [^tag | outer]} ->
        walk(rest, mode, outer, nil, [Enum.map(inner ++ [tag], &close/1) | acc])

      {_inner, []} ->
        walk(rest, mode, open, nil, acc)
    end
  end

  # Comments, processing instructions, doctypes.
  defp walk([_token | rest], mode, open, nil, acc), do: walk(rest, mode, open, nil, acc)

  defp open_tag(tag, attributes, mode) do
    attributes =
      Map.new(attributes, fn {name, value} ->
        {name |> to_string() |> String.downcase(), IO.iodata_to_binary(value)}
      end)

    kept =
      [{"href", attributes["href"]} | editor_attributes(tag, attributes, mode)]
      |> Enum.flat_map(fn {name, value} ->
        case keep_attribute(tag, name, value) do
          nil -> []
          kept_value -> [[" ", name, ~s(="), escape_attribute(kept_value), ~s(")]]
        end
      end)

    ["<", tag, kept, ">"]
  end

  defp editor_attributes("a", attributes, :editor),
    do: [{"target", attributes["target"]}, {"rel", attributes["rel"]}]

  defp editor_attributes(tag, attributes, :editor) when is_map_key(@editor_classes, tag),
    do: [{"class", attributes["class"]}]

  defp editor_attributes(_tag, _attributes, _mode), do: []

  defp keep_attribute("a", "href", href) when is_binary(href),
    do: if(safe_url?(href), do: href)

  defp keep_attribute("a", "target", "_blank"), do: "_blank"

  defp keep_attribute("a", "rel", rel) when is_binary(rel) do
    tokens = rel |> String.downcase() |> String.split()
    if tokens != [] and Enum.all?(tokens, &(&1 in @editor_rel_tokens)), do: Enum.join(tokens, " ")
  end

  defp keep_attribute(tag, "class", class) when is_binary(class) do
    if String.trim(class) == @editor_classes[tag], do: @editor_classes[tag]
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
