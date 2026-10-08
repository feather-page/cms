defmodule Feather.DataCase do
  @moduledoc """
  The test case for tests that touch the data layer.

  Every test runs inside a sandboxed transaction that is rolled back at
  the end. SQLite has a single writer, so tests that use the database are
  synchronous: `use Feather.DataCase` raises.
  """

  use ExUnit.CaseTemplate

  using opts do
    if opts[:async] do
      raise ArgumentError,
            "Feather.DataCase does not support async: true; SQLite tests run synchronously"
    end

    quote do
      alias Feather.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Feather.DataCase

      import Feather.AccountsFixtures
      import Feather.SitesFixtures
      import Feather.ContentFixtures
      import Feather.BooksFixtures
      import Feather.MediaFixtures
      import Feather.PublishingFixtures
    end
  end

  setup tags do
    Feather.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags. Raises for async tests.
  """
  def setup_sandbox(tags) do
    if tags[:async] do
      raise ArgumentError, "database tests must not be async: SQLite has a single writer"
    end

    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Feather.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Sites.create_site(scope, %{title: ""})
      assert "can't be blank" in errors_on(changeset).title
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
