defmodule Feather.Publishing.Rclone.Provider do
  @moduledoc """
  An rclone provider: the rclone config for a deployment target and the
  remote path to sync to. Credentials come from the target's (encrypted)
  `config` map.
  """

  alias Feather.Publishing.DeploymentTarget

  @typedoc "Obscures a password for an rclone config file."
  @type obscure :: (String.t() -> {:ok, String.t()} | {:error, String.t()})

  @doc "The content of the rclone config file."
  @callback config(DeploymentTarget.t(), obscure()) :: {:ok, iodata()} | {:error, String.t()}

  @doc "The rclone remote path, e.g. `\"fastmail:/me.example.com/files/site\"`."
  @callback remote(DeploymentTarget.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, String.t()}

  @doc """
  Fetches required string values from the target's config, or returns an
  error naming the missing keys.
  """
  @spec fetch_config(DeploymentTarget.t(), [String.t()]) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def fetch_config(%DeploymentTarget{config: config}, keys) do
    config = config || %{}
    values = Enum.map(keys, &Map.get(config, &1))

    case for({key, value} <- Enum.zip(keys, values), not valid_value?(value), do: key) do
      [] -> {:ok, values}
      missing -> {:error, "deployment target config is missing #{Enum.join(missing, ", ")}"}
    end
  end

  # Values end up in an ini file, one per line: no line breaks.
  defp valid_value?(value),
    do:
      is_binary(value) and String.trim(value) != "" and not String.contains?(value, ["\n", "\r"])
end
