defmodule FeatherWeb.Api.V1.PostController do
  @moduledoc """
  Posts of a site in the content API, see `docs/api/openapi.yml`.
  """
  use FeatherWeb, :controller

  alias Feather.Content
  alias Feather.Content.Post
  alias FeatherWeb.Api.V1.{ContentParams, Pagination}

  action_fallback FeatherWeb.Api.V1.FallbackController

  @permitted ~w(title slug draft emoji publish_at header_image_id thumbnail_image_id tags)

  def index(conn, params) do
    page = Content.paginate_posts(conn.assigns.current_scope, Pagination.page(params))
    render(conn, :index, page: page)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, post} <- fetch_post(conn, id) do
      render(conn, :show, post: Content.preload_images(post))
    end
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope

    with {:ok, attrs} <- ContentParams.attrs(scope, params, "post", @permitted, :create),
         {:ok, post} <- Content.create_post(scope, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, post: Content.preload_images(post))
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, post} <- fetch_post(conn, id),
         {:ok, attrs} <- ContentParams.attrs(scope, params, "post", @permitted, :update),
         {:ok, post} <- Content.update_post(scope, post, attrs) do
      render(conn, :show, post: Content.preload_images(post))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, post} <- fetch_post(conn, id),
         {:ok, _post} <- Content.delete_post(conn.assigns.current_scope, post) do
      json(conn, %{message: "Post deleted"})
    end
  end

  defp fetch_post(conn, id) do
    case Content.get_post(conn.assigns.current_scope, id) do
      %Post{} = post -> {:ok, post}
      nil -> {:error, :not_found}
    end
  end
end
