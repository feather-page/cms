defmodule Feather.StaticSite.HTMLFormatter do
  @moduledoc """
  Formats a rendered page of the static site like hand-written HTML, without
  changing how it looks (ADR 0022). Whitespace is only added or dropped next
  to block elements, where browsers ignore it.
  """

  @block_tags ~w(
    address article aside base blockquote body caption col colgroup dd details dialog div dl dt
    fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup hr html legend li
    link main menu meta nav noscript ol optgroup option p pre script search section style summary
    table tbody td template tfoot th thead title tr ul
  )
  @void_tags ~w(area base br col embed hr img input link meta source track wbr)
  @raw_text_tags ~w(script style xmp iframe noembed noframes)
  @preformatted_tags ~w(pre textarea)
  @foreign_tags ~w(svg math)
  @leaf_tags @void_tags ++ @raw_text_tags ++ @preformatted_tags
  @boolean_attributes ~w(
    allowfullscreen async autofocus autoplay checked controls default defer disabled formnovalidate
    hidden inert ismap itemscope loop multiple muted nomodule novalidate open playsinline readonly
    required reversed selected
  )
  @indent "  "
  @whitespace ~c[ \t\n\r\f]

  @doc "Formats a whole page; the result ends in a newline."
  @spec format(iodata()) :: String.t()
  def format(html) do
    tree = html |> IO.iodata_to_binary() |> LazyHTML.from_document() |> LazyHTML.to_tree()
    IO.iodata_to_binary(["<!DOCTYPE html>\n", block_content(tree, 0)])
  end

  defp block_content(nodes, depth) do
    nodes
    |> Enum.reject(&match?({:comment, _}, &1))
    |> Enum.chunk_by(&block?/1)
    |> Enum.flat_map(&lines(&1, depth))
  end

  defp lines([node | _] = nodes, depth) do
    if block?(node),
      do: Enum.map(nodes, &[indent(depth), block_element(&1, depth), "\n"]),
      else: inline_line(nodes, depth)
  end

  defp inline_line(nodes, depth) do
    case nodes |> trim_leading() |> Enum.reverse() |> trim_trailing() |> Enum.reverse() do
      [] -> []
      nodes -> [[indent(depth), inline_content(nodes, depth), "\n"]]
    end
  end

  defp trim_leading([text | rest]) when is_binary(text) do
    case split_whitespace(text) do
      {_leading, "", _trailing} -> trim_leading(rest)
      {_leading, middle, trailing} -> [middle <> trailing | rest]
    end
  end

  defp trim_leading(nodes), do: nodes

  defp trim_trailing([text | rest]) when is_binary(text) do
    case split_whitespace(text) do
      {_leading, "", _trailing} -> trim_trailing(rest)
      {leading, middle, _trailing} -> [leading <> middle | rest]
    end
  end

  defp trim_trailing(nodes), do: nodes

  # A byte scan instead of a regex: backtracking over long whitespace runs exceeds PCRE's limits.
  defp split_whitespace(text) do
    size = byte_size(text)
    lead = leading_whitespace(text, 0)
    trail = if lead == size, do: 0, else: trailing_whitespace(text, size)

    {binary_part(text, 0, lead), binary_part(text, lead, size - lead - trail),
     binary_part(text, size - trail, trail)}
  end

  defp leading_whitespace(<<char, rest::binary>>, count) when char in @whitespace,
    do: leading_whitespace(rest, count + 1)

  defp leading_whitespace(_text, count), do: count

  defp trailing_whitespace(text, position) do
    if :binary.at(text, position - 1) in @whitespace,
      do: 1 + trailing_whitespace(text, position - 1),
      else: 0
  end

  defp block?({tag, _attrs, children}) when is_binary(tag),
    do: tag in @block_tags or (tag not in @foreign_tags and block_children?(children))

  defp block?(_node), do: false

  defp block_children?(children), do: Enum.any?(children, &block?/1)

  defp block_element({tag, attrs, children} = element, depth) do
    if tag in @leaf_tags or not block_children?(children),
      do: element(element, depth),
      else: [
        start_tag(tag, attrs),
        "\n",
        block_content(children, depth + 1),
        indent(depth),
        end_tag(tag)
      ]
  end

  defp inline_content(nodes, depth, render_element \\ &element/2) do
    nodes = Enum.reject(nodes, &match?({:comment, _}, &1))
    last = length(nodes) - 1

    nodes
    |> Enum.with_index()
    |> Enum.map(fn
      {text, ^last} when is_binary(text) -> inline_text(text, depth, depth - 1)
      {text, _index} when is_binary(text) -> inline_text(text, depth, depth)
      {element, _index} -> render_element.(element, depth)
    end)
  end

  defp inline_text(text, depth, trailing_depth) do
    {leading, middle, trailing} = split_whitespace(text)

    if middle == "",
      do: reindent(leading, trailing_depth),
      else: [reindent(leading, depth), escape_text(middle), reindent(trailing, trailing_depth)]
  end

  defp reindent(whitespace, depth) do
    if String.contains?(whitespace, "\n"), do: ["\n", indent(depth)], else: whitespace
  end

  defp element({tag, attrs, _children}, _depth) when tag in @void_tags, do: start_tag(tag, attrs)

  defp element({tag, attrs, children}, _depth) when tag in @raw_text_tags,
    do: [start_tag(tag, attrs), children, end_tag(tag)]

  defp element({tag, attrs, children}, _depth) when tag in @preformatted_tags,
    do: [start_tag(tag, attrs), preformatted(children), end_tag(tag)]

  defp element({tag, _attrs, _children} = element, depth) when tag in @foreign_tags,
    do: foreign_element(element, depth)

  defp element({tag, attrs, children}, depth),
    do: [start_tag(tag, attrs), inline_content(children, depth + 1), end_tag(tag)]

  # The parser drops a line break right after the start tag, so a leading one is written twice.
  defp preformatted(["\n" <> _ = text | rest]), do: ["\n" | verbatim([text | rest])]
  defp preformatted(children), do: verbatim(children)

  defp verbatim(nodes) do
    Enum.map(nodes, fn
      text when is_binary(text) -> escape_text(text)
      {:comment, _} -> []
      {tag, attrs, children} -> [start_tag(tag, attrs), verbatim(children), end_tag(tag)]
    end)
  end

  defp foreign_element({"foreignObject" = tag, attrs, children}, depth),
    do: [start_tag(tag, attrs), inline_content(children, depth + 1), end_tag(tag)]

  defp foreign_element({tag, attrs, []}, _depth), do: ["<", tag, attributes(attrs), "/>"]

  defp foreign_element({tag, attrs, children}, depth) do
    content = inline_content(children, depth + 1, &foreign_element/2)
    [start_tag(tag, attrs), content, end_tag(tag)]
  end

  defp start_tag(tag, attrs), do: ["<", tag, attributes(attrs), ">"]
  defp end_tag(tag), do: ["</", tag, ">"]

  defp attributes(attrs), do: Enum.map(attrs, &attribute/1)

  defp attribute({name, ""}) when name in @boolean_attributes, do: [" ", name]
  defp attribute({name, value}), do: [" ", name, ~s(="), escape_attribute(value), ~s(")]

  defp escape_text(text) do
    String.replace(text, ["&", "<", ">", "\u00A0"], fn
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      "\u00A0" -> "&nbsp;"
    end)
  end

  defp escape_attribute(value) do
    String.replace(value, ["&", ~s("), "<", ">", "\u00A0"], fn
      "&" -> "&amp;"
      ~s(") -> "&quot;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      "\u00A0" -> "&nbsp;"
    end)
  end

  defp indent(depth), do: String.duplicate(@indent, depth)
end
