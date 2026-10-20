defmodule Feather.Redirects.Redirect do
  @moduledoc """
  A redirect of a site from an old path to an internal target, permanent
  (301) or temporary (302). The target is a post, page or project, or a
  path the site generates (`target_path`, such as `/` or `/feed.xml`).

  `target` is the target as a path to type in: what the form sends, and
  on loaded redirects where the redirect leads now (see
  `Feather.Redirects`).
  """
  use Feather.Schema

  alias Feather.Content.{Page, Post, Project, Slug}

  @type t :: %__MODULE__{}

  @targets [post: Post, page: Page, project: Project]

  @path_format ~r{\A/[A-Za-z0-9\-._~!$&'()*+,;=:@/]*\z}

  schema "redirects" do
    field :public_id, :string
    field :old_path, :string
    field :kind, Ecto.Enum, values: [:permanent, :temporary], default: :permanent
    field :target_path, :string
    field :target, :string, virtual: true

    belongs_to :site, Feather.Sites.Site
    belongs_to :post, Post
    belongs_to :page, Page
    belongs_to :project, Project

    timestamps()
  end

  @doc "The HTTP status code of the redirect's kind."
  @spec status(t()) :: 301 | 302
  def status(%__MODULE__{kind: :permanent}), do: 301
  def status(%__MODULE__{kind: :temporary}), do: 302

  @doc "The associations of the records a redirect can lead to."
  @spec target_assocs() :: [:post | :page | :project]
  def target_assocs, do: Keyword.keys(@targets)

  @doc "The fields that reference the records a redirect can lead to."
  @spec target_fields() :: [:post_id | :page_id | :project_id]
  def target_fields, do: Enum.map(@targets, fn {_assoc, schema} -> target_field(schema) end)

  @doc "The field that references a target record of the schema."
  @spec target_field(module()) :: :post_id | :page_id | :project_id
  for {assoc, schema} <- @targets do
    def target_field(unquote(schema)), do: unquote(:"#{assoc}_id")
  end

  @doc "The record the redirect leads to, or nil for a path. Needs the targets preloaded."
  @spec target_record(t()) :: struct() | nil
  def target_record(%__MODULE__{} = redirect),
    do: Enum.find_value(target_assocs(), &Map.fetch!(redirect, &1))

  @doc false
  def changeset(redirect, attrs) do
    redirect
    |> cast(attrs, [:old_path, :kind, :target])
    |> update_change(:old_path, &Slug.normalize/1)
    |> update_change(:target, &normalize_target/1)
    |> validate_required([:old_path, :kind, :target])
    |> validate_format(:old_path, @path_format,
      message: "may only contain the characters of a URL path, without ? or #"
    )
    |> unique_constraint([:site_id, :old_path],
      error_key: :old_path,
      message: "already has a redirect"
    )
    |> check_constraint(:target, name: :redirects_one_target)
  end

  @doc false
  def create_changeset(redirect, attrs) do
    redirect
    |> changeset(attrs)
    |> Feather.PublicId.put()
  end

  defp normalize_target(target) do
    case String.trim(target) do
      "" -> nil
      "/" <> _ = target -> target
      target -> "/" <> target
    end
  end
end
