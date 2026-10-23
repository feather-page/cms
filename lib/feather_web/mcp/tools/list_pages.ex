defmodule FeatherWeb.MCP.Tools.ListPages do
  @moduledoc """
  The tool `list_pages`: the site's pages, the homepage first, then by
  title.
  """

  @behaviour FeatherWeb.MCP.Tool

  alias Feather.Content
  alias FeatherWeb.MCP.{PageFields, Tool}

  @impl true
  def definition do
    %{
      name: "list_pages",
      title: "List pages",
      description:
        "Lists the site's pages, the homepage (slug /) first, then by title, with their id " <>
          "for get_page, update_page and publish_page and whether the main navigation " <>
          "links them.",
      inputSchema: Tool.input_schema(%{}, ["site"]),
      annotations: %{readOnlyHint: true}
    }
  end

  @impl true
  def call(scope, %{"site" => domain}) do
    with {:ok, scope} <- Tool.site_scope(scope, domain) do
      {:ok, %{pages: scope |> Content.list_pages() |> Enum.map(&PageFields.summary/1)}}
    end
  end
end
