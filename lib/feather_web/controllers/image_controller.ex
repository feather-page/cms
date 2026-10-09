defmodule FeatherWeb.ImageController do
  @moduledoc """
  Image endpoints of the admin:

    * `POST /sites/:site_id/images` - upload of the editor's image block
      (multipart field `image`)
    * `POST /sites/:site_id/images/from-url` - fetch an image from a URL
      (`{"url": ...}`) for the editor's image block
    * `GET /sites/:site_id/images/:id` - the original file (or a variant
      with `?variant=mobile_x1.webp`), cached for a year

  The two POST endpoints answer `201 {"id": public_id, "url": admin_url}`
  (the image block's `image_id` and `src`) or `422 {"error": message}`,
  a message to show the member.
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

  def create(conn, _params), do: refuse(conn, "Choose an image file.")

  def from_url(conn, %{"url" => url}) when is_binary(url) and url != "" do
    conn.assigns.current_scope
    |> Media.create_image_from_url(String.trim(url))
    |> respond(conn)
  end

  def from_url(conn, _params), do: refuse(conn, "Enter the URL of an image.")

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
    conn
    |> put_status(:created)
    |> json(%{
      id: image.public_id,
      url: Blocks.image_url(conn.assigns.current_scope.site, image.public_id)
    })
  end

  defp respond({:error, %Ecto.Changeset{} = changeset}, conn),
    do: refuse(conn, file_error(changeset))

  defp respond({:error, message}, conn) when is_binary(message), do: refuse(conn, message)

  # Media.create_image_from_upload/4 reports problems with the file on
  # `:file`; anything else is not the member's to fix.
  defp file_error(changeset) do
    case Keyword.get_values(changeset.errors, :file) do
      [{message, _opts} | _] -> "The file #{message}."
      [] -> "The image could not be saved."
    end
  end

  defp refuse(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: message})
  end
end
