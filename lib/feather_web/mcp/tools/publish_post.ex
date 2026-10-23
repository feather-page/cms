defmodule FeatherWeb.MCP.Tools.PublishPost do
  @moduledoc """
  The tool `publish_post`: publishes a post in the state the agent read.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{PostFields, Tool}

  @impl true
  def definition do
    %{
      name: "publish_post",
      title: "Publish post",
      description:
        "Publishes a post in the state you read, its unpublished changes included: " <>
          "lock_version is the one get_post, create_post or update_post gave last. If the " <>
          "post was changed elsewhere since, such as in the editor, nothing is published. " <>
          "The live site shows it after the next deploy_site. A post whose publish_at lies " <>
          "in the future is scheduled: the CMS deploys the site again by itself when it is due.",
      inputSchema:
        Tool.input_schema(
          %{
            "post" => %{"type" => "string", "description" => "The post's id from list_posts"},
            "lock_version" => %{
              "type" => "integer",
              "description" => "The post's lock_version as you read it"
            }
          },
          ["site", "post", "lock_version"]
        ),
      annotations: %{readOnlyHint: false, destructiveHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "post" => id, "lock_version" => lock_version}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, post} <- PostFields.fetch_post(scope, id) do
      case Content.publish(scope, %{post | lock_version: lock_version}) do
        {:ok, post} ->
          {:ok, PostFields.result(scope, post)}

        {:error, :slug_taken} ->
          {:error, "Not published: another post or page is published with the slug #{post.slug}."}

        {:error, :stale} ->
          {:error,
           "Not published: the post was changed elsewhere since lock_version " <>
             "#{lock_version}. get_post gives it as it is now."}
      end
    end
  end
end
