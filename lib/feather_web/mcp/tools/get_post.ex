defmodule FeatherWeb.MCP.Tools.GetPost do
  @moduledoc """
  The tool `get_post`: a post with all its fields and content.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias FeatherWeb.MCP.{PostFields, Tool}

  @impl true
  def definition do
    %{
      name: "get_post",
      title: "Get post",
      description:
        "Gives a post as it is saved, unpublished changes included: its fields, its content " <>
          "as JSON blocks, its publication status, the lock_version update_post and " <>
          "publish_post need and links to the editor and the preview.",
      inputSchema:
        Tool.input_schema(
          %{"post" => %{"type" => "string", "description" => "The post's id from list_posts"}},
          ["site", "post"]
        ),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "post" => id}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, post} <- PostFields.fetch_post(scope, id) do
      {:ok, PostFields.result(scope, post)}
    end
  end
end
