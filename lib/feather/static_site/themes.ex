defmodule Feather.StaticSite.Themes do
  @moduledoc """
  The themes of the static site (ADR 0015): a fixed list in code, each a
  key, a label and a module implementing `Feather.StaticSite.Theme`.
  Every site uses `feather` for now.
  """

  alias Feather.Sites.Site

  @themes [
    %{key: "feather", label: "feather.page", module: Feather.StaticSite.Themes.FeatherPage}
  ]

  @type key :: String.t()

  @doc "The keys of all themes."
  @spec keys() :: [key()]
  def keys, do: Enum.map(@themes, & &1.key)

  @doc "The themes as `{label, key}` options for a select."
  @spec options() :: [{String.t(), key()}]
  def options, do: Enum.map(@themes, &{&1.label, &1.key})

  @doc "The module of a theme, by key or by the site that uses it. Raises for unknown keys."
  @spec module(key() | Site.t()) :: module()
  def module(%Site{}), do: module("feather")

  def module(key) when is_binary(key) do
    case Enum.find(@themes, &(&1.key == key)) do
      %{module: module} -> module
      nil -> raise ArgumentError, "unknown theme #{inspect(key)}"
    end
  end
end
