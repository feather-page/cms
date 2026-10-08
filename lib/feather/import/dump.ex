defmodule Feather.Import.Dump do
  @moduledoc """
  Reads a dump written by the Rails app's `feather:dump` task (format 1):

      DIR/manifest.json                 {"format", "dumped_at", "rails_env", "counts"}
      DIR/<table>.json                  one JSON array per table
      DIR/images/<public_id>/<filename> the original file of each image

  Values are as Rails stored them: enums as string labels, JSON columns as
  JSON, timestamps as ISO 8601 UTC with microseconds, dates as `YYYY-MM-DD`.
  """

  @format 1

  @tables ~w(users sites site_users user_invitations social_media_links api_tokens images
             posts pages projects books navigations navigation_items deployment_targets)

  defstruct [:dir, :manifest, tables: %{}]

  @type t :: %__MODULE__{dir: Path.t(), manifest: map(), tables: %{String.t() => [map()]}}

  @doc "The tables a dump contains, parents before children."
  @spec tables() :: [String.t()]
  def tables, do: @tables

  @doc """
  Reads the manifest and every table of the dump in `dir`.
  """
  @spec read(Path.t()) :: {:ok, t()} | {:error, String.t()}
  def read(dir) do
    dir = Path.expand(dir)

    with :ok <- check_dir(dir),
         {:ok, manifest} <- read_json(dir, "manifest.json"),
         :ok <- check_format(manifest),
         {:ok, tables} <- read_tables(dir) do
      {:ok, %__MODULE__{dir: dir, manifest: manifest, tables: tables}}
    end
  end

  defp check_dir(dir) do
    if File.dir?(dir), do: :ok, else: {:error, "#{dir} is not a directory"}
  end

  defp check_format(%{"format" => @format}), do: :ok

  defp check_format(%{"format" => format}),
    do: {:error, "unsupported dump format #{inspect(format)}, expected #{@format}"}

  defp check_format(_manifest), do: {:error, "manifest.json has no format"}

  defp read_tables(dir) do
    Enum.reduce_while(@tables, {:ok, %{}}, fn table, {:ok, acc} ->
      case read_json(dir, "#{table}.json") do
        {:ok, rows} when is_list(rows) -> {:cont, {:ok, Map.put(acc, table, rows)}}
        {:ok, _other} -> {:halt, {:error, "#{table}.json is not a JSON array"}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp read_json(dir, name) do
    path = Path.join(dir, name)

    with {:ok, body} <- File.read(path),
         {:ok, data} <- Jason.decode(body) do
      {:ok, data}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, "#{name} is not valid JSON: #{Exception.message(error)}"}

      {:error, reason} ->
        {:error, "cannot read #{name}: #{:file.format_error(reason)}"}
    end
  end

  @doc "The rows of a table."
  @spec rows(t(), String.t()) :: [map()]
  def rows(%__MODULE__{tables: tables}, table) when table in @tables,
    do: Map.fetch!(tables, table)

  @doc """
  The path of a file inside the dump, given a relative path from a row.
  Returns `{:error, reason}` for a path leaving the dump directory or a
  missing file.
  """
  @spec file_path(t(), String.t()) :: {:ok, Path.t()} | {:error, String.t()}
  def file_path(%__MODULE__{dir: dir}, relative) when is_binary(relative) do
    case Path.safe_relative(relative) do
      {:ok, safe} ->
        path = Path.join(dir, safe)
        if File.regular?(path), do: {:ok, path}, else: {:error, "#{relative} is missing"}

      :error ->
        {:error, "#{relative} is not a path inside the dump"}
    end
  end

  @doc """
  Parses a timestamp from the dump into a UTC `DateTime` with microsecond
  precision. Returns nil for nil and raises for anything unparsable.
  """
  @spec timestamp(String.t() | nil) :: DateTime.t() | nil
  def timestamp(nil), do: nil

  def timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        {microsecond, _precision} = datetime.microsecond
        %{DateTime.shift_zone!(datetime, "Etc/UTC") | microsecond: {microsecond, 6}}

      {:error, reason} ->
        raise ArgumentError, "invalid timestamp #{inspect(value)} in dump: #{reason}"
    end
  end

  @doc """
  Parses a date or a timestamp from the dump into a `Date` (the UTC date of
  a timestamp, which is what Rails displayed). Returns nil for nil.
  """
  @spec date(String.t() | nil) :: Date.t() | nil
  def date(nil), do: nil

  def date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> value |> timestamp() |> DateTime.to_date()
    end
  end
end
