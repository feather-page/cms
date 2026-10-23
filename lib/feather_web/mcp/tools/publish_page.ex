defmodule FeatherWeb.MCP.Tools.PublishPage do
  @moduledoc """
  The tool `publish_page`: publishes a page in the state the agent read.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{PageFields, Tool}

  @impl true
  def definition do
    %{
      name: "publish_page",
      title: "Publish page",
      description:
        "Publishes a page in the state you read, its unpublished changes included: " <>
          "lock_version is the one get_page, create_page or update_page gave last. If the " <>
          "page was changed elsewhere since, such as in the editor, nothing is published. " <>
          "The live site shows it after the next deploy_site.",
      inputSchema:
        Tool.input_schema(
          %{
            "page" => %{"type" => "string", "description" => "The page's id from list_pages"},
            "lock_version" => %{
              "type" => "integer",
              "description" => "The page's lock_version as you read it"
            }
          },
          ["site", "page", "lock_version"]
        ),
      annotations: %{readOnlyHint: false, destructiveHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "page" => id, "lock_version" => lock_version}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, page} <- PageFields.fetch_page(scope, id) do
      case Content.publish(scope, %{page | lock_version: lock_version}) do
        {:ok, page} ->
          {:ok, PageFields.result(scope, page)}

        {:error, :slug_taken} ->
          {:error, "Not published: another post or page is published with the slug #{page.slug}."}

        {:error, :stale} ->
          {:error,
           "Not published: the page was changed elsewhere since lock_version " <>
             "#{lock_version}. get_page gives it as it is now."}
      end
    end
  end
end
