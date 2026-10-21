defmodule Feather.Media do
  @moduledoc """
  Images of a site and their files.

  Files live in the storage root (`config :feather, :storage_root`):

      <storage_root>/images/<public_id>/original.<ext>
      <storage_root>/images/<public_id>/640.webp   (and the other variants)

  Rendered diagrams live next to them in `<storage_root>/diagrams/` (see
  `Feather.Diagrams`).

  Variants (`Feather.Media.Variants`) are generated synchronously on create:
  the admin preview and those the caller asks for, which follow from the
  image's role (`Feather.StaticSite.ImageVariants`). The alt text is
  suggested afterwards in the background (`Feather.Media.AltText`).
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Media.{AltText, Cleanup, Fetcher, Image, Processor, Variants}
  alias Feather.Repo
  alias Feather.Sites.Site

  require Logger

  @max_byte_size 25 * 1024 * 1024

  @doc "The largest accepted image file in bytes (25 MB)."
  @spec max_byte_size() :: pos_integer()
  def max_byte_size, do: @max_byte_size

  ## Queries

  @doc "Lists the images of the scope's site, newest first."
  @spec list_images(Scope.t()) :: [Image.t()]
  def list_images(%Scope{site: %Site{id: site_id}}) do
    Repo.all(from i in Image, where: i.site_id == ^site_id, order_by: [desc: i.inserted_at])
  end

  @doc "Gets an image of the scope's site by public id. Raises if not found."
  @spec get_image!(Scope.t(), String.t()) :: Image.t()
  def get_image!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from i in Image, where: i.site_id == ^site_id and i.public_id == ^public_id)
  end

  @doc "Gets an image of the scope's site by public id, or nil."
  @spec get_image(Scope.t(), String.t()) :: Image.t() | nil
  def get_image(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one(from i in Image, where: i.site_id == ^site_id and i.public_id == ^public_id)
  end

  @doc "The public ids among `public_ids` that name images of the scope's site."
  @spec site_image_ids(Scope.t(), [String.t()]) :: [String.t()]
  def site_image_ids(%Scope{site: %Site{id: site_id}}, public_ids) do
    Repo.all(
      from i in Image,
        where: i.site_id == ^site_id and i.public_id in ^public_ids,
        select: i.public_id
    )
  end

  @doc """
  Lists the images embedded in a post, page or project, given the owner
  column (`:post_id`, `:page_id`, `:project_id`) and the owner's id.
  """
  @spec list_images_owned_by(:post_id | :page_id | :project_id, Ecto.UUID.t()) :: [Image.t()]
  def list_images_owned_by(owner_field, owner_id)
      when owner_field in [:post_id, :page_id, :project_id] do
    Repo.all(from i in Image, where: field(i, ^owner_field) == ^owner_id)
  end

  @doc """
  Makes the record the owner of the site's images with the given public
  ids. An image has one owner: the other owner columns are cleared.
  """
  @spec assign_images(Ecto.UUID.t(), :post_id | :page_id | :project_id, Ecto.UUID.t(), [
          String.t()
        ]) :: :ok
  def assign_images(_site_id, _owner_field, _owner_id, []), do: :ok

  def assign_images(site_id, owner_field, owner_id, public_ids)
      when owner_field in [:post_id, :page_id, :project_id] do
    owners = Keyword.put([post_id: nil, page_id: nil, project_id: nil], owner_field, owner_id)

    Repo.update_all(
      from(i in Image, where: i.site_id == ^site_id and i.public_id in ^public_ids),
      set: owners
    )

    :ok
  end

  @doc """
  Validates that the image ids in `fields` (e.g. `:header_image_id`) refer
  to images of the record's site (`site_id` field of the changeset).
  """
  @spec validate_site_images(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  def validate_site_images(%Ecto.Changeset{} = changeset, fields) do
    site_id = Ecto.Changeset.get_field(changeset, :site_id)

    Enum.reduce(fields, changeset, fn field, changeset ->
      Ecto.Changeset.validate_change(changeset, field, &site_image_errors(&1, &2, site_id))
    end)
  end

  defp site_image_errors(field, image_id, site_id) do
    if Repo.exists?(from i in Image, where: i.id == ^image_id and i.site_id == ^site_id) do
      []
    else
      [{field, "is not an image of this site"}]
    end
  end

  ## Creating

  @doc """
  Creates an image from a file on disk (an upload). The file is copied
  into storage and the admin preview and the variants given as `:variants`
  are generated.

  `attrs` may contain `:source_url`, `:unsplash_data`, `:post_id`,
  `:page_id` and `:project_id`.

  Returns `{:error, changeset}` if the file is not an image or too big.
  A created image gets its alt text suggested in the background.
  """
  @spec create_image_from_upload(Scope.t() | Site.t(), Path.t(), String.t(), map(), keyword()) ::
          {:ok, Image.t()} | {:error, Ecto.Changeset.t()}
  def create_image_from_upload(scope_or_site, path, filename, attrs \\ %{}, opts \\ [])

  def create_image_from_upload(%Scope{site: %Site{} = site}, path, filename, attrs, opts),
    do: create_image_from_upload(site, path, filename, attrs, opts)

  def create_image_from_upload(%Site{} = site, path, filename, attrs, opts) do
    %File.Stat{size: byte_size} = File.stat!(path)

    attrs =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(%{"filename" => sanitize_filename(filename), "byte_size" => byte_size})

    if byte_size > @max_byte_size do
      file_error(site, attrs, "is too big (at most 25 MB)")
    else
      with {:ok, image} <-
             create_image_from_file(site, path, attrs, Keyword.get(opts, :variants, [])) do
        AltText.start(site, image)
        {:ok, image}
      end
    end
  end

  defp create_image_from_file(site, path, attrs, variants) do
    case Processor.inspect_file(path) do
      {:ok, info} ->
        attrs =
          Map.merge(attrs, %{
            "content_type" => info.content_type,
            "width" => info.width,
            "height" => info.height
          })

        %Image{site_id: site.id}
        |> Image.create_changeset(attrs)
        |> insert_with_files(path, info.extension, fitting(variants, info))

      {:error, :not_an_image} ->
        file_error(site, attrs, "must be an image")
    end
  end

  defp fitting(variants, %{width: width, height: height}) do
    {webp, others} = Enum.split_with(variants, &(&1.format == :webp))
    Variants.for_image(Enum.map(webp, & &1.size), width, height) ++ others
  end

  # Only the file error: running the full changeset here would add
  # follow-up errors such as a missing content type, which mean nothing to
  # the user.
  defp file_error(site, attrs, message) do
    changeset =
      %Image{site_id: site.id}
      |> Ecto.Changeset.cast(attrs, [:filename, :byte_size])
      |> Ecto.Changeset.add_error(:file, message)

    {:error, %{changeset | action: :insert}}
  end

  defp insert_with_files(changeset, source_path, extension, variants) do
    with {:ok, image} <- Ecto.Changeset.apply_action(changeset, :insert) do
      dir = image_dir(image)
      original = Path.join(dir, "original.#{extension}")

      try do
        File.mkdir_p!(dir)
        File.cp!(source_path, original)

        case Processor.write_variants(original, dir, with_preview(variants)) do
          :ok ->
            case Repo.insert(changeset) do
              {:ok, image} ->
                {:ok, image}

              {:error, changeset} ->
                File.rm_rf(dir)
                {:error, changeset}
            end

          {:error, reason} ->
            File.rm_rf(dir)
            Logger.warning("Generating image variants failed: #{inspect(reason)}")
            {:error, Ecto.Changeset.add_error(changeset, :file, "could not be processed")}
        end
      rescue
        exception ->
          File.rm_rf(dir)
          reraise exception, __STACKTRACE__
      end
    end
  end

  @doc """
  Fetches an image from a URL and creates it like an upload, recording the
  URL as `source_url`. Takes the options of `create_image_from_upload/5`.

  `Feather.Media.Fetcher` does the download: only http(s) URLs on ports
  80/443 whose host resolves to public addresses only, connecting to the
  checked address, at most 3 redirects (each checked as well), at most
  25 MB and 30 seconds.

  Errors about the URL as given (scheme, port, `localhost`, a private IP
  literal) name the problem; every failure after that (resolving, a private
  address behind a name, the connection, the upstream status, size, time,
  redirects) is the generic `"Image could not be fetched"`, so the result
  does not tell the caller anything about the network the server sees. The
  details are logged.
  """
  @spec create_image_from_url(Scope.t() | Site.t(), String.t(), map(), keyword()) ::
          {:ok, Image.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_image_from_url(scope_or_site, url, attrs \\ %{}, opts \\ [])

  def create_image_from_url(%Scope{site: %Site{} = site}, url, attrs, opts),
    do: create_image_from_url(site, url, attrs, opts)

  def create_image_from_url(%Site{} = site, url, attrs, opts) do
    with {:ok, body} <- fetch(url) do
      tmp = Path.join(System.tmp_dir!(), "feather-fetch-#{Feather.PublicId.generate()}")

      try do
        File.write!(tmp, body)
        filename = url |> URI.parse() |> Map.get(:path) |> Kernel.||("") |> Path.basename()
        attrs = attrs |> Map.new() |> Map.put(:source_url, url)
        create_image_from_upload(site, tmp, filename, attrs, opts)
      after
        File.rm(tmp)
      end
    end
  end

  defp fetch(url) do
    case Fetcher.fetch(url, @max_byte_size) do
      {:ok, body} ->
        {:ok, body}

      {:error, {:invalid_url, message}} ->
        {:error, message}

      {:error, reason} ->
        Logger.info("Image could not be fetched from #{inspect(url)}: #{inspect(reason)}")
        {:error, "Image could not be fetched"}
    end
  end

  defp sanitize_filename(filename) do
    case filename |> to_string() |> Path.basename() |> String.trim() do
      "" -> "image"
      name -> String.slice(name, 0, 255)
    end
  end

  ## Updating

  @doc """
  Sets the alt text of an image of the scope's site. A changed alt text
  moves the site's `updated_at`, as the export shows it
  (`Feather.Sites.touch_site/1`).
  """
  @spec update_image_alt(Scope.t(), Image.t(), map()) ::
          {:ok, Image.t()} | {:error, Ecto.Changeset.t()}
  def update_image_alt(
        %Scope{site: %Site{id: site_id}} = scope,
        %Image{site_id: site_id} = image,
        attrs
      ) do
    changeset = Image.alt_changeset(image, attrs)

    with {:ok, image} <- Repo.update(changeset) do
      if Ecto.Changeset.changed?(changeset, :alt), do: Feather.Sites.touch_site(scope)
      {:ok, image}
    end
  end

  ## Files

  @doc "The storage root directory."
  @spec storage_root() :: Path.t()
  def storage_root, do: Application.fetch_env!(:feather, :storage_root)

  @doc "The directory holding an image's files."
  @spec image_dir(Image.t()) :: Path.t()
  def image_dir(%Image{public_id: public_id}) when is_binary(public_id) do
    Path.join([storage_root(), "images", public_id])
  end

  @doc """
  The path of the original file, or nil if it is missing.
  """
  @spec original_path(Image.t()) :: Path.t() | nil
  def original_path(%Image{} = image) do
    image |> image_dir() |> Path.join("original.*") |> Path.wildcard() |> List.first()
  end

  @doc """
  The path of a variant file, by variant or file name (`"640.webp"`).
  Raises for anything that names no variant.
  """
  @spec variant_path(Image.t(), Variants.variant() | String.t()) :: Path.t()
  def variant_path(%Image{} = image, variant) do
    case Variants.fetch(variant) do
      %{filename: filename} -> Path.join(image_dir(image), filename)
      nil -> raise ArgumentError, "unknown image variant #{inspect(variant)}"
    end
  end

  @doc """
  The file names of the stored variants of an image, sorted: every file
  but the original and variants still being written.
  """
  @spec variant_filenames(Image.t()) :: [String.t()]
  def variant_filenames(%Image{} = image) do
    case File.ls(image_dir(image)) do
      {:ok, names} -> names |> Enum.reject(&(original?(&1) or partial?(&1))) |> Enum.sort()
      {:error, _reason} -> []
    end
  end

  defp original?(name), do: String.starts_with?(name, "original.")
  defp partial?(name), do: String.ends_with?(name, ".part")

  @doc """
  Generates a variant from the original unless it is stored already.
  """
  @spec ensure_variant(Image.t(), Variants.variant()) :: :ok | {:error, term()}
  def ensure_variant(%Image{} = image, variant) do
    target = variant_path(image, variant)

    cond do
      File.regular?(target) -> :ok
      original = original_path(image) -> Processor.write_variant(original, target, variant)
      true -> {:error, :original_missing}
    end
  end

  @doc """
  Brings the stored variants of an image in line with `variants` (the
  admin preview is always kept): generates the missing ones from the
  original and deletes the others. Variants that are stored and needed are
  left untouched. Returns the added and removed file names.
  """
  @spec sync_variants(Image.t(), [Variants.variant()]) ::
          {:ok, %{added: [String.t()], removed: [String.t()]}} | {:error, term()}
  def sync_variants(%Image{} = image, variants) do
    needed = with_preview(variants)
    stored = variant_filenames(image)
    missing = Enum.reject(needed, &(&1.filename in stored))
    unneeded = stored -- Enum.map(needed, & &1.filename)

    with :ok <- write_missing(image, missing) do
      Enum.each(unneeded, &File.rm(Path.join(image_dir(image), &1)))
      {:ok, %{added: missing |> Enum.map(& &1.filename) |> Enum.sort(), removed: unneeded}}
    end
  end

  defp write_missing(_image, []), do: :ok

  defp write_missing(image, missing) do
    case original_path(image) do
      nil -> {:error, :original_missing}
      original -> Processor.write_variants(original, image_dir(image), missing)
    end
  end

  defp with_preview(variants), do: Enum.uniq_by([Variants.preview() | variants], & &1.filename)

  ## Deleting

  @doc "Deletes an image and its files."
  @spec delete_image(Image.t()) :: {:ok, Image.t()} | {:error, Ecto.Changeset.t()}
  def delete_image(%Image{} = image) do
    with {:ok, image} <- Repo.delete(image, allow_stale: true) do
      delete_image_files(image)
      {:ok, image}
    end
  end

  @doc "Removes the files of an image (but not its record)."
  @spec delete_image_files(Image.t()) :: :ok
  def delete_image_files(%Image{} = image) do
    File.rm_rf!(image_dir(image))
    :ok
  end

  ## Cleanup

  @doc """
  Lists the images `cleanup_orphaned_images/1` would delete at `now`: those
  nothing references and those their post, page or project no longer
  embeds. See `Feather.Media.Cleanup`.
  """
  @spec orphaned_images(DateTime.t()) :: Cleanup.result()
  def orphaned_images(now \\ DateTime.utc_now()), do: Cleanup.orphaned(now)

  @doc """
  Deletes images (rows and files) nothing references any more and images
  their owner no longer embeds, if they are older than two days. Runs
  daily through `Feather.Media.CleanupScheduler`. Returns the deleted
  images.
  """
  @spec cleanup_orphaned_images(DateTime.t()) :: {:ok, Cleanup.result()} | {:error, term()}
  def cleanup_orphaned_images(now \\ DateTime.utc_now()), do: Cleanup.delete_orphaned(now)
end
