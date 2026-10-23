defmodule FeatherWeb.MCP.Tools.ListPosts do
  @moduledoc """
  The tool `list_posts`: the site's posts, newest first.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{PostFields, Tool}

  @impl true
  def definition do
    %{
      name: "list_posts",
      title: "List posts",
      description:
        "Lists the site's posts, newest publish_at first, with their id for get_post, " <>
          "update_post and publish_post. A short post has no title; excerpt gives the start " <>
          "of its text. book is the id of the book a review is about.",
      inputSchema: Tool.input_schema(%{}, ["site"]),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      posts = scope |> Content.list_posts() |> Content.preload_post_details()
      {:ok, %{posts: Enum.map(posts, &PostFields.summary/1)}}
    end
  end
end
