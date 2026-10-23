defmodule FeatherWeb.MCP.Tool do
  @moduledoc """
  A tool of the MCP server, listed in `FeatherWeb.MCP.Tools`.

  `definition/0` describes the tool to clients: `name`, `title`,
  `description`, `inputSchema` (built with `input_schema/2`) and
  `annotations` (read tools are `readOnlyHint: true`). The input schema has
  string keys: `FeatherWeb.MCP.Tools` checks the arguments against it with
  `Feather.Content.SchemaValidator` before `call/2`.

  `call/2` gets the scope of the token's user and the arguments, calls the
  contexts and returns the result as a map, or a message the agent can
  read and act on. Tools that work on a site take its domain as `site` and
  load it with `site_scope/2`.
  """

  alias Feather.Accounts.Scope
  alias Feather.Content.BlockValidator
  alias Feather.Sites

  @callback definition() :: map()
  @callback call(Scope.t(), arguments :: map()) :: {:ok, map()} | {:error, String.t()}

  @site %{"type" => "string", "description" => "The site's domain"}

  @doc """
  The input schema of a tool: an object with `properties` and no others,
  of which the call must give the `required` ones. A required `site` adds
  its property, the site's domain; a `content` property adds the block
  schemas it refers to as `$defs`.
  """
  @spec input_schema(map(), [String.t()]) :: map()
  def input_schema(properties, required \\ []) do
    properties = if "site" in required, do: Map.put(properties, "site", @site), else: properties
    schema = %{"type" => "object", "properties" => properties, "additionalProperties" => false}
    schema = if required == [], do: schema, else: Map.put(schema, "required", required)

    if Map.has_key?(properties, "content"),
      do: Map.put(schema, "$defs", BlockValidator.definitions()),
      else: schema
  end

  @doc """
  The scope with the site of `domain` among the user's memberships. Any
  other site, also one a super admin may open in the admin, is answered
  as missing (ADR 0031).
  """
  @spec site_scope(Scope.t(), String.t()) :: {:ok, Scope.t()} | {:error, String.t()}
  def site_scope(%Scope{} = scope, domain) do
    case Sites.get_member_site_by_domain(scope, domain) do
      nil -> {:error, "There is no site #{domain}. list_sites lists the sites you can work on."}
      site -> {:ok, Scope.put_site(scope, site)}
    end
  end
end
