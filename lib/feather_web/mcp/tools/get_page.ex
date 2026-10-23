defmodule FeatherWeb.MCP.Tools.GetPage do
  @moduledoc """
  The tool `get_page`: a page with all its fields and content.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias FeatherWeb.MCP.{PageFields, Tool}

  @impl true
  def definition do
    %{
      name: "get_page",
      title: "Get page",
      description:
        "Gives a page as it is saved, unpublished changes included: its fields, its content " <>
          "as JSON blocks, its publication status, the lock_version update_page and " <>
          "publish_page need and links to the editor and the preview.",
      inputSchema:
        Tool.input_schema(
          %{"page" => %{"type" => "string", "description" => "The page's id from list_pages"}},
          ["site", "page"]
        ),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "page" => id}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, page} <- PageFields.fetch_page(scope, id) do
      {:ok, PageFields.result(scope, page)}
    end
  end
end
