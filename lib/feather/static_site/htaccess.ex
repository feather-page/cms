defmodule Feather.StaticSite.Htaccess do
  @moduledoc """
  The `.htaccess` the export writes for Apache hosts: the 404 page, the
  precompressed files and a long cache for `style.css`. Rules sit in module
  guards, so a host without a module serves plain files instead of failing.
  """

  alias Feather.StaticSite.{Precompress, Routes}

  require EEx

  @content_types %{
    ".html" => "text/html",
    ".css" => "text/css",
    ".js" => "text/javascript",
    ".txt" => "text/plain",
    ".xml" => "application/xml",
    ".svg" => "image/svg+xml"
  }

  EEx.function_from_file(
    :defp,
    :template,
    Path.join([__DIR__, "templates", "htaccess.eex"]),
    [:assigns]
  )

  @doc "The content of the `.htaccess` of the site the routes address."
  @spec render(Routes.t()) :: String.t()
  def render(%Routes{} = routes) do
    content_types =
      Enum.map(
        Precompress.extensions(),
        &{String.trim_leading(&1, "."), Map.fetch!(@content_types, &1)}
      )

    template(%{
      not_found_url: Routes.not_found_url(routes),
      encodings: [{"br", ".br"}, {"gzip", ".gz"}],
      extensions: Enum.map_join(content_types, "|", &elem(&1, 0)),
      content_types: content_types
    })
  end
end
