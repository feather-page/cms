defmodule FeatherWeb.ImageController do
  @moduledoc """
  Image endpoints of the admin:

    * `POST /sites/:site_id/images` - upload for the Editor.js image tool
      (multipart field `image`)
    * `POST /sites/:site_id/images/from-url` - fetch an image from a URL
      (JSON `{"url": ...}`) for the Editor.js image tool
    * `GET /sites/:site_id/images/:id` - the original file (or a variant
      with `?variant=mobile_x1.webp`), cached for a year

  The upload endpoints answer in the format the Editor.js image tool
  expects, like the Rails jbuilder: `{"success": 1, "id": ..., "file":
  {"url": ...}}` or `{"success": 0}`.
  """
  use FeatherWeb, :controller

  alias Feather.Content.Blocks
  alias Feather.Media
  alias Feather.Media.Variants

  @one_year 365 * 24 * 60 * 60

  def create(conn, %{"image" => %Plug.Upload{} = upload}) do
    conn.assigns.current_scope
    |> Media.create_image_from_upload(upload.path, upload.filename)
    |> respond(conn)
  end

  def create(conn, _params), do: json(conn, %{success: 0})

  def from_url(conn, %{"url" => url}) when is_binary(url) do
    conn.assigns.current_scope
    |> Media.create_image_from_url(url)
    |> respond(conn)
  end

  def from_url(conn, _params), do: json(conn, %{success: 0})

  def show(conn, %{"id" => id} = params) do
    image = Media.get_image!(conn.assigns.current_scope, id)

    {path, content_type} =
      case params["variant"] && Variants.fetch(params["variant"]) do
        nil -> {Media.original_path(image), image.content_type}
        variant -> {Media.variant_path(image, variant.name), Variants.content_type(variant)}
      end

    if path && File.exists?(path) do
      conn
      |> put_resp_content_type(content_type, nil)
      |> put_resp_header("cache-control", "private, max-age=#{@one_year}, immutable")
      |> put_resp_header("content-disposition", "inline")
      |> send_file(200, path)
    else
      send_resp(conn, 404, "Not found")
    end
  end

  defp respond({:ok, image}, conn) do
    json(conn, %{
      success: 1,
      id: image.id,
      file: %{url: Blocks.image_url(conn.assigns.current_scope.site, image.public_id)}
    })
  end

  defp respond({:error, _reason}, conn), do: json(conn, %{success: 0})
end
