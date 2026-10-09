defmodule FeatherWeb.Api.V1.PageController do
  @moduledoc """
  Pages of a site in the content API, see `docs/api/openapi.yml`.
  """
  use FeatherWeb, :controller

  alias Feather.Content
  alias Feather.Content.Page
  alias FeatherWeb.Api.V1.{ContentParams, Pagination}

  action_fallback FeatherWeb.Api.V1.FallbackController

  @permitted ~w(title slug emoji page_type header_image_id thumbnail_image_id tags)

  def index(conn, params) do
    page = Content.paginate_pages(conn.assigns.current_scope, Pagination.page(params))
    render(conn, :index, page: page)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, page} <- fetch_page(conn, id) do
      render(conn, :show, page: Content.preload_images(page))
    end
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope

    with {:ok, attrs} <- ContentParams.attrs(scope, params, "page", @permitted, :create),
         {:ok, draft} <- ContentParams.draft(params, "page"),
         {:ok, page} <- Content.create_page(scope, attrs, draft: draft) do
      conn
      |> put_status(:created)
      |> render(:show, page: Content.preload_images(page))
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, page} <- fetch_page(conn, id),
         {:ok, attrs} <- ContentParams.attrs(scope, params, "page", @permitted, :update),
         {:ok, draft} <- ContentParams.draft(params, "page"),
         {:ok, page} <- Content.update_page(scope, page, attrs, draft: draft) do
      render(conn, :show, page: Content.preload_images(page))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, page} <- fetch_page(conn, id),
         {:ok, _page} <- Content.delete_page(conn.assigns.current_scope, page) do
      json(conn, %{message: "Page deleted"})
    end
  end

  defp fetch_page(conn, id) do
    case Content.get_page(conn.assigns.current_scope, id) do
      %Page{} = page -> {:ok, page}
      nil -> {:error, :not_found}
    end
  end
end
