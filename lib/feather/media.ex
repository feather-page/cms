defmodule Feather.Media do
  @moduledoc """
  Images of a site and their files.

  Files live in the storage root (`config :feather, :storage_root`):

      <storage_root>/images/<public_id>/original.<ext>
      <storage_root>/images/<public_id>/mobile_x1.webp   (and the other variants)

  Variants are generated synchronously on create, see
  `Feather.Media.Variants` for the list.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Feather.Repo
  alias Feather.Accounts.Scope
  alias Feather.Media.{Cleanup, Fetcher, Image, Processor, Variants}
  alias Feather.Sites.Site

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
      Ecto.Changeset.validate_change(changeset, field, fn ^field, image_id ->
        if Repo.exists?(from i in Image, where: i.id == ^image_id and i.site_id == ^site_id) do
          []
        else
          [{field, "is not an image of this site"}]
        end
      end)
    end)
  end

  ## Creating

  @doc """
  Creates an image from a file on disk (an upload). The file is copied
  into storage and the variants are generated.

  `attrs` may contain `:source_url`, `:unsplash_data`, `:post_id`,
  `:page_id`, `:project_id` and (for imports) `:public_id`.

  Returns `{:error, changeset}` if the file is not an image or too big.
  """
  @spec create_image_from_upload(Scope.t() | Site.t(), Path.t(), String.t(), map()) ::
          {:ok, Image.t()} | {:error, Ecto.Changeset.t()}
  def create_image_from_upload(scope_or_site, path, filename, attrs \\ %{})

  def create_image_from_upload(%Scope{site: %Site{} = site}, path, filename, attrs),
    do: create_image_from_upload(site, path, filename, attrs)

  def create_image_from_upload(%Site{} = site, path, filename, attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
    %File.Stat{size: byte_size} = File.stat!(path)

    attrs =
      Map.merge(attrs, %{"filename" => sanitize_filename(filename), "byte_size" => byte_size})

    cond do
      byte_size > @max_byte_size ->
        file_error(site, attrs, "is too big (at most 25 MB)")

      true ->
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
            |> insert_with_files(path, info.extension)

          {:error, :not_an_image} ->
            file_error(site, attrs, "must be an image")
        end
    end
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

  defp insert_with_files(changeset, source_path, extension) do
    with {:ok, image} <- Ecto.Changeset.apply_action(changeset, :insert) do
      dir = image_dir(image)
      original = Path.join(dir, "original.#{extension}")

      try do
        File.mkdir_p!(dir)
        File.cp!(source_path, original)

        case Processor.write_variants(original, dir) do
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
  URL as `source_url`.

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
  @spec create_image_from_url(Scope.t() | Site.t(), String.t(), map()) ::
          {:ok, Image.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_image_from_url(scope_or_site, url, attrs \\ %{})

  def create_image_from_url(%Scope{site: %Site{} = site}, url, attrs),
    do: create_image_from_url(site, url, attrs)

  def create_image_from_url(%Site{} = site, url, attrs) do
    with {:ok, body} <- fetch(url) do
      tmp = Path.join(System.tmp_dir!(), "feather-fetch-#{Feather.PublicId.generate()}")

      try do
        File.write!(tmp, body)
        filename = url |> URI.parse() |> Map.get(:path) |> Kernel.||("") |> Path.basename()
        attrs = attrs |> Map.new() |> Map.put(:source_url, url)
        create_image_from_upload(site, tmp, filename, attrs)
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
  The path of a variant file, by variant name (`:mobile_x1_webp`) or file
  name (`"mobile_x1.webp"`). Raises for unknown variants.
  """
  @spec variant_path(Image.t(), atom() | String.t()) :: Path.t()
  def variant_path(%Image{} = image, variant) do
    case Variants.fetch(variant) do
      %{filename: filename} -> Path.join(image_dir(image), filename)
      nil -> raise ArgumentError, "unknown image variant #{inspect(variant)}"
    end
  end

  @doc """
  (Re)generates the variants of an image from its original, e.g. after an
  import copied the original into place.
  """
  @spec generate_variants(Image.t()) :: :ok | {:error, term()}
  def generate_variants(%Image{} = image) do
    case original_path(image) do
      nil -> {:error, :original_missing}
      original -> Processor.write_variants(original, image_dir(image))
    end
  end

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
