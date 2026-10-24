defmodule Feather.Media.Variants do
  @moduledoc """
  The resized versions of an image. A variant fits within N×N pixels
  (never upscaled), metadata stripped, and is named after its box and
  format (`640.webp`, `1200.jpg`), so a file name always means the same
  file and the export can cache it for a year.

  Which variants an image gets follows from its roles in the site's theme
  (`Feather.StaticSite.ImageVariants`); every image also gets the admin
  preview, the sharing image (`og:image`) a JPEG and the picture of a
  fediverse account a small one.
  """

  @type format :: :webp | :jpg
  @type variant :: %{filename: String.t(), size: pos_integer(), format: format()}

  @preview_size 480
  @sharing_size 1200
  @account_picture_size 400

  @doc "The webp variant fitting within size×size."
  @spec webp(pos_integer()) :: variant()
  def webp(size), do: new(size, :webp)

  @doc "The JPEG variant fitting within size×size."
  @spec jpg(pos_integer()) :: variant()
  def jpg(size), do: new(size, :jpg)

  defp new(size, format) when is_integer(size) and size > 0,
    do: %{filename: "#{size}.#{format}", size: size, format: format}

  @doc "The variant the admin shows of every image."
  @spec preview() :: variant()
  def preview, do: webp(@preview_size)

  @doc "The variant `og:image` links to."
  @spec sharing() :: variant()
  def sharing, do: jpg(@sharing_size)

  @doc "The variant a site's fediverse account shows as its picture."
  @spec account_picture() :: variant()
  def account_picture, do: jpg(@account_picture_size)

  @doc """
  The variant a file name (`"640.webp"`) names, or nil for anything else.
  Variants given as maps are returned as they are.
  """
  @spec fetch(String.t() | variant()) :: variant() | nil
  def fetch(%{filename: _, size: _, format: _} = variant), do: variant

  def fetch(filename) when is_binary(filename) do
    case Regex.run(~r/\A([1-9][0-9]{1,3})\.(webp|jpg)\z/, filename) do
      [_, size, "webp"] -> webp(String.to_integer(size))
      [_, size, "jpg"] -> jpg(String.to_integer(size))
      nil -> nil
    end
  end

  def fetch(_other), do: nil

  @doc "The content type of a variant."
  @spec content_type(variant()) :: String.t()
  def content_type(%{format: :jpg}), do: "image/jpeg"
  def content_type(%{format: :webp}), do: "image/webp"

  @doc """
  The width of a variant of an image of `width` × `height` pixels: it fits
  within size×size and is never upscaled. With an unknown image size it is
  the variant's size.
  """
  @spec width(variant(), pos_integer() | nil, pos_integer() | nil) :: pos_integer()
  def width(%{size: size}, width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    longest = max(width, height)
    if longest <= size, do: width, else: div(2 * width * size + longest, 2 * longest)
  end

  def width(%{size: size}, _width, _height), do: size

  @doc """
  The webp variants of the given sizes for an image of `width` × `height`
  pixels with their real widths: narrowest first, and of sizes the image is
  too small for only the smallest, since they would be the same file.
  """
  @spec srcset_widths([pos_integer()], pos_integer() | nil, pos_integer() | nil) ::
          [{variant(), pos_integer()}]
  def srcset_widths(sizes, width, height) do
    sizes
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&with_width(webp(&1), width, height))
    |> Enum.uniq_by(&elem(&1, 1))
  end

  defp with_width(variant, width, height), do: {variant, width(variant, width, height)}

  @doc "The webp variants an image of `width` × `height` needs for the given sizes."
  @spec for_image([pos_integer()], pos_integer() | nil, pos_integer() | nil) :: [variant()]
  def for_image(sizes, width, height),
    do: sizes |> srcset_widths(width, height) |> Enum.map(&elem(&1, 0))
end
