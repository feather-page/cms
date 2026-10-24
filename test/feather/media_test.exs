defmodule Feather.MediaTest do
  use Feather.DataCase

  alias Feather.Media
  alias Feather.Media.{Image, Variants}
  alias Vix.Vips.Operation

  setup do
    %{scope: site_scope_fixture()}
  end

  describe "create_image_from_upload/5" do
    test "stores the original and generates the preview and the given variants",
         %{scope: scope} do
      path = test_image_path(2400, 1200)
      variants = [Variants.webp(640), Variants.webp(1600), Variants.jpg(1200)]

      assert {:ok, %Image{} = image} =
               Media.create_image_from_upload(scope, path, "../evil/photo.png", %{},
                 variants: variants
               )

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

      assert Media.variant_filenames(image) == ~w(1200.jpg 1600.webp 480.webp 640.webp)

      for %{filename: filename, size: size, format: format} <- [Variants.preview() | variants] do
        variant_path = Media.variant_path(image, filename)
        assert variant_path == Path.join(Media.image_dir(image), filename)

        {:ok, variant} = Vix.Vips.Image.new_from_file(variant_path)
        assert Vix.Vips.Image.width(variant) == min(size, 2400), "#{filename} width"

        {:ok, loader} = Vix.Vips.Image.header_value(variant, "vips-loader")
        assert loader == if(format == :jpg, do: "jpegload", else: "webpload")
      end
    end

    test "without variants an image gets only the admin preview", %{scope: scope} do
      image = image_fixture(scope)

      assert Media.variant_filenames(image) == [Variants.preview().filename]
    end

    test "webp variants keep the alpha channel, the JPEG is flattened", %{scope: scope} do
      path = transparent_image_path(1200, 400)

      assert {:ok, image} =
               Media.create_image_from_upload(scope, path, "mascot.png", %{},
                 variants: [Variants.sharing()]
               )

      for %{filename: filename, format: format} <- [Variants.preview(), Variants.sharing()] do
        {:ok, variant} = Vix.Vips.Image.new_from_file(Media.variant_path(image, filename))

        if format == :webp do
          assert Vix.Vips.Image.has_alpha?(variant), "#{filename} has no alpha channel"
          {:ok, alpha} = Operation.extract_band(variant, 3)
          assert {:ok, {+0.0, _}} = Operation.min(alpha)
          assert {:ok, {opaque, _}} = Operation.max(alpha)
          assert opaque >= 250
        else
          refute Vix.Vips.Image.has_alpha?(variant)
        end
      end
    end

    test "accepts Ultra HDR JPEGs (iPhone photos with a gain map) as JPEGs", %{scope: scope} do
      path = ultra_hdr_image_path(64, 48)

      assert {:ok, %Image{} = image} =
               Media.create_image_from_upload(scope, path, "IMG_0001.jpeg", %{},
                 variants: [Variants.sharing()]
               )

      assert image.content_type == "image/jpeg"
      assert {image.width, image.height} == {64, 48}
      assert Path.basename(Media.original_path(image)) == "original.jpg"
      assert File.exists?(Media.variant_path(image, Variants.sharing()))
    end

    test "variants are never upscaled", %{scope: scope} do
      image = image_fixture(scope, width: 300, height: 200)

      {:ok, variant} = Vix.Vips.Image.new_from_file(Media.variant_path(image, "480.webp"))
      assert {Vix.Vips.Image.width(variant), Vix.Vips.Image.height(variant)} == {300, 200}
    end

    test "variant widths follow from the stored size", %{scope: scope} do
      sizes = [120, 640, 1600]
      variants = Enum.map(sizes, &Variants.webp/1)
      portrait = image_fixture(scope, width: 900, height: 1500, variants: variants)
      small = image_fixture(scope, width: 300, height: 200, variants: variants)

      assert Media.variant_filenames(small) == ~w(120.webp 480.webp 640.webp)

      for image <- [portrait, small],
          variant <- Variants.for_image(sizes, image.width, image.height) do
        {:ok, file} = Vix.Vips.Image.new_from_file(Media.variant_path(image, variant))

        assert Variants.width(variant, image.width, image.height) == Vix.Vips.Image.width(file),
               "#{image.width}×#{image.height} #{variant.filename}"
      end

      assert Variants.width(Variants.webp(860), nil, nil) == 860
    end

    test "srcset widths are the real widths, narrowest first, one candidate per width" do
      sizes = [1600, 640, 960, 1280]

      assert Variants.srcset_widths(sizes, 3024, 4032) == [
               {Variants.webp(640), 480},
               {Variants.webp(960), 720},
               {Variants.webp(1280), 960},
               {Variants.webp(1600), 1200}
             ]

      assert Variants.srcset_widths(sizes, 1000, 563) == [
               {Variants.webp(640), 640},
               {Variants.webp(960), 960},
               {Variants.webp(1280), 1000}
             ]

      assert Variants.srcset_widths(sizes, 180, 277) == [{Variants.webp(640), 180}]
      assert Variants.for_image(sizes, 180, 277) == [Variants.webp(640)]

      assert Variants.srcset_widths([960, 640], nil, nil) == [
               {Variants.webp(640), 640},
               {Variants.webp(960), 960}
             ]
    end

    test "variant file names name their box and format" do
      assert Variants.fetch("640.webp") == %{filename: "640.webp", size: 640, format: :webp}
      assert Variants.fetch("1200.jpg") == Variants.sharing()
      assert Variants.preview().filename == "480.webp"

      for name <- ~w(mobile_x1.webp 0.webp 640.png 12345.webp ../640.webp 640.webp.br) do
        assert Variants.fetch(name) == nil, name
      end

      assert_raise ArgumentError, fn -> Media.variant_path(%Image{public_id: "x"}, "huge") end
    end

    test "rejects files that are not images", %{scope: scope} do
      path =
        Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer([:positive])}.png")

      File.write!(path, "definitely not a png")

      assert {:error, changeset} = Media.create_image_from_upload(scope, path, "fake.png")
      assert errors_on(changeset) == %{file: ["must be an image"]}
      assert Media.list_images(scope) == []
    end

    test "rejects TIFF images", %{scope: scope} do
      path = test_image_path(64, 48, "tif")

      assert {:error, changeset} = Media.create_image_from_upload(scope, path, "scan.tif")
      assert errors_on(changeset) == %{file: ["must be an image"]}
      assert Media.list_images(scope) == []
    end

    test "rejects images whose header names more than 100 megapixels", %{scope: scope} do
      path = bomb_image_path(20_000, 20_000, "png")

      assert {:error, changeset} = Media.create_image_from_upload(scope, path, "bomb.png")
      assert errors_on(changeset) == %{file: ["has too many pixels (at most 100 megapixels)"]}
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

  describe "sync_variants/2" do
    test "adds missing variants, removes unneeded ones and leaves the rest untouched",
         %{scope: scope} do
      image = image_fixture(scope, width: 800, height: 600, variants: [Variants.webp(640)])
      kept = Media.variant_path(image, "640.webp")
      File.write!(kept, "kept as it is")
      File.write!(Path.join(Media.image_dir(image), "mobile_x1.webp"), "legacy")
      in_flight = Path.join(Media.image_dir(image), "960.webp.123.part")
      File.write!(in_flight, "being written")

      assert {:ok, %{added: ["1200.jpg", "960.webp"], removed: ["mobile_x1.webp"]}} =
               Media.sync_variants(image, [
                 Variants.webp(640),
                 Variants.webp(960),
                 Variants.sharing()
               ])

      assert Media.variant_filenames(image) == ~w(1200.jpg 480.webp 640.webp 960.webp)
      assert File.read!(kept) == "kept as it is"
      assert File.read!(in_flight) == "being written"
      assert File.exists?(Media.original_path(image))

      assert {:ok, %{added: [], removed: ["1200.jpg", "640.webp", "960.webp"]}} =
               Media.sync_variants(image, [])

      assert Media.variant_filenames(image) == [Variants.preview().filename]
    end

    test "fails without the original", %{scope: scope} do
      image = image_fixture(scope)
      File.rm!(Media.original_path(image))

      assert {:error, :original_missing} = Media.sync_variants(image, [Variants.webp(640)])
    end
  end

  describe "ensure_variant/2" do
    test "generates a missing variant from the original", %{scope: scope} do
      image = image_fixture(scope, width: 800, height: 600)
      path = Media.variant_path(image, "640.webp")
      refute File.exists?(path)

      assert Media.ensure_variant(image, Variants.webp(640)) == :ok
      {:ok, file} = Vix.Vips.Image.new_from_file(path)
      assert Vix.Vips.Image.width(file) == 640

      File.write!(path, "existing")
      assert Media.ensure_variant(image, Variants.webp(640)) == :ok
      assert File.read!(path) == "existing"
    end
  end

  describe "update_image_alt/3" do
    test "stores the trimmed alt text and moves the site's updated_at", %{scope: scope} do
      image = image_fixture(scope)
      Repo.update_all(Feather.Sites.Site, set: [updated_at: ~U[2020-01-01 00:00:00.000000Z]])

      assert {:ok, image} = Media.update_image_alt(scope, image, %{"alt" => "  A grey square "})
      assert Repo.reload!(image).alt == "A grey square"

      assert DateTime.after?(
               Repo.reload!(scope.site).updated_at,
               ~U[2020-01-01 00:00:00.000000Z]
             )

      assert {:ok, image} = Media.update_image_alt(scope, image, %{"alt" => ""})
      assert image.alt == ""
    end

    test "leaves the site untouched when the alt text stays", %{scope: scope} do
      image = image_fixture(scope)
      Repo.update_all(Feather.Sites.Site, set: [updated_at: ~U[2020-01-01 00:00:00.000000Z]])

      assert {:ok, _image} = Media.update_image_alt(scope, image, %{"alt" => " "})
      assert Repo.reload!(scope.site).updated_at == ~U[2020-01-01 00:00:00.000000Z]
    end

    test "rejects an alt text over 1000 characters", %{scope: scope} do
      image = image_fixture(scope)

      assert {:error, changeset} =
               Media.update_image_alt(scope, image, %{"alt" => String.duplicate("a", 1001)})

      assert "should be at most 1000 character(s)" in errors_on(changeset).alt
    end

    test "refuses an image of another site", %{scope: scope} do
      other = image_fixture(site_scope_fixture())

      assert_raise FunctionClauseError, fn ->
        Media.update_image_alt(scope, other, %{"alt" => "Mine"})
      end
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
    # Serves a PNG for every request: a URL that is refused must be refused
    # before it is requested.
    defp stub_png_server do
      png = File.read!(test_image_path(4, 3))
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, png))
    end

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

      assert {:error, "Image could not be fetched"} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end

    test "refuses IPv4 literals in non-canonical forms", %{scope: scope} do
      stub_png_server()

      for url <- [
            "http://2130706433/a.png",
            "http://127.1/a.png",
            "http://0177.0.0.1/a.png",
            "http://0x7f.0.0.1/a.png",
            "http://0x7f000001/a.png",
            "http://127.0.0.01/a.png"
          ] do
        assert {:error, "Forbidden IP" <> _} = Media.create_image_from_url(scope, url), url
      end

      assert Media.list_images(scope) == []
    end

    test "refuses host names that resolve to private addresses", %{scope: scope} do
      stub_png_server()

      for url <- [
            "http://127.0.0.1.nip.io/a.png",
            "http://169.254.169.254.nip.io/latest",
            "http://10.0.0.1.nip.io/a.png",
            "http://private-and-public.example/a.png",
            "http://unresolvable.example/a.png"
          ] do
        assert {:error, "Image could not be fetched"} = Media.create_image_from_url(scope, url),
               url
      end

      assert Media.list_images(scope) == []
    end

    test "a redirect to a name that resolves to a private address is refused", %{scope: scope} do
      Req.Test.stub(Feather.Media, fn conn ->
        case conn.host do
          "images.example.com" ->
            conn
            |> Plug.Conn.put_resp_header("location", "http://127.0.0.1.nip.io/secret.png")
            |> Plug.Conn.send_resp(302, "")

          other ->
            flunk("requested #{other}")
        end
      end)

      assert {:error, "Image could not be fetched"} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end

    test "follows at most 3 redirects", %{scope: scope} do
      Req.Test.stub(Feather.Media, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "https://images.example.com/again.png")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, "Image could not be fetched"} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end

    test "reports HTTP errors without the upstream status", %{scope: scope} do
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 404, "not found"))

      assert {:error, "Image could not be fetched"} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end

    test "refuses bodies over 25 MB", %{scope: scope} do
      big = :binary.copy(<<0>>, Media.max_byte_size() + 1)
      Req.Test.stub(Feather.Media, &Plug.Conn.send_resp(&1, 200, big))

      assert {:error, "Image could not be fetched"} =
               Media.create_image_from_url(scope, "https://images.example.com/a.png")
    end
  end
end
