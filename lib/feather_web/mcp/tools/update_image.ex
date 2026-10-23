defmodule FeatherWeb.MCP.Tools.UpdateImage do
  @moduledoc """
  The tool `update_image`: sets an image's alternative text.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Media
  alias FeatherWeb.MCP.{ImageFields, Tool}

  @impl true
  def definition do
    %{
      name: "update_image",
      title: "Update image",
      description:
        "Sets the alternative text of one of the site's images, which screen readers read " <>
          "out wherever the site shows the image. The live site shows it after the next " <>
          "deploy_site.",
      inputSchema:
        Tool.input_schema(
          %{
            "image" => %{"type" => "string", "description" => "The image's id from list_images"},
            "alt" => %{
              "type" => "string",
              "maxLength" => 1000,
              "description" => "What the image shows, in the site's language"
            }
          },
          ["site", "image", "alt"]
        ),
      annotations: %{readOnlyHint: false, idempotentHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "image" => id, "alt" => alt}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain),
         {:ok, image} <- ImageFields.fetch_image(scope, id) do
      case Media.update_image_alt(scope, image, %{"alt" => alt}) do
        {:ok, image} -> {:ok, ImageFields.result(image)}
        {:error, changeset} -> {:error, "Invalid image: " <> Tool.errors(changeset)}
      end
    end
  end
end
