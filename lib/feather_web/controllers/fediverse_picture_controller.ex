defmodule FeatherWeb.FediversePictureController do
  @moduledoc """
  The pictures of the site's Timeline and Mentions, which the CMS fetches
  from their servers, so that these do not see the members' addresses
  (`Feather.Fediverse.Timeline`, `Feather.Fediverse.Mentions`):

    * `GET /sites/:site_id/timeline/:post_id/pictures/:index` - an
      attachment of a Timeline post, by the post's public id
    * `GET /sites/:site_id/following/:followed_id/picture` - the picture of
      an account the site follows, by the follow's public id
    * `GET /sites/:site_id/mentions/:mention_id/picture` - the picture of a
      mention's author, by the mention's public id; Mentions adds the
      mention's version (`?v=`), so that a changed picture never comes
      from the browser's cache

  Only a JPEG, PNG, WebP or GIF passes, cached privately for a day;
  anything else and a failed fetch is a 404.
  """
  use FeatherWeb, :controller

  alias Feather.Fediverse

  @one_day 24 * 60 * 60

  def show(conn, %{"post_id" => post_id, "index" => index}) do
    case Integer.parse(index) do
      {index, ""} when index >= 0 ->
        send_picture(conn, Fediverse.timeline_picture(conn.assigns.current_scope, post_id, index))

      _invalid ->
        send_resp(conn, 404, "Not found")
    end
  end

  def account(conn, %{"followed_id" => followed_id}) do
    picture = Fediverse.followed_account_picture(conn.assigns.current_scope, followed_id)
    send_picture(conn, picture)
  end

  def mention(conn, %{"mention_id" => mention_id}),
    do: send_picture(conn, Fediverse.mention_picture(conn.assigns.current_scope, mention_id))

  defp send_picture(conn, {:ok, picture, content_type}) do
    conn
    |> put_resp_content_type(content_type, nil)
    |> put_resp_header("cache-control", "private, max-age=#{@one_day}")
    |> put_resp_header("content-disposition", "inline")
    |> send_resp(200, picture)
  end

  defp send_picture(conn, {:error, _reason}), do: send_resp(conn, 404, "Not found")
end
