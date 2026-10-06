defmodule Mix.Tasks.Feather.Import do
  @shortdoc "Imports a dump of the Rails app (one-time migration)"

  @moduledoc """
  Imports the data dumped by the Rails app's `bin/rails feather:dump` task.

      $ mix feather.import DIR [--force]

  Refuses to run unless the database holds no users and no sites.
  `--force` first deletes all application data and image files. Prints
  the rows per table and everything that needs a look. See
  `Feather.Import.RailsDump`.

  In a release: `bin/feather eval 'Feather.Release.import_dump("DIR")'`.
  """

  use Mix.Task

  alias Feather.Import.{RailsDump, Report}

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, dir} =
      case OptionParser.parse(args, strict: [force: :boolean]) do
        {opts, [dir], []} -> {opts, dir}
        _ -> Mix.raise("Usage: mix feather.import DIR [--force]")
      end

    case RailsDump.run(dir, force: Keyword.get(opts, :force, false)) do
      {:ok, report} ->
        Mix.shell().info(Report.format(report))
        Mix.shell().info("Import finished.")

      {:error, :not_empty} ->
        Mix.raise("The database already holds users or sites. Use --force to replace them.")

      {:error, message} ->
        Mix.raise("Import failed: #{message}")
    end
  end
end
