defmodule FeatherWeb.MCP.PageFields do
  @moduledoc """
  The fields of a page in the page tools, those of the page form: their
  input schema, the attributes they set and a page as a tool result.
  `in_navigation` is the form's "Add to navigation".
  """

  use FeatherWeb, :verified_routes

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias Feather.Content.Page
  alias FeatherWeb.MCP.ContentFields

  @fields ~w(title slug description emoji tags page_type header_image thumbnail_image content)

  @doc "The input schema properties of the page's fields."
  @spec properties() :: map()
  def properties do
    %{
      "title" => %{"type" => ["string", "null"]},
      "slug" => %{
        "type" => "string",
        "description" =>
          "The page's path on the site, such as /about; the page at / is the homepage"
      },
      "description" => %{
        "type" => ["string", "null"],
        "description" => "One sentence for search results and link previews"
      },
      "emoji" => %{"type" => ["string", "null"], "description" => "An emoji for the page"},
      "tags" => ContentFields.tags_property(),
      "page_type" => %{
        "type" => "string",
        "enum" => Page.page_types(),
        "description" =>
          "default shows the content, books the content and the bookshelf, projects the " <>
            "content and the site's projects; default by default"
      },
      "in_navigation" => %{
        "type" => "boolean",
        "description" =>
          "Whether the site's main navigation links the page, at its end when added. The " <>
            "navigation shows only published pages and is not part of the unpublished " <>
            "changes: it changes on the live site with the next deploy_site."
      },
      "header_image" => ContentFields.image_property("The image shown large above the page"),
      "thumbnail_image" => ContentFields.image_property("The page's thumbnail"),
      "content" => ContentFields.content_property()
    }
  end

  @doc """
  The page's attributes among the arguments, with content, images and tags
  as `Feather.Content` takes them and `in_navigation` as
  `add_to_navigation`.
  """
  @spec attrs(Scope.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def attrs(%Scope{} = scope, arguments) do
    with {:ok, attrs} <- ContentFields.cast(scope, Map.take(arguments, @fields)) do
      case Map.fetch(arguments, "in_navigation") do
        {:ok, in_navigation} -> {:ok, Map.put(attrs, "add_to_navigation", in_navigation)}
        :error -> {:ok, attrs}
      end
    end
  end

  @doc "The page of the site with the public id `id`."
  @spec fetch_page(Scope.t(), String.t()) :: {:ok, Page.t()} | {:error, String.t()}
  def fetch_page(%Scope{} = scope, id) do
    case Content.get_page(scope, id) do
      nil ->
        {:error, "There is no page #{id} on #{scope.site.domain}. list_pages lists its pages."}

      page ->
        {:ok, page}
    end
  end

  @doc """
  A page as a tool result: its fields, `id` (its public id), its
  publication `status`, the `lock_version` an update builds on and the
  links to the editor and the preview.
  """
  @spec result(Scope.t(), Page.t()) :: map()
  def result(%Scope{} = scope, %Page{} = page) do
    page = Content.preload_images(page)

    %{
      id: page.public_id,
      title: page.title,
      slug: page.slug,
      description: page.description,
      emoji: page.emoji,
      tags: Content.tag_list(page),
      page_type: page.page_type,
      in_navigation: page.add_to_navigation,
      header_image: ContentFields.public_id(page.header_image),
      thumbnail_image: ContentFields.public_id(page.thumbnail_image),
      content: ContentFields.content(page),
      status: Content.publication_status(page),
      lock_version: page.lock_version,
      editor_url: url(~p"/sites/#{scope.site.public_id}/pages/#{page.public_id}/edit"),
      preview_url: ContentFields.preview_url(scope, page)
    }
  end

  @doc "A page as an entry of a list."
  @spec summary(Page.t()) :: map()
  def summary(%Page{} = page) do
    %{
      id: page.public_id,
      title: page.title,
      slug: page.slug,
      page_type: page.page_type,
      in_navigation: page.add_to_navigation,
      status: Content.publication_status(page)
    }
  end
end
