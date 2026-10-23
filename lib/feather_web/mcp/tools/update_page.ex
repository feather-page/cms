defmodule FeatherWeb.MCP.Tools.UpdatePage do
  @moduledoc """
  The tool `update_page`: saves changes to a page as its unpublished
  changes, on the lock version the agent read.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{ContentFields, PageFields, Tool}

  @impl true
  def definition do
    %{
      name: "update_page",
      title: "Update page",
      description:
        "Changes a page: only the fields given; null clears a field. The changes are saved " <>
          "as unpublished changes: the site shows the page as it was until publish_page. " <>
          "lock_version is the one get_page, create_page or update_page gave last; if the " <>
          "page was changed elsewhere since, such as in the editor, nothing is saved.",
      inputSchema:
        Tool.input_schema(
          Map.merge(PageFields.properties(), %{
            "page" => %{"type" => "string", "description" => "The page's id from list_pages"},
            "lock_version" => %{
              "type" => "integer",
              "description" => "The page's lock_version this change builds on"
            }
          }),
          ["site", "page", "lock_version"]
        ),
      annotations: %{readOnlyHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "page" => id, "lock_version" => lock_version} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, page} <- PageFields.fetch_page(scope, id),
         {:ok, attrs} <- PageFields.attrs(scope, arguments) do
      case Content.update_page(scope, %{page | lock_version: lock_version}, attrs) do
        {:ok, page} -> {:ok, PageFields.result(scope, page)}
        {:error, changeset} -> {:error, ContentFields.save_error(changeset, "page")}
      end
    end
  end
end
