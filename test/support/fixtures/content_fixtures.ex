defmodule Feather.ContentFixtures do
  @moduledoc """
  Test helpers for posts, pages and projects. All take a scope with a site.
  """

  alias Feather.Content

  def unique_slug(prefix \\ "item"), do: "/#{prefix}-#{System.unique_integer([:positive])}"

  def paragraph(text), do: %{"type" => "paragraph", "text" => text}

  def post_fixture(scope, attrs \\ %{}) do
    {:ok, post} =
      Content.create_post(
        scope,
        Enum.into(attrs, %{
          title: "A post",
          slug: unique_slug("post"),
          content: [paragraph("Hello from a post.")]
        })
      )

    post
  end

  def page_fixture(scope, attrs \\ %{}) do
    {:ok, page} =
      Content.create_page(
        scope,
        Enum.into(attrs, %{
          title: "A page",
          slug: unique_slug("page"),
          content: [paragraph("Hello from a page.")]
        })
      )

    page
  end

  def project_fixture(scope, attrs \\ %{}) do
    {:ok, project} =
      Content.create_project(
        scope,
        Enum.into(attrs, %{
          title: "A project",
          slug: unique_slug("project"),
          short_description: "Something I built.",
          started_at: ~D[2024-03-01]
        })
      )

    project
  end
end
