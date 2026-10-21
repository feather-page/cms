defmodule Feather.Media.AltText do
  @moduledoc """
  Fills in the alt text of new images with a suggestion of
  `Feather.Ollama` (ADR 0026), in the site's language, in the background.

  The model sees a JPEG of at most 1024 pixels. A suggestion never replaces an
  alt text written meanwhile, and without the model the alt text stays
  empty.
  """

  import Ecto.Query, warn: false

  alias Feather.Media
  alias Feather.Media.{Image, Processor}
  alias Feather.{Ollama, Repo}
  alias Feather.Sites.Site

  require Logger

  @model_image_size 1024

  @doc """
  Runs `suggest/2` under `Feather.TaskSupervisor`, or right away with
  `config :feather, :alt_text_suggestions, :inline` (as in tests). Does
  nothing without a configured model.
  """
  @spec start(Site.t(), Image.t()) :: :ok
  def start(%Site{} = site, %Image{} = image) do
    cond do
      not Ollama.configured?() ->
        :ok

      Application.get_env(:feather, :alt_text_suggestions, :background) == :inline ->
        suggest(site, image)

      true ->
        Feather.TaskSupervisor
        |> Task.Supervisor.start_child(fn -> suggest(site, image) end)
        |> log_start_failure(image)
    end
  end

  defp log_start_failure({:ok, _pid}, _image), do: :ok

  defp log_start_failure({:error, reason}, image) do
    Logger.error("No alt text suggested for image #{image.public_id}: #{inspect(reason)}")
  end

  @doc """
  Asks the model for the image's alt text and stores it while the image
  has none.
  """
  @spec suggest(Site.t(), Image.t()) :: :ok
  def suggest(%Site{} = site, %Image{} = image) do
    with path when is_binary(path) <- Media.original_path(image),
         {:ok, jpeg} <- Processor.jpeg(path, @model_image_size),
         {:ok, alt} <- Ollama.alt_text(jpeg, site.language_code) do
      Repo.update_all(
        from(i in Image, where: i.id == ^image.id and i.alt == ""),
        set: [alt: alt, updated_at: DateTime.utc_now()]
      )
    end

    :ok
  end
end
