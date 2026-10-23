defmodule FeatherWeb.MCP.Tools do
  @moduledoc """
  The tools of the MCP server (`FeatherWeb.MCP.Tool`), in the order
  `tools/list` gives them.

  A call checks the arguments against the tool's input schema and answers
  with a tool result: the tool's map as `structuredContent` and as JSON
  text, or its message with `isError: true`, so the agent can correct the
  call.
  """

  alias Feather.Accounts.Scope
  alias Feather.Content.SchemaValidator
  alias FeatherWeb.MCP.Tools.{AddBook, DeploySite, ListBooks, ListSites, SearchBooks, UpdateBook}
  alias FeatherWeb.MCP.Tools.{CreatePost, GetPost, ListPosts, PublishPost, UpdatePost}

  @tools [
    ListSites,
    DeploySite,
    SearchBooks,
    ListBooks,
    AddBook,
    UpdateBook,
    ListPosts,
    GetPost,
    CreatePost,
    UpdatePost,
    PublishPost
  ]

  @doc "The definitions of all tools."
  @spec definitions() :: [map()]
  def definitions, do: Enum.map(@tools, & &1.definition())

  @doc """
  Calls the tool `name` with `arguments`. Returns the tool result, or
  `:unknown` for a name no tool has.
  """
  @spec call(Scope.t(), String.t(), term()) :: {:ok, map()} | :unknown
  def call(%Scope{} = scope, name, arguments) do
    case Enum.find(@tools, &(&1.definition().name == name)) do
      nil -> :unknown
      tool -> {:ok, tool |> run(scope, arguments) |> result()}
    end
  end

  defp run(tool, scope, arguments) do
    case SchemaValidator.validate(arguments, tool.definition().inputSchema) do
      [] -> tool.call(scope, arguments)
      errors -> {:error, "Invalid arguments: " <> Enum.map_join(errors, "; ", &format_error/1)}
    end
  end

  defp format_error(%{pointer: "", message: message}), do: message
  defp format_error(%{pointer: "/" <> path, message: message}), do: "#{path}: #{message}"

  defp result({:ok, data}),
    do: %{content: [text(Jason.encode!(data))], structuredContent: data, isError: false}

  defp result({:error, message}), do: %{content: [text(message)], isError: true}

  defp text(text), do: %{type: "text", text: text}
end
