defmodule Feather.StaticSite.Xml do
  @moduledoc """
  A minimal XML writer for the feed and the sitemap: elements as iodata,
  text and attribute values escaped, characters XML 1.0 forbids removed.
  """

  @declaration ~s(<?xml version="1.0" encoding="UTF-8"?>\n)

  @doc "The XML declaration line."
  @spec declaration() :: String.t()
  def declaration, do: @declaration

  @doc """
  An element on its own line, indented by `depth` levels of two spaces.
  `content` is text (escaped), a list of child lines (already built with
  `element/4`) or nil for an empty element.
  """
  @spec element(non_neg_integer(), String.t(), [{String.t(), term()}], term()) :: iodata()
  def element(depth, name, attributes \\ [], content)

  def element(depth, name, attributes, nil),
    do: [indent(depth), "<", name, attributes(attributes), "/>\n"]

  def element(depth, name, attributes, children) when is_list(children) do
    [
      indent(depth),
      ["<", name, attributes(attributes), ">\n"],
      children,
      [indent(depth), "</", name, ">\n"]
    ]
  end

  def element(depth, name, attributes, text) do
    [indent(depth), "<", name, attributes(attributes), ">", escape(text), "</", name, ">\n"]
  end

  @doc "Escapes text for XML content and attribute values."
  @spec escape(term()) :: String.t()
  def escape(value) do
    value
    |> to_string()
    |> String.replace_invalid("")
    |> String.replace(
      ~r/[^\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]/u,
      ""
    )
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp attributes(attributes) do
    Enum.map(attributes, fn {name, value} -> [" ", name, "=\"", escape(value), "\""] end)
  end

  defp indent(depth), do: String.duplicate("  ", depth)
end
