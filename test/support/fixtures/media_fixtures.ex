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
  Creates an image in the scope's site from a generated file.
  """
  def image_fixture(scope, attrs \\ %{}) do
    {width, attrs} = Map.pop(Map.new(attrs), :width, 64)
    {height, attrs} = Map.pop(attrs, :height, 48)
    path = test_image_path(width, height)

    {:ok, image} = Feather.Media.create_image_from_upload(scope, path, "photo.png", attrs)
    File.rm(path)
    image
  end

  @doc "An image block referencing the image."
  def image_block(image, caption \\ ""),
    do: %{"type" => "image", "image_id" => image.public_id, "caption" => caption}
end
