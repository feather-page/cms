defmodule Feather.Media.Processor do
  @moduledoc """
  Image inspection and resizing with libvips (through Vix).

  libvips never picks a loader itself, so none of its other loaders (SVG,
  TIFF, VIPS, CSV, ...) ever parses a member's file:

    * only JPEG, PNG, WebP, GIF and HEIF (AVIF included) are accepted, by
      their magic bytes, before libvips sees the file;
    * only the loader of that format opens it, and only one image is
      read: the first frame, or a HEIF file's primary image.

  An image opened with sequential access can only be written once, so
  every variant opens the original afresh.
  """

  alias Feather.Media.Variants
  alias Vix.Vips.{Image, Operation}

  @formats %{
    jpeg: {"image/jpeg", "jpg"},
    png: {"image/png", "png"},
    webp: {"image/webp", "webp"},
    gif: {"image/gif", "gif"},
    heif: {"image/heif", "heic"}
  }

  @heif_brands ~w(heic heix hevc heim heis hevm hevs mif1 msf1 avif)

  @type info :: %{
          content_type: String.t(),
          extension: String.t(),
          width: pos_integer(),
          height: pos_integer()
        }

  @doc """
  Inspects a file. Returns `{:ok, info}` for a JPEG, PNG, WebP, GIF or HEIF
  image and `{:error, :not_an_image}` otherwise. Width and height are given
  after applying the EXIF orientation.
  """
  @spec inspect_file(Path.t()) :: {:ok, info()} | {:error, :not_an_image}
  def inspect_file(path) do
    with {:ok, format} <- format(path),
         {:ok, image} <- open(path, format) do
      {content_type, extension} = Map.fetch!(@formats, format)
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
      result = write_variant(source, Path.join(dir, variant.filename), variant)
      # libvips frees an image only once the BEAM has collected its last reference.
      :erlang.garbage_collect()

      case result do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {variant.filename, reason}}}
      end
    end)
  end

  @doc """
  Writes one variant: fit within size×size without upscaling, EXIF
  orientation applied, metadata stripped. The file appears complete or not
  at all, so a concurrent export never copies half of it. `source` is
  checked as in `inspect_file/1`.
  """
  @spec write_variant(Path.t(), Path.t(), Variants.variant()) :: :ok | {:error, term()}
  def write_variant(source, target, %{size: size, format: format}) do
    partial = "#{target}.#{System.unique_integer([:positive])}.part"

    try do
      with {:ok, thumbnail} <- thumbnail(source, size),
           :ok <- save(thumbnail, partial, format) do
        File.rename(partial, target)
      end
    after
      File.rm(partial)
    end
  end

  @doc """
  A JPEG of `source` that fits within size×size, without upscaling, EXIF
  orientation applied and metadata stripped. `source` is checked as in
  `inspect_file/1`.
  """
  @spec jpeg(Path.t(), pos_integer()) :: {:ok, binary()} | {:error, term()}
  def jpeg(source, size) do
    with {:ok, thumbnail} <- thumbnail(source, size) do
      Image.write_to_buffer(thumbnail, ".jpg", Q: 85, keep: [])
    end
  end

  defp thumbnail(source, size) do
    with {:ok, format} <- format(source),
         {:ok, header} <- open(source, format),
         {:ok, image} <- open(source, format, shrink_on_load(format, header, size)) do
      Operation.thumbnail_image(image, size, height: size, size: :VIPS_SIZE_DOWN)
    end
  end

  defp format(path) do
    case File.open(path, [:read, :binary], &IO.binread(&1, 12)) do
      {:ok, head} when is_binary(head) -> magic(head)
      _ -> {:error, :not_an_image}
    end
  end

  defp magic(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: {:ok, :jpeg}
  defp magic(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>), do: {:ok, :png}
  defp magic(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>), do: {:ok, :webp}
  defp magic(<<"GIF8", version, "a", _rest::binary>>) when version in [?7, ?9], do: {:ok, :gif}

  defp magic(<<_size::binary-size(4), "ftyp", brand::binary-size(4), _rest::binary>>)
       when brand in @heif_brands,
       do: {:ok, :heif}

  defp magic(_head), do: {:error, :not_an_image}

  defp open(path, format, opts \\ []) do
    with {:ok, {image, _flags}} <-
           load_picture(path, format, [access: :VIPS_ACCESS_SEQUENTIAL] ++ opts) do
      {:ok, image}
    end
  end

  defp load_picture(path, :jpeg, opts), do: Operation.jpegload(path, opts)
  defp load_picture(path, :png, opts), do: Operation.pngload(path, opts)
  defp load_picture(path, :webp, opts), do: Operation.webpload(path, [n: 1] ++ opts)
  defp load_picture(path, :gif, opts), do: Operation.gifload(path, [n: 1] ++ opts)
  defp load_picture(path, :heif, opts), do: Operation.heifload(path, opts)

  # As libvips' thumbnail: JPEG block-shrinks to at least twice the size, WebP scales right to it.
  defp shrink_on_load(:jpeg, header, size) do
    shrink = longest_side(header) / size

    cond do
      shrink >= 16 -> [shrink: 8]
      shrink >= 8 -> [shrink: 4]
      shrink >= 4 -> [shrink: 2]
      true -> []
    end
  end

  defp shrink_on_load(:webp, header, size),
    do: [scale: 1 / max(longest_side(header) / size, 1.0)]

  defp shrink_on_load(_format, _header, _size), do: []

  defp longest_side(image), do: max(Image.width(image), Image.height(image))

  defp save(image, target, :webp), do: Operation.webpsave(image, target, keep: [], Q: 80)
  defp save(image, target, :jpg), do: Operation.jpegsave(image, target, keep: [], Q: 85)
end
