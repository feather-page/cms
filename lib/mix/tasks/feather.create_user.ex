defmodule Mix.Tasks.Feather.CreateUser do
  @shortdoc "Creates a user who can log in by magic link"

  @moduledoc """
  Creates a confirmed user, or updates an existing one.

      $ mix feather.create_user EMAIL [--super-admin]

  There is no public sign-up: users come in through an invitation or this
  task. `--super-admin` grants access to every site; without it an
  existing user loses super admin rights.
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: [super_admin: :boolean]) do
      {opts, [email], []} ->
        super_admin? = Keyword.get(opts, :super_admin, false)

        with {:ok, user} <- Feather.Accounts.get_or_create_user_by_email(email),
             {:ok, user} <- Feather.Accounts.set_super_admin(user, super_admin?) do
          Mix.shell().info(
            "User #{user.email} ready#{if user.super_admin, do: " (super admin)", else: ""}."
          )
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            Mix.raise("Could not create user: #{inspect(changeset.errors)}")
        end

      _ ->
        Mix.raise("Usage: mix feather.create_user EMAIL [--super-admin]")
    end
  end
end
