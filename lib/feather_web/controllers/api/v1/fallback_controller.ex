defmodule FeatherWeb.Api.V1.FallbackController do
  @moduledoc """
  Turns the error results of the content API actions into JSON responses:

    * `{:error, :not_found}` - 404 `{"error": "Not found"}`
    * `{:error, :bad_request, message}` - 400 `{"error": message}`
    * `{:error, %Ecto.Changeset{}}` and `{:error, {:validation, details}}` -
      422 `{"error": "Validation failed", "details": {field: [messages]}}`
    * `{:error, {:content, messages}}` -
      422 `{"error": "Content validation failed", "details": {"content": messages}}`
    * `{:error, message}` - 422 `{"error": message}`
  """
  use FeatherWeb, :controller

  def call(conn, {:error, :not_found}), do: error(conn, :not_found, %{error: "Not found"})

  def call(conn, {:error, :bad_request, message}),
    do: error(conn, :bad_request, %{error: message})

  def call(conn, {:error, %Ecto.Changeset{} = changeset}),
    do: call(conn, {:error, {:validation, error_details(changeset)}})

  def call(conn, {:error, {:validation, details}}),
    do: error(conn, :unprocessable_entity, %{error: "Validation failed", details: details})

  def call(conn, {:error, {:content, messages}}) do
    error(conn, :unprocessable_entity, %{
      error: "Content validation failed",
      details: %{content: messages}
    })
  end

  def call(conn, {:error, message}) when is_binary(message),
    do: error(conn, :unprocessable_entity, %{error: message})

  defp error(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  @doc """
  The errors of a changeset as `%{field => [message]}`, messages
  interpolated.
  """
  @spec error_details(Ecto.Changeset.t()) :: %{atom() => [String.t()]}
  def error_details(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
