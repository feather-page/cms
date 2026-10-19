defmodule FeatherWeb.Api.V1.ImageController do
  @moduledoc """
  Images of a site in the content API, see `docs/api/openapi.yml`.

  `create` takes either a multipart `file` upload or a `url` to fetch the
  image from (`Feather.Media.create_image_from_url/4`, which refuses local
  and private addresses).
  """
  use FeatherWeb, :controller

  alias Feather.Media
  alias Feather.Media.Image
  alias Feather.StaticSite.ImageVariants

  action_fallback FeatherWeb.Api.V1.FallbackController

  def show(conn, %{"id" => id}) do
    case Media.get_image(conn.assigns.current_scope, id) do
      %Image{} = image -> render(conn, :show, image: image)
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"file" => %Plug.Upload{} = upload}) do
    scope = conn.assigns.current_scope

    scope
    |> Media.create_image_from_upload(
      upload.path,
      upload.filename || "image",
      %{},
      variants(scope)
    )
    |> created(conn)
  end

  def create(conn, %{"url" => url}) when is_binary(url) and url != "" do
    scope = conn.assigns.current_scope

    scope
    |> Media.create_image_from_url(url, %{}, variants(scope))
    |> created(conn)
  end

  def create(_conn, _params), do: {:error, "Either file or url parameter is required"}

  # API images go into content blocks; other roles get their variants at the next export.
  defp variants(scope), do: [variants: ImageVariants.for_role(scope.site, :content)]

  defp created({:ok, image}, conn) do
    conn
    |> put_status(:created)
    |> render(:show, image: image)
  end

  defp created({:error, _reason} = error, _conn), do: error
end
