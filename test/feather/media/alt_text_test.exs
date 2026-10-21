defmodule Feather.Media.AltTextTest do
  use Feather.DataCase

  alias Feather.Media
  alias Feather.Media.AltText
  alias Feather.StaticSite.{Export, RecordingSink, Routes}
  alias Vix.Vips.Image, as: VipsImage

  @moduletag :capture_log

  setup do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    %{scope: site_scope_fixture(%{language_code: "de"})}
  end

  defp stub_alt(alt) do
    Req.Test.stub(Feather.Ollama, fn conn ->
      Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(%{"alt" => alt})}})
    end)
  end

  defp export(scope) do
    sink = RecordingSink.new(start_supervised!({RecordingSink, []}, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink
  end

  test "an uploaded image gets the model's alt text, which the export shows", %{scope: scope} do
    stub_alt("  Ein Leuchtturm im Nebel  ")

    image = image_fixture(scope, width: 2000, height: 1000)
    assert Repo.reload!(image).alt == "Ein Leuchtturm im Nebel"

    post_fixture(scope, %{
      title: "Coast",
      slug: "/coast",
      header_image_id: image.id,
      content: [image_block(image, "Caption")]
    })

    html = RecordingSink.get(export(scope), "coast/index.html")
    doc = Floki.parse_document!(html)

    assert Floki.attribute(doc, "img.header-image", "alt") == ["Ein Leuchtturm im Nebel"]
    assert Floki.attribute(doc, "figure img", "alt") == ["Ein Leuchtturm im Nebel"]
  end

  test "asks the model for JSON in the site's language with a downscaled JPEG",
       %{scope: scope} do
    Req.Test.stub(Feather.Ollama, fn conn ->
      assert conn.method == "POST"
      assert conn.host == "ollama.test"
      assert conn.request_path == "/api/chat"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      request = Jason.decode!(body)

      assert request["model"] == "gemma4-26b"
      assert request["stream"] == false
      assert request["format"]["required"] == ["alt"]
      assert [%{"role" => "user", "content" => prompt, "images" => [jpeg]}] = request["messages"]
      assert prompt =~ "German"

      {:ok, sent} = jpeg |> Base.decode64!() |> VipsImage.new_from_buffer()
      assert VipsImage.width(sent) == 1024
      assert {:ok, "jpegload_buffer"} = VipsImage.header_value(sent, "vips-loader")

      Req.Test.json(conn, %{"message" => %{"content" => ~s({"alt": "Grau"})}})
    end)

    image = image_fixture(scope, width: 2048, height: 1024)

    assert Repo.reload!(image).alt == "Grau"
  end

  test "an image imported from a URL gets an alt text too", %{scope: scope} do
    stub_alt("Ein graues Bild")
    body = File.read!(test_image_path())
    Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, body))

    {:ok, image} = Media.create_image_from_url(scope, "https://example.com/grey.png")

    assert Repo.reload!(image).alt == "Ein graues Bild"
  end

  test "with the model unreachable the upload succeeds without an alt text", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))

    image = image_fixture(scope)

    assert Repo.reload!(image).alt == ""
  end

  test "an answer that is not the asked JSON leaves the alt text empty", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, fn conn ->
      Req.Test.json(conn, %{"message" => %{"content" => "A grey square"}})
    end)

    assert Repo.reload!(image_fixture(scope)).alt == ""

    Req.Test.stub(Feather.Ollama, &Plug.Conn.send_resp(&1, 500, "model not found"))

    assert Repo.reload!(image_fixture(scope)).alt == ""
  end

  test "without OLLAMA_URL the model is not asked", %{scope: scope} do
    Application.delete_env(:feather, :ollama_url)
    Req.Test.stub(Feather.Ollama, fn _conn -> flunk("the model was asked") end)

    assert Repo.reload!(image_fixture(scope)).alt == ""
  end

  test "a suggestion does not replace an alt text written meanwhile", %{scope: scope} do
    Application.delete_env(:feather, :ollama_url)
    image = image_fixture(scope)
    {:ok, _image} = Media.update_image_alt(scope, image, %{"alt" => "Mine"})

    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    stub_alt("Suggested")
    AltText.suggest(scope.site, image)

    assert Repo.reload!(image).alt == "Mine"
  end
end
