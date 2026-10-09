defmodule Feather.Content.ProseMirror do
  @moduledoc """
  Converts content between the block list (`Feather.Content.Blocks`, the
  stored format) and ProseMirror JSON, the document of the admin editor.

  `from_doc(to_doc(blocks, site))` returns the blocks unchanged, once they
  are normalized and their inline HTML is in the canonical form below.
  Both directions normalize with `Blocks.normalize/1`: content is
  sanitized on its way into the editor and again on its way back, so a
  document from the client is never trusted.

  ## Schema

  The client-side schema of the editor must match this one to one. Every
  attr has a default (`null` unless stated), so a node may omit attrs. Each
  top-level node carries the id of its block in `id`; nested nodes have no
  id.

  Top-level nodes (`doc` content `block+`):

    * `paragraph` - attrs `id`; content `inline*`. Also the first child of
      a `list_item`. Block `paragraph`.
    * `heading` - attrs `id`, `level` (2, 3 or 4, default 2); content
      `inline*`. Block `header`.
    * `bullet_list`, `ordered_list` - attrs `id`; content `list_item+`.
      Block `list` with style `"ul"` or `"ol"`. Nested lists take the type
      of the top-level list, since the block list stores one style.
    * `quote` - attrs `id`; content `quote_text quote_caption`, both
      `inline*`. Block `quote` (`text`, `caption`).
    * `code_block` - attrs `id`, `language` (default `"plaintext"`);
      content `text*`, no marks, `code: true`. Block `code`; the text is
      the raw code, not HTML.
    * `image` - attrs `id`, `image_id` (the image's public id), `src` (the
      admin image URL, for display only, ignored on the way back); content
      `inline*`, the caption. Block `image`.
    * `table` - attrs `id`; content `table_row+`, `table_row` content
      `(table_cell | table_header)*`, cells content `inline*` with the
      prosemirror-tables attrs `colspan`, `rowspan` (default 1) and
      `colwidth`. Block `table`: a first row of `table_header` cells means
      `with_headings`.
    * `embed` - attrs `id`, `service`, `source`, `embed`, `width`,
      `height`; content `inline*`, the caption. Block `embed`.
    * `book` - atom, attrs `id`, `book_public_id`, `title`, `author`,
      `cover_url`, `emoji`. Block `book`.

  Nested nodes: `list_item` (content `paragraph (bullet_list |
  ordered_list)*`), `quote_text`, `quote_caption`, `table_row`,
  `table_cell`, `table_header`. Inline nodes: `text` and `hard_break`
  (`<br>`).

  Marks, in this order (the schema's order decides how marks nest): `link`
  (attrs `href`, `target`, `rel`), `bold` (`<b>`), `italic` (`<i>`),
  `underline` (`<u>`), `code` (`<code>`).

  An empty list or table gets one empty item or cell to type in.
  """

  alias Feather.Content.Blocks

  @type doc :: %{required(String.t()) => term()}
  @type pm_node :: %{required(String.t()) => term()}

  @mark_order ~w(link bold italic underline code)
  @mark_tags %{"bold" => "b", "italic" => "i", "underline" => "u", "code" => "code"}
  @tag_marks Map.new(@mark_tags, fn {mark, tag} -> {tag, mark} end)
  @list_types %{"ul" => "bullet_list", "ol" => "ordered_list"}
  @list_styles Map.new(@list_types, fn {style, type} -> {type, style} end)

  @doc """
  Converts content into a ProseMirror document.

  `site` gives the image URLs; book nodes take title, author and emoji
  from `books` (see `Blocks.put_book/2`).
  """
  @spec to_doc([Blocks.block()] | nil, %{public_id: String.t()}, map()) :: doc()
  def to_doc(blocks, site, books \\ %{}) do
    %{
      "type" => "doc",
      "content" => blocks |> Blocks.normalize() |> Enum.map(&block_to_node(&1, site, books))
    }
  end

  @doc """
  Converts a ProseMirror document into normalized, sanitized content.
  Unknown nodes and marks are dropped.
  """
  @spec from_doc(doc() | nil) :: [Blocks.block()]
  def from_doc(%{"content" => nodes}) when is_list(nodes) do
    nodes
    |> Enum.filter(&is_map/1)
    |> Enum.map(&node_to_block/1)
    |> Blocks.normalize()
  end

  def from_doc(_doc), do: []

  @doc """
  Converts one top-level node into a normalized block, or nil if the node
  is not a block.
  """
  @spec from_node(pm_node()) :: Blocks.block() | nil
  def from_node(node) do
    case from_doc(%{"content" => [node]}) do
      [block] -> block
      [] -> nil
    end
  end

  # Block list to ProseMirror

  defp block_to_node(%{"type" => "paragraph"} = b, _site, _books),
    do: node("paragraph", %{"id" => b["id"]}, inline_nodes(b["text"]))

  defp block_to_node(%{"type" => "header"} = b, _site, _books),
    do: node("heading", %{"id" => b["id"], "level" => b["level"]}, inline_nodes(b["text"]))

  defp block_to_node(%{"type" => "list"} = b, _site, _books) do
    list_node(@list_types[b["style"]], %{"id" => b["id"]}, b["items"])
  end

  defp block_to_node(%{"type" => "quote"} = b, _site, _books) do
    node("quote", %{"id" => b["id"]}, [
      node("quote_text", nil, inline_nodes(b["text"])),
      node("quote_caption", nil, inline_nodes(b["caption"]))
    ])
  end

  defp block_to_node(%{"type" => "code"} = b, _site, _books) do
    content = if b["code"] in [nil, ""], do: [], else: [text_node(b["code"], [])]
    node("code_block", %{"id" => b["id"], "language" => b["language"]}, content)
  end

  defp block_to_node(%{"type" => "image"} = b, site, _books) do
    attrs = %{
      "id" => b["id"],
      "image_id" => b["image_id"],
      "src" => Blocks.image_url(site, b["image_id"])
    }

    node("image", attrs, inline_nodes(b["caption"]))
  end

  defp block_to_node(%{"type" => "table"} = b, _site, _books) do
    rows =
      case b["content"] do
        [_ | _] = rows -> rows
        _empty -> [[""]]
      end

    rows =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {cells, index} ->
        cell_type = if index == 0 and b["with_headings"], do: "table_header", else: "table_cell"
        cells = if cells == [], do: [""], else: cells
        node("table_row", nil, Enum.map(cells, &node(cell_type, nil, inline_nodes(&1))))
      end)

    node("table", %{"id" => b["id"]}, rows)
  end

  defp block_to_node(%{"type" => "embed"} = b, _site, _books) do
    attrs = Map.take(b, ~w(id service source embed width height))
    node("embed", attrs, inline_nodes(b["caption"]))
  end

  defp block_to_node(%{"type" => "book"} = b, _site, books) do
    attrs = b |> Blocks.put_book(books) |> Map.delete("type")
    node("book", attrs, [])
  end

  defp list_node(type, attrs, items) do
    items = if items == [], do: [%{"content" => "", "items" => []}], else: items

    node(
      type,
      attrs,
      Enum.map(items, fn item ->
        nested = if item["items"] == [], do: [], else: [list_node(type, nil, item["items"])]
        node("list_item", nil, [node("paragraph", nil, inline_nodes(item["content"])) | nested])
      end)
    )
  end

  defp node(type, attrs, content) do
    [{"type", type}, {"attrs", attrs}, {"content", content}]
    |> Enum.reject(fn {_key, value} -> value in [nil, []] end)
    |> Map.new()
  end

  defp text_node(text, []), do: %{"type" => "text", "text" => text}
  defp text_node(text, marks), do: %{"type" => "text", "text" => text, "marks" => marks}

  # Inline HTML (sanitized by Blocks.normalize/1, so well-formed and made
  # of the allowed tags only) to text nodes with marks and hard breaks.
  defp inline_nodes(html) when html in [nil, ""], do: []

  defp inline_nodes(html) do
    html
    |> :floki_mochi_html.tokens()
    |> Enum.reduce({[], []}, &inline_token/2)
    |> elem(0)
    |> Enum.reverse()
  end

  defp inline_token({:data, text, _whitespace?}, {nodes, marks}),
    do: {add_text(nodes, text, sort_marks(marks)), marks}

  defp inline_token({:start_tag, "br", _attributes, _self_closing?}, {nodes, marks}),
    do: {[%{"type" => "hard_break"} | nodes], marks}

  defp inline_token({:start_tag, "a", attributes, _self_closing?}, {nodes, marks}) do
    attributes = Map.new(attributes)
    attrs = Map.new(~w(href target rel), &{&1, attributes[&1]})
    {nodes, put_mark(marks, %{"type" => "link", "attrs" => attrs})}
  end

  defp inline_token({:start_tag, tag, _attributes, _self_closing?}, {nodes, marks})
       when is_map_key(@tag_marks, tag),
       do: {nodes, put_mark(marks, %{"type" => @tag_marks[tag]})}

  defp inline_token({:end_tag, tag}, {nodes, marks}) do
    type = if tag == "a", do: "link", else: @tag_marks[tag]
    {nodes, Enum.reject(marks, &(&1["type"] == type))}
  end

  defp inline_token(_token, acc), do: acc

  defp put_mark(marks, mark), do: [mark | Enum.reject(marks, &(&1["type"] == mark["type"]))]

  defp add_text(nodes, "", _marks), do: nodes

  defp add_text([%{"type" => "text"} = previous | rest] = nodes, text, marks) do
    if Map.get(previous, "marks", []) == marks,
      do: [%{previous | "text" => previous["text"] <> text} | rest],
      else: [text_node(text, marks) | nodes]
  end

  defp add_text(nodes, text, marks), do: [text_node(text, marks) | nodes]

  defp sort_marks(marks), do: Enum.sort_by(marks, &mark_rank(&1["type"]))

  defp mark_rank(type), do: Enum.find_index(@mark_order, &(&1 == type))

  # ProseMirror to block list (normalized by the caller)

  defp node_to_block(%{"type" => "paragraph"} = n),
    do: %{"id" => id(n), "type" => "paragraph", "text" => inline_html(n)}

  defp node_to_block(%{"type" => "heading"} = n),
    do: %{
      "id" => id(n),
      "type" => "header",
      "level" => attr(n, "level"),
      "text" => inline_html(n)
    }

  defp node_to_block(%{"type" => type} = n) when is_map_key(@list_styles, type),
    do: %{
      "id" => id(n),
      "type" => "list",
      "style" => @list_styles[type],
      "items" => list_items(n)
    }

  defp node_to_block(%{"type" => "quote"} = n) do
    %{
      "id" => id(n),
      "type" => "quote",
      "text" => n |> child("quote_text") |> inline_html(),
      "caption" => n |> child("quote_caption") |> inline_html()
    }
  end

  defp node_to_block(%{"type" => "code_block"} = n) do
    code = n |> children() |> Enum.map_join(&text_of/1)
    %{"id" => id(n), "type" => "code", "code" => code, "language" => attr(n, "language")}
  end

  defp node_to_block(%{"type" => "image"} = n) do
    %{
      "id" => id(n),
      "type" => "image",
      "image_id" => attr(n, "image_id"),
      "caption" => inline_html(n)
    }
  end

  defp node_to_block(%{"type" => "table"} = n) do
    rows = Enum.map(children(n), &children/1)

    with_headings =
      case rows do
        [[_ | _] = first | _] -> Enum.all?(first, &(&1["type"] == "table_header"))
        _empty -> false
      end

    %{
      "id" => id(n),
      "type" => "table",
      "content" => Enum.map(rows, fn cells -> Enum.map(cells, &inline_html/1) end),
      "with_headings" => with_headings
    }
  end

  defp node_to_block(%{"type" => "embed"} = n) do
    n
    |> attrs()
    |> Map.take(~w(service source embed width height))
    |> Map.merge(%{"id" => id(n), "type" => "embed", "caption" => inline_html(n)})
  end

  defp node_to_block(%{"type" => "book"} = n) do
    n
    |> attrs()
    |> Map.take(~w(book_public_id title author cover_url emoji))
    |> Map.merge(%{"id" => id(n), "type" => "book"})
  end

  defp node_to_block(_node), do: %{"type" => nil}

  defp list_items(list) do
    list
    |> children()
    |> Enum.filter(&(&1["type"] == "list_item"))
    |> Enum.map(fn item ->
      {paragraphs, lists} = item |> children() |> Enum.split_with(&(&1["type"] == "paragraph"))

      %{
        "content" => Enum.map_join(paragraphs, "<br>", &inline_html/1),
        "items" =>
          lists
          |> Enum.filter(&is_map_key(@list_styles, &1["type"]))
          |> Enum.flat_map(&list_items/1)
      }
    end)
  end

  defp id(node), do: attr(node, "id")
  defp attr(node, name), do: attrs(node)[name]

  defp attrs(%{"attrs" => %{} = attrs}), do: attrs
  defp attrs(_node), do: %{}

  defp children(%{"content" => content}) when is_list(content),
    do: Enum.filter(content, &is_map/1)

  defp children(_node), do: []

  defp child(node, type), do: Enum.find(children(node), &(&1["type"] == type))

  defp text_of(%{"type" => "text", "text" => text}) when is_binary(text), do: text
  defp text_of(_node), do: ""

  # Text nodes with marks to inline HTML. Marks are opened in their order,
  # and those shared with the previous node stay open; Blocks.normalize/1
  # sanitizes the result.
  defp inline_html(node) do
    {html, open} =
      node
      |> children()
      |> Enum.reduce({[], []}, fn child, {html, open} ->
        case child do
          %{"type" => "hard_break"} ->
            {[html, close_marks(open), "<br>"], []}

          %{"type" => "text"} ->
            marks = child |> Map.get("marks") |> known_marks()
            shared = shared_prefix(open, marks)
            closing = Enum.drop(open, length(shared))
            opening = Enum.drop(marks, length(shared))

            {[
               html,
               close_marks(closing),
               Enum.map(opening, &open_mark/1),
               escape(text_of(child))
             ], marks}

          _other ->
            {html, open}
        end
      end)

    IO.iodata_to_binary([html, close_marks(open)])
  end

  defp known_marks(marks) when is_list(marks) do
    marks
    |> Enum.filter(&(is_map(&1) and &1["type"] in @mark_order))
    |> Enum.uniq_by(& &1["type"])
    |> sort_marks()
  end

  defp known_marks(_marks), do: []

  defp shared_prefix(open, marks) do
    open
    |> Enum.zip(marks)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> Enum.map(&elem(&1, 0))
  end

  defp open_mark(%{"type" => "link"} = mark) do
    attributes =
      for name <- ~w(href target rel),
          value = attr(mark, name),
          is_binary(value),
          do: [" ", name, ~s(="), escape(value), ~s(")]

    ["<a", attributes, ">"]
  end

  defp open_mark(%{"type" => type}), do: ["<", @mark_tags[type], ">"]

  defp close_marks(open) do
    open
    |> Enum.reverse()
    |> Enum.map(fn
      %{"type" => "link"} -> "</a>"
      %{"type" => type} -> ["</", @mark_tags[type], ">"]
    end)
  end

  defp escape(text), do: Plug.HTML.html_escape(text)
end
