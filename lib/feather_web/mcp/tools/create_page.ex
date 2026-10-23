defmodule FeatherWeb.MCP.Tools.CreatePage do
  @moduledoc """
  The tool `create_page`: writes a page as a draft.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{ContentFields, PageFields, Tool}

  @impl true
  def definition do
    %{
      name: "create_page",
      title: "Create page",
      description:
        "Writes a new page and saves it as a draft, which the site does not show until " <>
          "publish_page. Without a slug, one is suggested from the title. The result links " <>
          "to the editor and the preview, where the member can look at the page before it " <>
          "is published.",
      inputSchema: Tool.input_schema(PageFields.properties(), ["site"]),
      annotations: %{readOnlyHint: false, destructiveHint: false, idempotentHint: false}
    }
  end

  @impl true
  def call(scope, %{"site" => domain} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, attrs} <-
           PageFields.attrs(scope, ContentFields.put_suggested_slug(scope, arguments)) do
      case Content.create_page(scope, attrs) do
        {:ok, page} -> {:ok, PageFields.result(scope, page)}
        {:error, changeset} -> {:error, ContentFields.save_error(changeset, "page")}
      end
    end
  end
end
