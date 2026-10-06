defmodule Mix.Tasks.Feather.ApiToken do
  @shortdoc "Creates an API token for a user and prints it once"

  @moduledoc """
  Creates a bearer token for the content API.

      $ mix feather.api_token EMAIL [NAME]

  The token is printed once; only its SHA-256 digest is stored.
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {email, name} =
      case args do
        [email] -> {email, nil}
        [email, name] -> {email, name}
        _ -> Mix.raise("Usage: mix feather.api_token EMAIL [NAME]")
      end

    case Feather.Accounts.get_user_by_email(email |> String.trim() |> String.downcase()) do
      nil ->
        Mix.raise("No user with email #{email}")

      user ->
        {:ok, token, _api_token} = Feather.Accounts.create_api_token(user, name)
        Mix.shell().info(token)
    end
  end
end
