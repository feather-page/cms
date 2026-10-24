defmodule Feather.StaticSite.Htaccess do
  @moduledoc """
  The `.htaccess` the export writes for Apache hosts: the 404 page, the
  security headers (ADR 0029), the site's redirects (ADR 0025), the
  Markdown alternates for clients whose `Accept` header names
  `text/markdown` (ADR 0030), UTF-8 for them and text files like
  `llms.txt`, the precompressed files and a year-long immutable cache for
  `style.css`, the image variants and the fonts: their URLs change
  whenever their content does (a hash in the query, or a variant's file
  name that always means the same file). Rules sit in module guards, so a
  host without a module serves plain files instead of failing.

  For a site with a fediverse name it serves the fediverse documents
  (ADR 0033), which have no extension, as `application/activity+json`
  and the WebFinger answer as `application/jrd+json` for any origin, by
  core directives, and their precompressed copies like the text files.

  The content security policy allows only what the themes load: the site's
  own images (the drawn favicon among them), stylesheet and fonts, the
  icon of a page with an emoji of its own as a data URI, inline style
  attributes and HTTPS frames for embeds. No script runs: the structured
  data is a JSON-LD data block, which browsers do not execute. Diagrams
  get a policy of their own for their inline styles, fonts and icons,
  which keeps the framing rule.
  """

  alias Feather.Content.{Page, Post, Project}
  alias Feather.Fediverse
  alias Feather.Redirects
  alias Feather.Redirects.Redirect
  alias Feather.StaticSite.{Precompress, Routes}

  require EEx

  @content_types %{
    ".html" => "text/html",
    ".css" => "text/css",
    ".js" => "text/javascript",
    ".txt" => "text/plain;charset=utf-8",
    ".xml" => "application/xml",
    ".svg" => "image/svg+xml",
    ".md" => "text/markdown;charset=utf-8"
  }

  @content_security_policy [
    "default-src 'none'",
    "img-src 'self' data:",
    "style-src 'self'",
    "style-src-attr 'unsafe-inline'",
    "font-src 'self'",
    "frame-src https:",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'self'"
  ]

  @security_headers [
    {"Strict-Transport-Security", "max-age=31536000"},
    {"X-Content-Type-Options", "nosniff"},
    {"Referrer-Policy", "strict-origin-when-cross-origin"},
    {"Content-Security-Policy", Enum.join(@content_security_policy, "; ")}
  ]

  # Firefox applies an SVG's own policy even where a page shows it as an image.
  @diagram_content_security_policy [
    "default-src 'none'",
    "img-src data:",
    "style-src 'unsafe-inline'",
    "font-src data:",
    "frame-ancestors 'self'"
  ]

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
  an extension also matches with a trailing slash and as its `index.html`
  (`Feather.Redirects.Redirect.catches_index_files?/1`), and a second rule
  sends its `index.md` to the target's Markdown alternate
  (`Feather.Redirects.markdown_target_url/2`). The rules of old paths with
  an extension come first, so a redirect from such an `index.html` or
  `index.md` itself wins. A redirect from a path the fediverse documents
  own (`Feather.StaticSite.Routes.fediverse_path?/1`) gets no rule: one
  from before those paths were reserved must not shadow them.
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
      fediverse: Fediverse.account?(routes.site),
      security_headers: @security_headers,
      diagram_content_security_policy: Enum.join(@diagram_content_security_policy, "; "),
      redirects:
        redirects
        |> Enum.reject(fn {%Redirect{old_path: old_path}, _target} ->
          Routes.fediverse_path?(old_path)
        end)
        |> with_extension_first()
        |> Enum.flat_map(&redirect_rules(routes, &1)),
      encodings: [{"br", ".br"}, {"gzip", ".gz"}],
      extensions: Enum.map_join(content_types, "|", &elem(&1, 0)),
      content_types: content_types
    })
  end

  defp with_extension_first(redirects) do
    Enum.sort_by(redirects, fn {%Redirect{old_path: old_path}, _target} ->
      Redirect.catches_index_files?(old_path)
    end)
  end

  defp redirect_rules(routes, {%Redirect{old_path: old_path} = redirect, target}) do
    path = old_path |> String.trim_leading("/") |> Regex.escape()
    url = target_url(routes, target)

    if Redirect.catches_index_files?(old_path) do
      [
        rule(redirect, "^#{path}(/(index\\.html)?)?$", url),
        rule(redirect, "^#{path}/index\\.md$", Redirects.markdown_target_url(routes, target))
      ]
    else
      [rule(redirect, "^#{path}$", url)]
    end
  end

  defp rule(redirect, pattern, url),
    do: %{pattern: pattern, url: url, status: Redirect.status(redirect)}

  defp target_url(routes, path) when is_binary(path), do: Routes.path_url(routes, path)

  defp target_url(routes, record), do: Routes.record_url(routes, record)
end
