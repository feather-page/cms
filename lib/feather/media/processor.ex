defmodule Feather.Media.Processor do
  @moduledoc """
  Image inspection and resizing with libvips (through Vix).

  Note: an image opened by `Vix.Vips.Operation.thumbnail/3` is read
  sequentially from its file and can only be written once, so every
  variant starts from a fresh thumbnail.
  """

  alias Feather.Media.Variants
  alias Vix.Vips.{Image, Operation}

  @loaders %{
    "jpegload" => {"image/jpeg", "jpg"},
    # Ultra HDR: a JPEG with a gain map, as iPhones take them
    "uhdrload" => {"image/jpeg", "jpg"},
    "pngload" => {"image/png", "png"},
    "webpload" => {"image/webp", "webp"},
    "gifload" => {"image/gif", "gif"},
    "heifload" => {"image/heif", "heic"},
    "tiffload" => {"image/tiff", "tiff"}
  }

  @type info :: %{
          content_type: String.t(),
          extension: String.t(),
          width: pos_integer(),
          height: pos_integer()
        }

  @doc """
  Inspects a file. Returns `{:ok, info}` for a supported raster image and
  `{:error, :not_an_image}` otherwise. Width and height are given after
  applying the EXIF orientation.
  """
  @spec inspect_file(Path.t()) :: {:ok, info()} | {:error, :not_an_image}
  def inspect_file(path) do
    with {:ok, image} <- Image.new_from_file(path),
         {:ok, loader} <- Image.header_value(image, "vips-loader"),
         {content_type, extension} <- Map.get(@loaders, loader) do
      {width, height} = oriented_size(image)
      {:ok, %{content_type: content_type, extension: extension, width: width, height: height}}
    else
      _ -> {:error, :not_an_image}
    end
  end

  defp oriented_size(image) do
    width = Image.width(image)
    height = Image.height(image)

    case Image.header_value(image, "orientation") do
      {:ok, orientation} when orientation in 5..8 -> {height, width}
      _ -> {width, height}
    end
  end

  @doc """
  Writes the variants of `source` into `dir`, named as in
  `Feather.Media.Variants`.
  """
  @spec write_variants(Path.t(), Path.t(), [Variants.variant()]) :: :ok | {:error, term()}
  def write_variants(source, dir, variants) do
    File.mkdir_p!(dir)

    Enum.reduce_while(variants, :ok, fn variant, :ok ->
      case write_variant(source, Path.join(dir, variant.filename), variant) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {variant.filename, reason}}}
      end
    end)
  end

  @doc """
  Writes one variant: fit within size×size without upscaling, EXIF
  orientation applied, metadata stripped. The file appears complete or not
  at all, so a concurrent export never copies half of it.
  """
  @spec write_variant(Path.t(), Path.t(), Variants.variant()) :: :ok | {:error, term()}
  def write_variant(source, target, %{size: size, format: format}) do
    partial = "#{target}.#{System.unique_integer([:positive])}.part"

    try do
      with {:ok, thumbnail} <-
             Operation.thumbnail(source, size, height: size, size: :VIPS_SIZE_DOWN),
           :ok <- save(thumbnail, partial, format) do
        File.rename(partial, target)
      end
    after
      File.rm(partial)
    end
  end

  @doc """
  A JPEG of `source` that fits within size×size, without upscaling, EXIF
  orientation applied and metadata stripped.
  """
  @spec jpeg(Path.t(), pos_integer()) :: {:ok, binary()} | {:error, term()}
  def jpeg(source, size) do
    with {:ok, thumbnail} <-
           Operation.thumbnail(source, size, height: size, size: :VIPS_SIZE_DOWN) do
      Image.write_to_buffer(thumbnail, ".jpg", Q: 85, keep: [])
    end
  end

  defp save(image, target, :webp), do: Operation.webpsave(image, target, keep: [], Q: 80)
  defp save(image, target, :jpg), do: Operation.jpegsave(image, target, keep: [], Q: 85)
end
