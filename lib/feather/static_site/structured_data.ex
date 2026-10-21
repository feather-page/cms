defmodule Feather.StaticSite.StructuredData do
  @moduledoc """
  The schema.org structured data (JSON-LD) in the head of a page, from the
  assigns `Feather.StaticSite.Renderer` builds: on the first page of the
  post list the `WebSite` and the `Person` it belongs to, named after the
  site title; on a post a `BlogPosting` by that person, and for a review
  also the `Review` of its `Book`. Other pages carry none.
  """

  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.Post
  alias Feather.Media.{Image, Variants}
  alias Feather.StaticSite.{Routes, Themes}

  @context "https://schema.org"

  @doc "The structured data of a page as a JSON-LD document, nil for pages without."
  @spec for_page(atom(), map()) :: map() | nil
  def for_page(:home, %{current_page: 1} = assigns),
    do: graph([website(assigns), person(assigns)])

  def for_page(:post, %{post: %Post{} = post} = assigns),
    do: graph([blog_posting(assigns, post) | review(assigns, post)])

  def for_page(_view, _assigns), do: nil

  @doc """
  Encodes structured data for a `<script type="application/ld+json">`:
  `<`, `>` and `&` are escaped so that no text can end the script.
  """
  @spec encode(map()) :: Phoenix.HTML.safe()
  def encode(data) do
    {:safe,
     data
     |> Jason.encode!()
     |> String.replace(["<", ">", "&"], &escape_char/1)}
  end

  defp escape_char("<"), do: "\\u003c"
  defp escape_char(">"), do: "\\u003e"
  defp escape_char("&"), do: "\\u0026"

  defp graph(nodes), do: %{"@context" => @context, "@graph" => nodes}

  defp website(assigns) do
    home = home_url(assigns)

    compact(%{
      "@type" => "WebSite",
      "@id" => home <> "#website",
      "url" => home,
      "name" => assigns.site.title,
      "description" => assigns.description,
      "inLanguage" => language(assigns),
      "publisher" => person_ref(assigns)
    })
  end

  defp person(assigns) do
    home = home_url(assigns)

    compact(%{
      "@type" => "Person",
      "@id" => home <> "#person",
      "name" => assigns.site.title,
      "url" => home,
      "description" => present(assigns.site.bio),
      "image" => portrait_url(assigns),
      "sameAs" => same_as(assigns.social_links)
    })
  end

  defp person_ref(assigns), do: %{"@id" => home_url(assigns) <> "#person"}

  defp author(assigns) do
    assigns
    |> person_ref()
    |> Map.merge(%{"@type" => "Person", "name" => assigns.site.title, "url" => home_url(assigns)})
  end

  defp same_as(links) do
    case for(%{url: url} <- links, absolute_web_url?(url), do: url) do
      [] -> nil
      urls -> urls
    end
  end

  defp absolute_web_url?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] -> host not in [nil, ""]
      _other -> false
    end
  end

  # Only a theme that shows the portrait exports its files.
  defp portrait_url(%{site: %{portrait_image: %Image{} = image} = site, routes: routes}) do
    theme = Themes.module(site)

    if :portrait_image_id in theme.site_image_fields() do
      sizes = Map.get(theme.image_variants(), :portrait, [])

      case Variants.for_image(sizes, image.width, image.height) do
        [] -> nil
        variants -> Routes.image_url(Routes.canonical(routes), image, List.last(variants))
      end
    end
  end

  defp portrait_url(_assigns), do: nil

  defp blog_posting(assigns, post) do
    compact(%{
      "@type" => "BlogPosting",
      "headline" => assigns.meta_title,
      "url" => assigns.canonical_url,
      "mainEntityOfPage" => assigns.canonical_url,
      "datePublished" => iso8601(post.publish_at),
      "dateModified" => iso8601(Content.last_changed_or_updated_at(post)),
      "description" => assigns.description,
      "image" => assigns.og_image_url,
      "inLanguage" => language(assigns),
      "author" => author(assigns)
    })
  end

  defp review(assigns, %Post{book: %Book{} = book} = post) do
    [
      compact(%{
        "@type" => "Review",
        "url" => assigns.canonical_url,
        "datePublished" => iso8601(post.publish_at),
        "author" => person_ref(assigns),
        "itemReviewed" => reviewed_book(book),
        "reviewRating" => rating(book.rating)
      })
    ]
  end

  defp review(_assigns, _post), do: []

  defp reviewed_book(book) do
    compact(%{
      "@type" => "Book",
      "name" => book.title,
      "author" => %{"@type" => "Person", "name" => book.author},
      "isbn" => present(book.isbn)
    })
  end

  defp rating(nil), do: nil

  defp rating(value),
    do: %{"@type" => "Rating", "ratingValue" => value, "bestRating" => 5, "worstRating" => 1}

  defp home_url(assigns), do: assigns.routes |> Routes.canonical() |> Routes.home_url()

  defp language(assigns), do: assigns.site.language_code || "en"

  defp iso8601(nil), do: nil

  defp iso8601(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp present(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp present(_value), do: nil

  defp compact(map), do: map |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new()
end
