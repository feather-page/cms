defmodule Feather.MediaTest do
  use Feather.DataCase

  alias Feather.Media
  alias Feather.Media.{Image, Variants}

  setup do
    %{scope: site_scope_fixture()}
  end

  describe "create_image_from_upload/4" do
    test "stores the original and generates every variant", %{scope: scope} do
      path = test_image_path(2400, 1200)

      assert {:ok, %Image{} = image} =
               Media.create_image_from_upload(scope, path, "../evil/photo.png", %{})

      assert image.public_id =~ ~r/\A[0-9a-zA-Z]{12}\z/
      assert image.filename == "photo.png"
      assert image.content_type == "image/png"
      assert image.width == 2400
      assert image.height == 1200
      assert image.byte_size == File.stat!(path).size
      assert image.site_id == scope.site.id

      original = Media.original_path(image)
      assert original == Path.join(Media.image_dir(image), "original.png")
      assert File.exists?(original)

      assert Media.image_dir(image) ==
               Path.join([
                 Application.fetch_env!(:feather, :storage_root),
                 "images",
                 image.public_id
               ])

      for %{name: name, filename: filename, size: size, format: format} <- Variants.all() do
        variant_path = Media.variant_path(image, name)
        assert variant_path == Media.variant_path(image, filename)
        assert Path.basename(variant_path) == filename

        {:ok, variant} = Vix.Vips.Image.new_from_file(variant_path)
        assert Vix.Vips.Image.width(variant) == min(size, 2400), "#{filename} width"

        {:ok, loader} = Vix.Vips.Image.header_value(variant, "vips-loader")
        assert loader == if(format == :jpg, do: "jpegload", else: "webpload")
      end
    end

    test "variants are never upscaled", %{scope: scope} do
      image = image_fixture(scope, width: 300, height: 200)

      {:ok, variant} = Vix.Vips.Image.new_from_file(Media.variant_path(image, :desktop_x2_webp))
      assert {Vix.Vips.Image.width(variant), Vix.Vips.Image.height(variant)} == {300, 200}
    end

    test "variant names match the static export file names" do
      assert Variants.filenames() ==
               ~w(mobile_x1.webp mobile_x2.webp desktop_x1.webp mobile_x3.webp desktop_x2.webp desktop_x1.jpg)

      assert Media.variant_names() == Variants.names()
      assert_raise ArgumentError, fn -> Media.variant_path(%Image{public_id: "x"}, :huge) end
    end

    test "rejects files that are not images", %{scope: scope} do
      path =
        Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer([:positive])}.png")

      File.write!(path, "definitely not a png")

      assert {:error, changeset} = Media.create_image_from_upload(scope, path, "fake.png")
      assert errors_on(changeset) == %{file: ["must be an image"]}
      assert Media.list_images(scope) == []
    end

    test "rejects files over 25 MB", %{scope: scope} do
      path = Path.join(System.tmp_dir!(), "big-#{System.unique_integer([:positive])}.png")
      File.write!(path, :binary.copy(<<0>>, Media.max_byte_size() + 1))

      assert {:error, changeset} = Media.create_image_from_upload(scope, path, "big.png")
      assert errors_on(changeset) == %{file: ["is too big (at most 25 MB)"]}
      File.rm!(path)
    end

    test "stores Unsplash data", %{scope: scope} do
      image =
        image_fixture(scope,
          unsplash_data: %{
            "photographer_name" => "Jane",
            "photographer_url" => "https://unsplash.com/@jane",
            "download_location" => "https://api.unsplash.com/photos/x/download"
          }
        )

      image = Media.get_image!(scope, image.public_id)
      assert Image.unsplash?(image)
      assert Image.unsplash_photographer_name(image) == "Jane"
      assert Image.unsplash_photographer_url(image) == "https://unsplash.com/@jane"
      assert Image.unsplash_download_location(image) =~ "download"
      refute Image.unsplash?(image_fixture(scope))
    end
  end

  describe "generate_variants/1" do
    test "regenerates missing variants from the original", %{scope: scope} do
      image = image_fixture(scope)
      File.rm!(Media.variant_path(image, :mobile_x1_webp))

      assert :ok = Media.generate_variants(image)
      assert File.exists?(Media.variant_path(image, :mobile_x1_webp))
    end
  end

  describe "delete_image/1" do
    test "removes the record and the files", %{scope: scope} do
      image = image_fixture(scope)
      dir = Media.image_dir(image)

      assert {:ok, _} = Media.delete_image(image)
      refute File.exists?(dir)
      assert Media.get_image(scope, image.public_id) == nil
    end
  end

  describe "create_image_from_url/3" do
    test "fetches the image and records the source", %{scope: scope} do
      png = File.read!(test_image_path(40, 30))

      Req.Test.stub(Feather.Media, fn conn ->
        case conn.request_path do
          "/old.png" ->
            conn
            |> Plug.Conn.put_resp_header("location", "https://images.example.com/photo.png")
            |> Plug.Conn.send_resp(301, "")

          "/photo.png" ->
            Plug.Conn.send_resp(conn, 200, png)
        end
      end)

      assert {:ok, image} =
               Media.create_image_from_url(scope, "https://images.example.com/old.png")

      assert image.source_url == "https://images.example.com/old.png"
      assert image.filename == "old.png"
      assert image.width == 40
    end

    test "refuses unsafe URLs, also as redirect targets", %{scope: scope} do
      assert {:error, "Forbidden IP" <> _} =
               Media.create_image_from_url(scope, "http://169.254.169.254/latest")

      Req.Test.stub(Feather.Media, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://localhost/secret.png")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, "Forbidden hostname" <> _} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end

    test "follows at most 3 redirects", %{scope: scope} do
      Req.Test.stub(Feather.Media, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "https://images.example.com/again.png")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, "Too many redirects" <> _} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end

    test "reports HTTP errors", %{scope: scope} do
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 404, "not found"))

      assert {:error, "Failed to fetch image" <> _} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end
  end
end
