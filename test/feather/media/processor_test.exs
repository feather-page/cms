defmodule Feather.Media.ProcessorTest do
  use ExUnit.Case, async: true

  import Feather.MediaFixtures

  alias Feather.Media.{Processor, Variants}
  alias Vix.Vips.{Image, MutableImage, Operation}

  @moduletag :tmp_dir

  describe "inspect_file/1" do
    test "accepts JPEG, PNG, WebP, GIF and HEIF (AVIF) by their magic bytes", %{tmp_dir: dir} do
      for {format, content_type, extension} <- [
            {"jpg", "image/jpeg", "jpg"},
            {"png", "image/png", "png"},
            {"webp", "image/webp", "webp"},
            {"gif", "image/gif", "gif"},
            {"avif", "image/heif", "heic"}
          ] do
        path = test_image_path(64, 48, format)

        assert Processor.inspect_file(path) ==
                 {:ok, %{content_type: content_type, extension: extension, width: 64, height: 48}},
               format

        target = Path.join(dir, "#{format}-32.webp")
        assert Processor.write_variant(path, target, Variants.webp(32)) == :ok, format
        assert dimensions(target) == {32, 24}, format
      end
    end

    test "accepts a HEIF image whose major brand is heic", %{tmp_dir: dir} do
      <<box::binary-size(8), "avif", rest::binary>> = File.read!(test_image_path(64, 48, "avif"))
      path = Path.join(dir, "photo.heic")
      File.write!(path, box <> "heic" <> rest)

      assert {:ok, %{content_type: "image/heif", extension: "heic", width: 64, height: 48}} =
               Processor.inspect_file(path)
    end

    test "reads the primary image of a HEIF file that holds several", %{tmp_dir: dir} do
      path = two_image_avif_path({64, 48}, {48, 32})
      assert {:ok, %{width: 48, height: 32}} = Processor.inspect_file(path)

      target = Path.join(dir, "480.webp")
      assert Processor.write_variant(path, target, Variants.preview()) == :ok
      {:ok, variant} = Image.new_from_file(target)
      assert dimensions(variant) == {48, 32}
      assert {:ok, average} = Operation.avg(variant)
      assert average > 250
    end

    test "refuses a file whose magic bytes are followed by garbage", %{tmp_dir: dir} do
      garbage = String.duplicate("garbage ", 64)

      for magic <- [
            <<0xFF, 0xD8, 0xFF>>,
            <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>,
            <<"RIFF", 0, 2, 0, 0, "WEBP">>,
            "GIF89a",
            <<0, 0, 0, 24, "ftypheic">>
          ] do
        path = Path.join(dir, "garbage-#{System.unique_integer([:positive])}")
        File.write!(path, magic <> garbage)

        assert Processor.inspect_file(path) == {:error, :not_an_image}, inspect(magic)
      end
    end
  end

  describe "files that are not JPEG, PNG, WebP, GIF or HEIF" do
    setup %{tmp_dir: dir} do
      text = Path.join(dir, "notes.txt")
      File.write!(text, "definitely not an image")

      svg = Path.join(dir, "drawing.svg")

      File.write!(
        svg,
        ~s(<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"><rect width="64" height="48"/></svg>)
      )

      {:ok, image} = Image.new_from_file(test_image_path(64, 48))
      {:ok, band} = Operation.extract_band(image, 0)
      vips = Path.join(dir, "native.v")
      :ok = Operation.vipssave(image, vips)
      csv = Path.join(dir, "table.csv")
      :ok = Operation.csvsave(band, csv)
      matrix = Path.join(dir, "kernel.mat")
      :ok = Operation.matrixsave(band, matrix)

      %{text: text, loadable: [svg, vips, csv, matrix]}
    end

    test "get no info, no variants and no JPEG, also those libvips itself would load", %{
      tmp_dir: dir,
      text: text,
      loadable: loadable
    } do
      for path <- loadable, do: assert({:ok, _image} = Image.new_from_file(path), path)
      target = Path.join(dir, "480.webp")

      for path <- [text | loadable] do
        assert Processor.inspect_file(path) == {:error, :not_an_image}, path

        assert Processor.write_variant(path, target, Variants.preview()) ==
                 {:error, :not_an_image},
               path

        assert Processor.jpeg(path, 480) == {:error, :not_an_image}, path
      end

      refute Enum.any?(File.ls!(dir), &String.starts_with?(&1, "480."))
    end
  end

  describe "write_variant/3 and jpeg/2" do
    test "large JPEGs and WebPs get the size Variants.width/3 gives", %{tmp_dir: dir} do
      for format <- ~w(jpg webp), {width, height} <- [{4001, 2999}, {2001, 3203}] do
        source = test_image_path(width, height, format)

        for size <- [120, 320, 480, 1600] do
          variant = Variants.webp(size)
          target = Path.join(dir, "#{format}-#{width}-#{variant.filename}")

          assert Processor.write_variant(source, target, variant) == :ok

          assert dimensions(target) == fitted(variant, width, height),
                 "#{format} #{width}×#{height} #{variant.filename}"
        end

        {:ok, jpeg} = Processor.jpeg(source, 480)
        {:ok, image} = Image.new_from_buffer(jpeg)
        assert dimensions(image) == fitted(Variants.jpg(480), width, height)
      end
    end

    test "apply the EXIF orientation and strip it", %{tmp_dir: dir} do
      source = rotated_jpeg_path(dir, 4000, 3000)
      assert {:ok, %{width: 3000, height: 4000}} = Processor.inspect_file(source)

      target = Path.join(dir, "480.webp")
      assert Processor.write_variant(source, target, Variants.preview()) == :ok
      {:ok, jpeg} = Processor.jpeg(source, 480)
      {:ok, from_buffer} = Image.new_from_buffer(jpeg)
      {:ok, from_file} = Image.new_from_file(target)

      for variant <- [from_file, from_buffer] do
        assert dimensions(variant) == {360, 480}
        assert {:error, _} = Image.header_value(variant, "orientation")
        assert {:ok, [top | _]} = Operation.getpoint(variant, 180, 60)
        assert {:ok, [bottom | _]} = Operation.getpoint(variant, 180, 420)
        assert top > 200 and bottom < 50, "top #{top}, bottom #{bottom}"
      end
    end
  end

  defp dimensions(%Image{} = image), do: {Image.width(image), Image.height(image)}

  defp dimensions(path) do
    {:ok, image} = Image.new_from_file(path)
    dimensions(image)
  end

  defp fitted(variant, width, height),
    do: {Variants.width(variant, width, height), Variants.width(variant, height, width)}

  # Stored landscape, left half white: orientation 6 turns it upright, white half on top.
  defp rotated_jpeg_path(dir, width, height) do
    {:ok, xy} = Operation.xyz(width, height)
    {:ok, x} = Operation.extract_band(xy, 0)
    {:ok, left} = Operation.relational_const(x, :VIPS_OPERATION_RELATIONAL_LESS, [width / 2])
    {:ok, image} = Operation.bandjoin([left, left, left])
    {:ok, image} = Image.mutate(image, &MutableImage.set(&1, "orientation", :gint, 6))
    path = Path.join(dir, "rotated.jpg")
    :ok = Operation.jpegsave(image, path)
    path
  end
end
