defmodule Feather.StaticSite.Htaccess do
  @moduledoc """
  The `.htaccess` the export writes for Apache hosts: the 404 page, the
  site's redirects (ADR 0025), the precompressed files and a year-long
  immutable cache for `style.css`, the image variants and the fonts: their
  URLs change whenever their content does (a hash in the query, or a
  variant's file name that always means the same file). Rules sit in
  module guards, so a host without a module serves plain files instead of
  failing.
  """

  alias Feather.Content.{Page, Post, Project}
  alias Feather.Redirects.Redirect
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

  @doc """
  The content of the `.htaccess` of the site the routes address, with a
  rewrite rule for each of the redirects, given with the record or path
  they lead to (see `Feather.StaticSite.SiteData`). An old path without
  an extension matches with and without a trailing slash.
  """
  @spec render(Routes.t(), [{Redirect.t(), Post.t() | Page.t() | Project.t() | String.t()}]) ::
          String.t()
  def render(%Routes{} = routes, redirects) do
    content_types =
      Enum.map(
        Precompress.extensions(),
        &{String.trim_leading(&1, "."), Map.fetch!(@content_types, &1)}
      )

    template(%{
      not_found_url: Routes.not_found_url(routes),
      redirects: Enum.map(redirects, &redirect_rule(routes, &1)),
      encodings: [{"br", ".br"}, {"gzip", ".gz"}],
      extensions: Enum.map_join(content_types, "|", &elem(&1, 0)),
      content_types: content_types
    })
  end

  defp redirect_rule(routes, {%Redirect{old_path: old_path} = redirect, target}) do
    %{
      pattern: old_path_pattern(old_path),
      url: target_url(routes, target),
      status: Redirect.status(redirect)
    }
  end

  defp old_path_pattern(old_path) do
    path = old_path |> String.trim_leading("/") |> Regex.escape()
    if Path.extname(old_path) == "", do: "^#{path}/?$", else: "^#{path}$"
  end

  defp target_url(routes, path) when is_binary(path), do: Routes.path_url(routes, path)

  defp target_url(routes, record), do: Routes.record_url(routes, record)
end
