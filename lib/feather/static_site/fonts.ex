defmodule Feather.StaticSite.Fonts do
  @moduledoc """
  The web fonts of the static site theme, kept in `priv/static_site/fonts/`
  and written into every exported site under `fonts/`: Nunito 700 and 800
  for headings (Latin subset of `@fontsource/nunito` 5.2.7) and its licence,
  the SIL Open Font License.
  """

  @files %{
    "nunito-latin-700.woff2" => "font/woff2",
    "nunito-latin-800.woff2" => "font/woff2",
    "OFL.txt" => "text/plain"
  }

  @doc "The file names under `fonts/`."
  @spec files() :: [String.t()]
  def files, do: @files |> Map.keys() |> Enum.sort()

  @doc "Returns true if the theme ships a font file of that name."
  @spec file?(String.t()) :: boolean()
  def file?(name), do: Map.has_key?(@files, name)

  @doc "The path of a font file in the app's priv directory."
  @spec path(String.t()) :: Path.t()
  def path(name), do: Application.app_dir(:feather, ["priv", "static_site", "fonts", name])

  @doc "The content type of a font file."
  @spec content_type(String.t()) :: String.t()
  def content_type(name), do: Map.fetch!(@files, name)
end
