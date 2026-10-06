defmodule Feather.Media.Variants do
  @moduledoc """
  The resized versions generated for every image. Their file names are the
  ones the static export uses (`images/<public_id>/<file name>`).

  Each variant fits within N×N pixels (never upscaled), metadata stripped.
  """

  @variants [
    %{name: :mobile_x1_webp, filename: "mobile_x1.webp", size: 430, format: :webp},
    %{name: :mobile_x2_webp, filename: "mobile_x2.webp", size: 860, format: :webp},
    %{name: :desktop_x1_webp, filename: "desktop_x1.webp", size: 1000, format: :webp},
    %{name: :mobile_x3_webp, filename: "mobile_x3.webp", size: 1290, format: :webp},
    %{name: :desktop_x2_webp, filename: "desktop_x2.webp", size: 2000, format: :webp},
    %{name: :desktop_x1_jpg, filename: "desktop_x1.jpg", size: 1000, format: :jpg}
  ]

  @type variant :: %{name: atom(), filename: String.t(), size: pos_integer(), format: atom()}

  @doc "All variants."
  @spec all() :: [variant()]
  def all, do: @variants

  @doc "The variant names, e.g. `:mobile_x1_webp`."
  @spec names() :: [atom()]
  def names, do: Enum.map(@variants, & &1.name)

  @doc "The variant file names, e.g. `\"mobile_x1.webp\"`."
  @spec filenames() :: [String.t()]
  def filenames, do: Enum.map(@variants, & &1.filename)

  @doc """
  Finds a variant by name (`:mobile_x1_webp`) or file name
  (`"mobile_x1.webp"`). Returns nil for unknown variants.
  """
  @spec fetch(atom() | String.t()) :: variant() | nil
  def fetch(name) when is_atom(name), do: Enum.find(@variants, &(&1.name == name))

  def fetch(filename) when is_binary(filename),
    do: Enum.find(@variants, &(&1.filename == filename))

  @doc "The content type of a variant."
  @spec content_type(variant()) :: String.t()
  def content_type(%{format: :jpg}), do: "image/jpeg"
  def content_type(%{format: :webp}), do: "image/webp"

  @doc """
  The webp variants with their widths, for `srcset` attributes.
  """
  @spec srcset_widths() :: [{String.t(), pos_integer()}]
  def srcset_widths do
    for %{format: :webp, filename: filename, size: size} <- @variants, do: {filename, size}
  end
end
