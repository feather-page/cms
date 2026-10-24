defmodule Feather.MediaFixtures do
  @moduledoc """
  Test helpers for images. Test images are generated with libvips, so no
  binary fixtures are needed.
  """

  alias Vix.Vips.{Image, Operation}

  @doc """
  Writes a generated image to a temporary file and returns its path.
  `format` is the file extension (`"png"`, `"jpg"`, `"webp"`).
  """
  def test_image_path(width \\ 64, height \\ 48, format \\ "png") do
    dir = Path.join(System.tmp_dir!(), "feather-test-images")
    File.mkdir_p!(dir)
    path = Path.join(dir, "test-#{System.unique_integer([:positive])}.#{format}")

    {:ok, image} = Operation.black(width, height, bands: 3)
    {:ok, image} = Operation.linear(image, [1.0], [128.0])
    {:ok, image} = Operation.cast(image, :VIPS_FORMAT_UCHAR)
    :ok = Image.write_to_file(image, path)
    path
  end

  @doc """
  Writes a generated PNG with an alpha channel that runs from fully
  transparent on the left to opaque on the right, and returns its path.
  """
  def transparent_image_path(width \\ 64, height \\ 48) do
    dir = Path.join(System.tmp_dir!(), "feather-test-images")
    File.mkdir_p!(dir)
    path = Path.join(dir, "test-#{System.unique_integer([:positive])}.png")

    {:ok, colour} = Operation.black(width, height, bands: 3)
    {:ok, colour} = Operation.linear(colour, [1.0], [128.0])
    {:ok, xy} = Operation.xyz(width, height)
    {:ok, x} = Operation.extract_band(xy, 0)
    {:ok, alpha} = Operation.linear(x, [255.0 / (width - 1)], [0.0])
    {:ok, image} = Operation.bandjoin([colour, alpha])
    {:ok, image} = Operation.cast(image, :VIPS_FORMAT_UCHAR)
    :ok = Image.write_to_file(image, path)
    path
  end

  @doc """
  Writes an AVIF holding a black image of `first` and a white one of
  `second` (`{width, height}`), in that order, and returns its path. Its
  primary image (`pitm`) is the second.
  """
  def two_image_avif_path(first, second) do
    {ftyp, first} = avif_parts(first, 0.0)
    {_ftyp, second} = avif_parts(second, 255.0)
    second = shift_properties(second, length(first.properties))
    offset = byte_size(ftyp) + byte_size(avif_meta(0, first, second)) + 8
    dir = Path.join(System.tmp_dir!(), "feather-test-images")
    File.mkdir_p!(dir)
    path = Path.join(dir, "test-#{System.unique_integer([:positive])}.avif")
    mdat = box("mdat", first.data <> second.data)
    File.write!(path, ftyp <> avif_meta(offset, first, second) <> mdat)
    path
  end

  defp avif_parts({width, height}, grey) do
    {:ok, image} = Operation.black(width, height, bands: 3)
    {:ok, image} = Operation.linear(image, [1.0], [grey])
    {:ok, image} = Operation.cast(image, :VIPS_FORMAT_UCHAR)

    {:ok, avif} =
      Operation.heifsave_buffer(image, compression: :VIPS_FOREIGN_HEIF_COMPRESSION_AV1, keep: [])

    avif_item(avif)
  end

  defp avif_item(avif) do
    [{"ftyp", ftyp}, {"meta", <<_version_flags::32, meta::binary>>}, {"mdat", data}] = boxes(avif)
    meta = Map.new(boxes(meta))

    [{"ipco", ipco}, {"ipma", <<_::32, 1::32, 1::16, count, associations::binary-size(count)>>}] =
      boxes(meta["iprp"])

    {box("ftyp", ftyp),
     %{
       hdlr: box("hdlr", meta["hdlr"]),
       properties: for({type, body} <- boxes(ipco), do: box(type, body)),
       associations: associations,
       data: data
     }}
  end

  defp shift_properties(item, shift) do
    associations =
      for <<essential::1, index::7 <- item.associations>>,
        into: <<>>,
        do: <<essential::1, index + shift::7>>

    %{item | associations: associations}
  end

  defp avif_meta(offset, first, second) do
    pitm = full_box("pitm", 0, <<2::16>>)

    extents =
      item_extent(1, offset, first) <> item_extent(2, offset + byte_size(first.data), second)

    iloc = full_box("iloc", 0, <<0x44, 0x00, 2::16>> <> extents)
    infe = &full_box("infe", 2, <<&1::16, 0::16, "av01", 0>>)
    iinf = full_box("iinf", 0, <<2::16>> <> infe.(1) <> infe.(2))
    full_box("meta", 0, first.hdlr <> pitm <> iloc <> iinf <> avif_iprp(first, second))
  end

  defp avif_iprp(first, second) do
    ipco = box("ipco", Enum.join(first.properties ++ second.properties))
    associations = item_associations(1, first) <> item_associations(2, second)
    box("iprp", ipco <> full_box("ipma", 0, <<2::32>> <> associations))
  end

  defp item_associations(item, %{associations: associations}),
    do: <<item::16, byte_size(associations), associations::binary>>

  defp item_extent(item, offset, %{data: data}),
    do: <<item::16, 0::16, 1::16, offset::32, byte_size(data)::32>>

  defp box(type, body), do: <<byte_size(body) + 8::32, type::binary, body::binary>>

  defp full_box(type, version, body), do: box(type, <<version, 0::24, body::binary>>)

  defp boxes(<<>>), do: []

  defp boxes(<<size::32, type::binary-size(4), rest::binary>>) do
    body_size = size - 8
    <<body::binary-size(^body_size), rest::binary>> = rest
    [{type, body} | boxes(rest)]
  end

  @doc """
  Writes a generated Ultra HDR JPEG (a JPEG with a gain map, as iPhones take
  them; libvips reads it with `uhdrload`) and returns its path.
  """
  def ultra_hdr_image_path(width \\ 64, height \\ 48) do
    dir = Path.join(System.tmp_dir!(), "feather-test-images")
    File.mkdir_p!(dir)
    path = Path.join(dir, "test-#{System.unique_integer([:positive])}.jpg")

    {:ok, image} = Operation.black(width, height, bands: 3)
    {:ok, image} = Operation.linear(image, [1.0], [0.5])
    {:ok, image} = Operation.colourspace(image, :VIPS_INTERPRETATION_scRGB)
    :ok = Operation.uhdrsave(image, path)
    path
  end

  @doc """
  Creates an image in the scope's site from a generated file. `:width`,
  `:height` and `:variants` (see `Feather.Media.create_image_from_upload/5`)
  are taken from `attrs`.
  """
  def image_fixture(scope, attrs \\ %{}) do
    {width, attrs} = Map.pop(Map.new(attrs), :width, 64)
    {height, attrs} = Map.pop(attrs, :height, 48)
    {variants, attrs} = Map.pop(attrs, :variants, [])
    path = test_image_path(width, height)

    {:ok, image} =
      Feather.Media.create_image_from_upload(scope, path, "photo.png", attrs, variants: variants)

    File.rm(path)
    image
  end

  @doc "An image block referencing the image."
  def image_block(image, caption \\ ""),
    do: %{"type" => "image", "image_id" => image.public_id, "caption" => caption}
end
