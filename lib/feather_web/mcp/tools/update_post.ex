defmodule FeatherWeb.MCP.Tools.UpdatePost do
  @moduledoc """
  The tool `update_post`: saves changes to a post as its unpublished
  changes, on the lock version the agent read.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{ContentFields, PostFields, Tool}

  @impl true
  def definition do
    %{
      name: "update_post",
      title: "Update post",
      description:
        "Changes a post: only the fields given; null clears a field. The changes are saved " <>
          "as unpublished changes: the site shows the post as it was until publish_post. " <>
          "lock_version is the one get_post, create_post or update_post gave last; if the " <>
          "post was changed elsewhere since, such as in the editor, nothing is saved.",
      inputSchema:
        Tool.input_schema(
          Map.merge(PostFields.properties(), %{
            "post" => %{"type" => "string", "description" => "The post's id from list_posts"},
            "lock_version" => %{
              "type" => "integer",
              "description" => "The post's lock_version this change builds on"
            }
          }),
          ["site", "post", "lock_version"]
        ),
      annotations: %{readOnlyHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "post" => id, "lock_version" => lock_version} = arguments) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, post} <- PostFields.fetch_post(scope, id),
         {:ok, attrs} <- PostFields.attrs(scope, arguments) do
      case Content.update_post(scope, %{post | lock_version: lock_version}, attrs) do
        {:ok, post} -> {:ok, PostFields.result(scope, post)}
        {:error, changeset} -> {:error, ContentFields.save_error(changeset, "post")}
      end
    end
  end
end
