defmodule FeatherWeb.MCP.Tools.ListImages do
  @moduledoc """
  The tool `list_images`: the site's images, newest first.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Media
  alias FeatherWeb.MCP.{ImageFields, Tool}

  @impl true
  def definition do
    %{
      name: "list_images",
      title: "List images",
      description:
        "Lists the site's images, newest first, with their id for image blocks, header_image, " <>
          "thumbnail_image and update_image and their alternative text (alt).",
      inputSchema: Tool.input_schema(%{}, ["site"]),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      {:ok, %{images: scope |> Media.list_images() |> Enum.map(&ImageFields.result/1)}}
    end
  end
end
