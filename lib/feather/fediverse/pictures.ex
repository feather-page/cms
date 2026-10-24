defmodule Feather.Fediverse.Pictures do
  @moduledoc """
  Pictures from fediverse servers: those of the authors of approved
  replies, which the site shows beside them (`Feather.Fediverse.Mentions`),
  and those of the Timeline, which the CMS passes on to its members
  (`get/2`), so the servers do not see the members' addresses. The site's
  content security policy allows only its own images, so the picture of a
  reply's author is downloaded when the reply is approved and exported
  with the site.

  `fetch/2` downloads the author's picture through the checked requests
  (`Feather.Fediverse.Client`, at most 2 MB) and keeps a small square webp
  of it (`put/1`):

    * only JPEG, PNG, WebP and GIF are accepted, by their magic bytes,
      before libvips sees the file;
    * only the loader of that format opens it, so none of libvips'
      untrusted loaders runs;
    * a picture whose header names more than 4096 × 4096 pixels is
      refused, and only the first frame is read
      (`Feather.Media.Processor.square_picture/4`).

  The webp is stored as `<storage_root>/fediverse/pictures/<name>.webp`
  under a name the CMS generates, the only file kept of the picture. Once
  no approved reply uses it (`mark_unused/2`), it is deleted after the
  site's next successful deploy (`delete_unused/1`), so that a deploy
  running meanwhile still finds it.
  """

  import Ecto.Query, warn: false

  alias Feather.Fediverse.{Client, RemoteAccount, SigningKey, UnusedPicture}
  alias Feather.{Media, PublicId, Repo}
  alias Feather.Media.Processor
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Sites.Site

  require Logger

  @size 96
  @max_pixels 4096 * 4096
  @file_name ~r/\A[0-9A-Za-z]{12}\.webp\z/

  @doc """
  Downloads the picture of `account` with the site's key and keeps it
  (`put/1`). Returns its file name, or nil when the account has none or it
  could not be fetched or was refused.
  """
  @spec fetch(Site.t(), RemoteAccount.t()) :: String.t() | nil
  def fetch(%Site{}, %RemoteAccount{picture_url: nil}), do: nil

  def fetch(%Site{} = site, %RemoteAccount{picture_url: url}) do
    with {:ok, picture} <- Client.get_picture(url, SigningKey.for_site(site)),
         {:ok, name} <- put(picture) do
      name
    else
      {:error, reason} ->
        Logger.info("The picture #{inspect(url)} was not kept: #{inspect(reason)}")
        nil
    end
  end

  @doc """
  Downloads the picture at `url` with the site's key, as it is, for the CMS
  to pass on to its members: only a JPEG, PNG, WebP or GIF, by its magic
  bytes, with its content type.
  """
  @spec get(Site.t(), String.t()) :: {:ok, binary(), String.t()} | {:error, term()}
  def get(%Site{} = site, url) when is_binary(url) do
    with {:ok, picture} <- Client.get_picture(url, SigningKey.for_site(site)),
         {:ok, format} <- format(picture) do
      {:ok, picture, "image/#{format}"}
    end
  end

  @doc """
  Keeps a JPEG, PNG, WebP or GIF as a square webp of 96 × 96 pixels and
  returns its new file name; anything else is refused unopened
  (`{:error, :unsupported_format}`).
  """
  @spec put(binary()) :: {:ok, String.t()} | {:error, term()}
  def put(picture) when is_binary(picture) do
    with {:ok, format} <- format(picture),
         {:ok, webp} <- Processor.square_picture(picture, format, @size, @max_pixels) do
      name = PublicId.generate() <> ".webp"
      write(path(name), webp)
      {:ok, name}
    end
  end

  defp format(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: {:ok, :jpeg}
  defp format(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>), do: {:ok, :png}
  defp format(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>), do: {:ok, :webp}
  defp format(<<"GIF8", version, "a", _rest::binary>>) when version in [?7, ?9], do: {:ok, :gif}
  defp format(_picture), do: {:error, :unsupported_format}

  # Written whole or not at all, so a concurrent export never copies half of it.
  defp write(path, webp) do
    partial = "#{path}.#{System.unique_integer([:positive])}.part"
    File.mkdir_p!(Path.dirname(path))

    try do
      File.write!(partial, webp)
      File.rename!(partial, path)
    after
      File.rm(partial)
    end
  end

  @doc """
  Marks kept pictures, by their file names, that no approved reply of the
  site uses any more: the site's next successful deploy deletes them
  (`delete_unused/1`). A site without a deployment target deletes them at
  once. nil is skipped.
  """
  @spec mark_unused(Site.t(), [String.t() | nil]) :: :ok
  def mark_unused(%Site{id: site_id}, names) do
    case Enum.reject(names, &is_nil/1) do
      [] ->
        :ok

      names ->
        if Repo.exists?(from t in DeploymentTarget, where: t.site_id == ^site_id),
          do: Enum.each(names, &Repo.insert!(%UnusedPicture{site_id: site_id, name: &1})),
          else: Enum.each(names, &delete/1)
    end
  end

  @doc """
  Deletes the pictures the site no longer uses (`mark_unused/2`), after a
  deploy succeeded. Failures are only logged: the deploy has succeeded,
  and the next one deletes them.
  """
  @spec delete_unused(Site.t()) :: :ok
  def delete_unused(%Site{id: site_id} = site) do
    from(p in UnusedPicture, where: p.site_id == ^site_id)
    |> Repo.all()
    |> Enum.each(fn picture ->
      delete(picture.name)
      Repo.delete!(picture, allow_stale: true)
    end)
  rescue
    exception ->
      Logger.error(
        "Deleting the unused reply pictures of #{site.domain} failed: " <>
          Exception.message(exception)
      )
  end

  @doc "The file names of the pictures the site no longer uses, which wait for a deploy."
  @spec unused(Site.t()) :: [String.t()]
  def unused(%Site{id: site_id}),
    do: Repo.all(from p in UnusedPicture, where: p.site_id == ^site_id, select: p.name)

  @doc "Removes a kept picture by its file name; nil and missing files are fine."
  @spec delete(String.t() | nil) :: :ok
  def delete(nil), do: :ok

  def delete(name) do
    File.rm(path(name))
    :ok
  end

  @doc "Returns true if `name` has the form of a file name of `put/1`."
  @spec file_name?(term()) :: boolean()
  def file_name?(name) when is_binary(name), do: Regex.match?(@file_name, name)
  def file_name?(_name), do: false

  @doc "The stored file of a picture by its file name."
  @spec path(String.t()) :: Path.t()
  def path(name) do
    if file_name?(name),
      do: Path.join([Media.storage_root(), "fediverse", "pictures", name]),
      else: raise(ArgumentError, "unknown picture #{inspect(name)}")
  end
end
