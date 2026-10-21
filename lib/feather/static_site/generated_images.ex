defmodule Feather.StaticSite.GeneratedImages do
  @moduledoc """
  The images the export draws for a site (ADR 0028,
  `Feather.Media.Drawing`): the site's emoji as a PNG favicon and, for
  pages without an image to share, a share card with their title and
  emoji in the look of the site's theme (`c:Feather.StaticSite.Theme.share_card_look/1`).

  An image is named after a SHA-256 of what it shows (`<hash>.png`) and
  drawn once into `<storage_root>/generated/`, like image variants; the
  export serves it at `images/<hash>.png`. Old files stay.
  """

  alias Feather.Media
  alias Feather.Media.Drawing
  alias Feather.Sites.Site
  alias Feather.StaticSite.Themes

  @type t :: {:favicon, String.t()} | {:share_card, Drawing.card()}

  # Bump to redraw every image after a change to the drawing.
  @version 1
  @max_title_length 150
  @file_name ~r/\A[0-9a-f]{64}\.png\z/

  @doc "The favicon of a site, or nil for a site without an emoji."
  @spec favicon(Site.t()) :: t() | nil
  def favicon(%Site{emoji: emoji}) do
    case trim(emoji) do
      nil -> nil
      emoji -> {:favicon, emoji}
    end
  end

  @doc """
  The share card of a page of the site with a title and an optional emoji.
  It names the site below the title unless the title is the site's.
  """
  @spec share_card(Site.t(), String.t(), String.t() | nil) :: t()
  def share_card(%Site{} = site, title, emoji) do
    title = title |> to_string() |> String.slice(0, @max_title_length)

    {:share_card,
     %{
       title: title,
       site_title: if(title != site.title, do: trim(site.title)),
       emoji: trim(emoji),
       look: Themes.module(site).share_card_look(site)
     }}
  end

  @doc "The file name of an image."
  @spec file_name(t()) :: String.t()
  def file_name(image) do
    content = :erlang.term_to_binary({@version, without_install_path(image)}, [:deterministic])
    Base.encode16(:crypto.hash(:sha256, content), case: :lower) <> ".png"
  end

  # The font file's directory moves with the release; its name says which font it is.
  defp without_install_path({:share_card, card}),
    do: {:share_card, update_in(card.look.font_file, &Path.basename/1)}

  defp without_install_path(image), do: image

  @doc "Returns true if `name` has the form of a file name of `file_name/1`."
  @spec file_name?(String.t()) :: boolean()
  def file_name?(name) when is_binary(name), do: Regex.match?(@file_name, name)
  def file_name?(_name), do: false

  @doc "The stored file of an image by its file name."
  @spec path(String.t()) :: Path.t()
  def path(name) do
    if file_name?(name),
      do: Path.join([Media.storage_root(), "generated", name]),
      else: raise(ArgumentError, "unknown generated image #{inspect(name)}")
  end

  @doc "Draws an image unless it is stored already."
  @spec ensure(t()) :: :ok | {:error, term()}
  def ensure(image) do
    target = image |> file_name() |> path()

    if File.regular?(target) do
      :ok
    else
      File.mkdir_p!(Path.dirname(target))
      draw(image, target)
    end
  end

  defp draw({:favicon, emoji}, target), do: Drawing.favicon(emoji, target)
  defp draw({:share_card, card}, target), do: Drawing.share_card(card, target)

  defp trim(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trim(_value), do: nil
end
