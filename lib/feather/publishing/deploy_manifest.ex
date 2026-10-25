defmodule Feather.Publishing.DeployManifest do
  @moduledoc """
  Every file of the last successful deploy of a target, changed or not:
  the path relative to the export, the SHA-256 of its content and its
  modification time in posix seconds (rclone's precision on FTP).

  Every export writes fresh files, and rclone uploads a file whose
  modification time differs from the remote's when the backend has no
  hashes, as on FTP. Before the sync the deploy gives every file whose
  content the manifest knows the manifest's time back (`restore_times/2`),
  so only changed files are uploaded and unchanged ones keep their
  `Last-Modified`; after a successful sync it saves the export's manifest
  (`save/2`). See DECISIONS.md, 0035.

  The manifest is a JSON file at `<storage_root>/deploy_manifests/<target
  id>.json`, outside `<storage_root>/static_site/`, which the boot clears.
  A missing or unreadable manifest counts as empty: the deploy then
  uploads everything.
  """

  alias Feather.Media
  alias Feather.Publishing.DeploymentTarget

  require Logger

  @type entry :: %{sha256: String.t(), mtime: integer()}
  @type t :: %{String.t() => entry()}

  @chunk_size 64 * 1024

  @doc "The path of the target's manifest."
  @spec path(DeploymentTarget.t()) :: Path.t()
  def path(%DeploymentTarget{id: id}),
    do: Path.join([Media.storage_root(), "deploy_manifests", "#{id}.json"])

  @doc """
  The manifest of the target's last successful deploy; empty when there is
  none or it cannot be read (logged).
  """
  @spec load(DeploymentTarget.t()) :: t()
  def load(%DeploymentTarget{} = target) do
    path = path(target)

    case File.read(path) do
      {:ok, json} ->
        decode(json, path)

      {:error, :enoent} ->
        %{}

      {:error, reason} ->
        Logger.warning("Ignoring the deploy manifest #{path}: #{:file.format_error(reason)}")
        %{}
    end
  end

  defp decode(json, path) do
    with {:ok, %{} = files} <- Jason.decode(json),
         {:ok, manifest} <- entries(files) do
      manifest
    else
      _invalid ->
        Logger.warning("Ignoring the corrupt deploy manifest #{path}")
        %{}
    end
  end

  defp entries(files) do
    Enum.reduce_while(files, {:ok, %{}}, fn
      {path, %{"sha256" => sha256, "mtime" => mtime}}, {:ok, manifest}
      when is_binary(sha256) and is_integer(mtime) ->
        {:cont, {:ok, Map.put(manifest, path, %{sha256: sha256, mtime: mtime})}}

      _invalid, _manifest ->
        {:halt, :error}
    end)
  end

  @doc """
  Gives every file below `dir` whose content `manifest` records its
  recorded modification time and returns the manifest of `dir`.
  """
  @spec restore_times(t(), Path.t()) :: t()
  def restore_times(manifest, dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Map.new(&restore_time(&1, Path.relative_to(&1, dir), manifest))
  end

  defp restore_time(file, path, manifest) do
    sha256 = sha256(file)

    case manifest do
      %{^path => %{sha256: ^sha256, mtime: mtime} = entry} ->
        File.touch!(file, mtime)
        {path, entry}

      _changed ->
        {path, %{sha256: sha256, mtime: File.stat!(file, time: :posix).mtime}}
    end
  end

  defp sha256(file) do
    file
    |> File.stream!(@chunk_size)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Replaces the target's manifest atomically. A manifest that cannot be
  saved is logged, not raised: the site is online by then, and the next
  deploy only uploads more than it would have to.
  """
  @spec save(DeploymentTarget.t(), t()) :: :ok
  def save(%DeploymentTarget{} = target, manifest) do
    path = path(target)
    temporary = "#{path}.#{Feather.PublicId.generate()}.tmp"

    with {:ok, json} <- Jason.encode_to_iodata(manifest),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(temporary, json),
         :ok <- File.rename(temporary, path) do
      :ok
    else
      {:error, reason} ->
        File.rm(temporary)
        Logger.warning("Could not save the deploy manifest #{path}: #{describe(reason)}")
        :ok
    end
  end

  defp describe(%Jason.EncodeError{} = error), do: Exception.message(error)
  defp describe(reason), do: :file.format_error(reason)

  @doc "Deletes the target's manifest, if there is one."
  @spec delete(DeploymentTarget.t()) :: :ok
  def delete(%DeploymentTarget{} = target) do
    _result = File.rm(path(target))
    :ok
  end
end
