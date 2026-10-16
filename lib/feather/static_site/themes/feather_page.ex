defmodule Feather.StaticSite.Themes.FeatherPage do
  @moduledoc """
  The `feather` theme, ported from the Rails ERB views: a narrow column
  with a masthead on the home page, a breadcrumb elsewhere and the site's
  mascots, headings in Nunito. Templates in `feather_page/*.html.eex`,
  stylesheet and fonts in `priv/static_site/themes/feather_page/`.
  """

  use Feather.StaticSite.Theme

  alias Feather.Content
  alias Feather.Content.HTML
  alias Feather.Media.Image
  alias Feather.StaticSite.{Blocks, Routes}

  @priv_dir Path.expand("../../../../priv/static_site/themes/feather_page", __DIR__)
  @css_path Path.join(@priv_dir, "theme.css")
  @external_resource @css_path
  @css File.read!(@css_path)

  @fonts %{
    "nunito-latin-700.woff2" => "font/woff2",
    "nunito-latin-800.woff2" => "font/woff2",
    "OFL.txt" => "text/plain"
  }

  @views ~w(layout home post page project not_found)a
  @partials ~w(masthead post_book_card books_list projects_list project_card tags)a

  for name <- @views ++ @partials do
    if name in @views, do: @impl(true)

    EEx.function_from_file(
      :def,
      name,
      Path.join([__DIR__, "feather_page", "#{name}.html.eex"]),
      [:assigns],
      engine: Phoenix.HTML.Engine,
      trim: true
    )
  end

  @impl true
  def css, do: @css

  @impl true
  def font_faces(%Routes{} = routes) do
    {:safe,
     [
       font_face(routes, "Nunito", 700, ["Nunito Bold", "Nunito-Bold"], "nunito-latin-700.woff2"),
       font_face(
         routes,
         "Nunito",
         800,
         ["Nunito ExtraBold", "Nunito-ExtraBold"],
         "nunito-latin-800.woff2"
       )
     ]}
  end

  # Nunito 700 and 800, Latin subset of @fontsource/nunito 5.2.7, SIL Open Font License.
  @impl true
  def fonts, do: @fonts

  @impl true
  def font_path(name),
    do: Application.app_dir(:feather, "priv/static_site/themes/feather_page/fonts/#{name}")

  defp chip(href, emoji, title, current? \\ false) do
    {class, seal} =
      if present?(emoji),
        do: {"chip", [~s(<span class="seal" aria-hidden="true">), escape(emoji), "</span>"]},
        else: {"chip chip--plain", []}

    {:safe,
     [
       ~s(<a class="),
       class,
       ~s(" href="),
       escape(href),
       ~s("),
       if(current?, do: ~s( aria-current="page"), else: ""),
       ">",
       seal,
       escape(title),
       "</a>"
     ]}
  end

  # Mascots are characters, not content: decorative, so alt is empty.
  defp mascot(routes, %Image{} = image, class, sizes, opts \\ []) do
    {:safe,
     [
       ~s(<img class="),
       class,
       ~s(" src="),
       escape(Routes.image_url(routes, image, :mobile_x1_webp)),
       ~s(" srcset="),
       escape(Routes.image_srcset(routes, image)),
       ~s(" sizes="),
       escape(sizes),
       ~s("),
       image |> dimensions() |> elem(1),
       if(Keyword.get(opts, :lazy, true), do: ~s( loading="lazy"), else: ""),
       ~s( alt="">)
     ]}
  end

  defp not_found_mascot(site), do: site.post_end_mascot_image || site.projects_mascot_image
end
