defmodule FeatherWeb.MCP.Tools.AddImageFromUrlTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Media
  alias FeatherWeb.MCP.Tools.AddImageFromUrl

  @moduletag :capture_log

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "downloads the image into the site's images", %{site_scope: site_scope, scope: scope} do
    file = File.read!(test_image_path())

    Req.Test.stub(Feather.Media, fn conn ->
      assert conn.host == "photos.example"
      assert conn.request_path == "/fog.png"
      Plug.Conn.send_resp(conn, 200, file)
    end)

    assert {:ok, result} =
             AddImageFromUrl.call(scope, %{
               "site" => "notes.example",
               "url" => " https://photos.example/fog.png "
             })

    assert [image] = Media.list_images(site_scope)

    assert result == %{
             id: image.public_id,
             filename: "fog.png",
             alt: "",
             width: 64,
             height: 48,
             source_url: "https://photos.example/fog.png"
           }
  end

  test "the model writes the alt text afterwards", %{site_scope: site_scope, scope: scope} do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    file = File.read!(test_image_path())
    Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, file))

    Req.Test.stub(Feather.Ollama, fn conn ->
      Req.Test.json(conn, %{"message" => %{"content" => ~s({"alt": "A grey square."})}})
    end)

    assert {:ok, %{id: id}} =
             AddImageFromUrl.call(scope, %{
               "site" => "notes.example",
               "url" => "https://photos.example/square.png"
             })

    assert Media.get_image!(site_scope, id).alt == "A grey square."
  end

  test "a URL the CMS does not fetch from is an error naming the problem", %{
    site_scope: site_scope,
    scope: scope
  } do
    assert AddImageFromUrl.call(scope, %{
             "site" => "notes.example",
             "url" => "http://127.0.0.1/secret.png"
           }) == {:error, "The image was not added: Forbidden IP: http://127.0.0.1/secret.png"}

    assert Media.list_images(site_scope) == []
  end

  test "what is not an image is an error", %{site_scope: site_scope, scope: scope} do
    Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, "<html></html>"))

    assert AddImageFromUrl.call(scope, %{
             "site" => "notes.example",
             "url" => "https://photos.example/page"
           }) == {:error, "The image was not added: file must be an image"}

    assert Media.list_images(site_scope) == []
  end

  test "a failed download is an error", %{scope: scope} do
    Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 404, "Not found"))

    assert AddImageFromUrl.call(scope, %{
             "site" => "notes.example",
             "url" => "https://photos.example/gone.png"
           }) == {:error, "The image was not added: Image could not be fetched"}
  end
end
