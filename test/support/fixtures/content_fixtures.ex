defmodule Feather.ContentFixtures do
  @moduledoc """
  Test helpers for posts, pages and projects. All take a scope with a site.

  The records are published (version 1) unless `draft: true` is given.
  """

  alias Feather.Content

  def unique_slug(prefix \\ "item"), do: "/#{prefix}-#{System.unique_integer([:positive])}"

  def paragraph(text), do: %{"type" => "paragraph", "text" => text}

  def post_fixture(scope, attrs \\ %{}) do
    {draft, attrs} = pop_draft(attrs)

    {:ok, post} =
      Content.create_post(
        scope,
        Enum.into(attrs, %{
          title: "A post",
          slug: unique_slug("post"),
          content: [paragraph("Hello from a post.")]
        })
      )

    publish_unless_draft(scope, post, draft)
  end

  def page_fixture(scope, attrs \\ %{}) do
    {draft, attrs} = pop_draft(attrs)

    {:ok, page} =
      Content.create_page(
        scope,
        Enum.into(attrs, %{
          title: "A page",
          slug: unique_slug("page"),
          content: [paragraph("Hello from a page.")]
        })
      )

    publish_unless_draft(scope, page, draft)
  end

  def project_fixture(scope, attrs \\ %{}) do
    {draft, attrs} = pop_draft(attrs)

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

    publish_unless_draft(scope, project, draft)
  end

  defp pop_draft(attrs), do: attrs |> Map.new() |> Map.pop(:draft, false)

  defp publish_unless_draft(_scope, record, true), do: record

  defp publish_unless_draft(scope, record, false) do
    {:ok, record} = Content.publish(scope, record)
    record
  end
end
