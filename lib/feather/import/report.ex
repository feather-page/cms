defmodule Feather.Import.Report do
  @moduledoc """
  What an import did: rows per table (in the dump and imported) and every
  finding worth a human look, grouped by kind:

    * `:missing_file` - an image without a usable original file (not imported)
    * `:dangling_reference` - a reference to a record that is not in the
      dump or was not imported (dropped or reported, never fatal)
    * `:validation_bypassed` - a record that violates a current validation
      and was imported anyway
    * `:skipped` - a record that could not be imported
    * `:content_changed` - blocks that `Feather.Content.Blocks.normalize/1`
      changed or dropped
    * `:notice` - everything else (adjusted data, legacy formats)
  """

  @kinds [
    :missing_file,
    :dangling_reference,
    :validation_bypassed,
    :skipped,
    :content_changed,
    :notice
  ]

  defstruct counts: %{}, findings: []

  @type kind ::
          :missing_file
          | :dangling_reference
          | :validation_bypassed
          | :skipped
          | :content_changed
          | :notice

  @type t :: %__MODULE__{
          counts: %{String.t() => %{dumped: non_neg_integer(), imported: non_neg_integer()}},
          findings: [{kind(), String.t()}]
        }

  @doc "The finding kinds, in report order."
  @spec kinds() :: [kind()]
  def kinds, do: @kinds

  @doc "Records the number of rows of a table in the dump."
  @spec dumped(t(), String.t(), non_neg_integer()) :: t()
  def dumped(%__MODULE__{} = report, table, count) do
    update_in(report.counts, fn counts ->
      Map.update(counts, table, %{dumped: count, imported: 0}, &%{&1 | dumped: count})
    end)
  end

  @doc "Counts imported rows of a table (one by default)."
  @spec imported(t(), String.t(), non_neg_integer()) :: t()
  def imported(%__MODULE__{} = report, table, count \\ 1) do
    update_in(report.counts, fn counts ->
      Map.update(counts, table, %{dumped: 0, imported: count}, fn c ->
        %{c | imported: c.imported + count}
      end)
    end)
  end

  @doc "Adds a finding."
  @spec add(t(), kind(), String.t()) :: t()
  def add(%__MODULE__{} = report, kind, message) when kind in @kinds do
    %{report | findings: [{kind, message} | report.findings]}
  end

  @doc "The findings of one kind, in the order they were added."
  @spec findings(t(), kind()) :: [String.t()]
  def findings(%__MODULE__{findings: findings}, kind) do
    for {^kind, message} <- Enum.reverse(findings), do: message
  end

  @doc "The number of imported rows of a table."
  @spec imported_count(t(), String.t()) :: non_neg_integer()
  def imported_count(%__MODULE__{counts: counts}, table) do
    get_in(counts, [table, :imported]) || 0
  end

  @doc "Formats the report as text lines for the console."
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = report) do
    counts =
      report.counts
      |> Enum.sort_by(fn {table, _} -> table end)
      |> Enum.map(fn {table, %{dumped: dumped, imported: imported}} ->
        marker = if dumped == imported, do: "", else: "  <- differs"

        "  #{String.pad_trailing(table, 20)} #{pad(dumped)} dumped #{pad(imported)} imported#{marker}"
      end)

    findings =
      Enum.flat_map(@kinds, fn kind ->
        case findings(report, kind) do
          [] ->
            []

          messages ->
            ["", "#{title(kind)} (#{length(messages)}):" | Enum.map(messages, &"  - #{&1}")]
        end
      end)

    Enum.join(["Rows:" | counts] ++ findings, "\n")
  end

  defp pad(count), do: count |> Integer.to_string() |> String.pad_leading(5)

  defp title(:missing_file), do: "Images without a usable file (not imported)"
  defp title(:dangling_reference), do: "Dangling references"
  defp title(:validation_bypassed), do: "Imported despite failing validation"
  defp title(:skipped), do: "Skipped records"
  defp title(:content_changed), do: "Content changed by normalization"
  defp title(:notice), do: "Notices"
end
