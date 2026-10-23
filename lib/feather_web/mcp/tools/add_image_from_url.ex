defmodule FeatherWeb.MCP.Tools.AddImageFromUrl do
  @moduledoc """
  The tool `add_image_from_url`: downloads an image into the site's
  images, like the editor's import by URL.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Media
  alias Feather.StaticSite.ImageVariants
  alias FeatherWeb.MCP.{ImageFields, Tool}

  @impl true
  def definition do
    %{
      name: "add_image_from_url",
      title: "Add image from URL",
      description:
        "Downloads an image from a public http or https URL, at most 25 MB, into the site's " <>
          "images. Its id goes into image blocks, header_image and thumbnail_image. A model " <>
          "writes its alternative text in the background shortly after, where the CMS has " <>
          "one; update_image sets it.",
      inputSchema:
        Tool.input_schema(
          %{
            "url" => %{"type" => "string", "format" => "uri", "description" => "The image's URL"}
          },
          ["site", "url"]
        ),
      annotations: %{
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: true
      }
    }
  end

  @impl true
  def call(scope, %{"site" => domain, "url" => url}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      variants = ImageVariants.for_role(scope.site, :content)

      case Media.create_image_from_url(scope, String.trim(url), %{}, variants: variants) do
        {:ok, image} ->
          {:ok, ImageFields.result(image)}

        {:error, reason} ->
          {:error, "The image was not added: #{ImageFields.download_error(reason)}"}
      end
    end
  end
end
