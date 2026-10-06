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
  parsed with Floki (entities decoded), and the output is rebuilt from the
  parsed tree with every text node and attribute value escaped. The `href`
  a browser sees is therefore exactly the decoded value checked here.
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
    case Floki.parse_fragment(html) do
      {:ok, nodes} -> nodes |> Enum.map(&node_to_iodata/1) |> IO.iodata_to_binary()
      {:error, _reason} -> escape(html)
    end
  end

  def sanitize(other), do: other |> to_string() |> sanitize()

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

  defp node_to_iodata(text) when is_binary(text), do: escape(text)

  defp node_to_iodata({tag, attributes, children}) when is_binary(tag) do
    tag = String.downcase(tag)

    cond do
      tag in @allowed_tags ->
        ["<", tag, attributes_to_iodata(tag, attributes), ">", children_to_iodata(children)] ++
          ["</", tag, ">"]

      tag in @dropped_content_tags ->
        []

      true ->
        children_to_iodata(children)
    end
  end

  # Comments, processing instructions, doctypes and anything else.
  defp node_to_iodata(_node), do: []

  defp children_to_iodata(children) when is_list(children),
    do: Enum.map(children, &node_to_iodata/1)

  defp children_to_iodata(_children), do: []

  defp attributes_to_iodata("a", attributes) do
    attributes
    |> Enum.find_value(fn {name, value} ->
      if String.downcase(name) == "href" and safe_url?(value), do: value
    end)
    |> case do
      nil -> []
      href -> [~s( href="), escape(href), ~s(")]
    end
  end

  defp attributes_to_iodata(_tag, _attributes), do: []

  defp escape(text) do
    text
    |> strip_invalid()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  # Invalid UTF-8 would make the output undecodable for the browser.
  defp strip_invalid(text) do
    if String.valid?(text), do: text, else: String.replace_invalid(text, "")
  end
end
