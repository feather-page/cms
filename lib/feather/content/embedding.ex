defmodule Feather.Content.Embedding do
  @moduledoc """
  What the embedding model of `Feather.Ollama` reads in a published post
  (ADR 0036), which its related posts are found by
  (`Feather.Content.RelatedPosts`).

  The model reads the clustering prompt with the title (a short post's
  meta title, `none` without either) and the description, then the first
  4000 characters of the plain text.

  Publishing a post reads its new version in the background (`start/1`);
  `backfill/1` reads the published versions read by no or another model.
  The vector, which Ollama returns L2-normalised, is stored as
  little-endian 32-bit floats on the version, with the model's name, so that only vectors of the configured
  model are compared (`store/3`). Without the model, and for a version
  without plain text, the version stays unread.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.{Blocks, Post, PostVersion}
  alias Feather.{Ollama, Publishing, Repo, Sites}
  alias Feather.Sites.Site
  alias Feather.Validations

  require Logger

  @text_length 4000

  @doc """
  Reads the published version of a post under `Feather.TaskSupervisor`,
  or right away with `config :feather, :post_embeddings, :inline`; `false`
  reads nothing (tests that do not ask for it). Does nothing without
  `OLLAMA_URL` or when the version is read by the configured model.
  """
  @spec start(Post.t()) :: :ok
  def start(%Post{published_version: %PostVersion{} = version}) do
    if Ollama.configured?() and not read?(version),
      do: start_in(Application.get_env(:feather, :post_embeddings, :background), version),
      else: :ok
  end

  def start(%Post{}), do: :ok

  defp start_in(:background, version) do
    Feather.TaskSupervisor
    |> Task.Supervisor.start_child(fn -> embed(version) end)
    |> log_start_failure(version)
  end

  defp start_in(:inline, version) do
    embed(version)
    :ok
  end

  defp start_in(false, _version), do: :ok

  defp log_start_failure({:ok, _pid}, _version), do: :ok

  defp log_start_failure({:error, reason}, version) do
    Logger.error("Post version #{version.id} not read: #{inspect(reason)}")
  end

  defp read?(%PostVersion{embedding: embedding, embedding_model: model}),
    do: is_binary(embedding) and model == Ollama.embedding_model()

  defp embed(%PostVersion{} = version) do
    with {:ok, input} <- input(version),
         {:ok, vector} <- Ollama.embedding(input) do
      store(version, vector, Ollama.embedding_model())
    else
      {:error, _reason} -> :error
    end
  end

  @doc """
  Stores the vector, as Ollama returns it L2-normalised, as the version's
  embedding by `model`. When the version is the published version
  of a post the live site already shows, the site counts as changed since
  its last deploy, as the related posts the export shows may change.
  """
  @spec store(PostVersion.t(), [number()], String.t()) :: :ok
  def store(%PostVersion{id: id} = version, vector, model) do
    Repo.update_all(from(v in PostVersion, where: v.id == ^id),
      set: [embedding: encode(vector), embedding_model: model]
    )

    touch_site_if_live(version)
  end

  defp touch_site_if_live(%PostVersion{id: id} = version) do
    case Repo.one(from p in Post, where: p.published_version_id == ^id, select: p.site_id) do
      nil -> :ok
      site_id -> touch_site_if_live(Scope.for_site(%Site{id: site_id}), version)
    end
  end

  defp touch_site_if_live(scope, version) do
    target = Publishing.get_target(scope)

    if target && Publishing.live?(target, version),
      do: Sites.touch_site(scope),
      else: :ok
  end

  defp input(%PostVersion{} = version) do
    case Blocks.model_text(version.content, @text_length) do
      "" ->
        {:error, :no_text}

      text ->
        {:ok, "task: clustering | query: #{title(version)}. #{version.description}\n\n#{text}"}
    end
  end

  defp title(version) do
    cond do
      not Validations.blank?(version.title) -> version.title
      not Validations.blank?(version.meta_title) -> version.meta_title
      true -> "none"
    end
  end

  @doc """
  Reads the published versions of the scope's posts that no vector of the
  configured model was stored for, one after the other. Publishes nothing
  again. Returns how many the model read.
  """
  @spec backfill(Scope.t()) :: non_neg_integer()
  def backfill(%Scope{site: %Site{id: site_id}}) do
    model = Ollama.embedding_model()

    from(v in PostVersion,
      join: p in Post,
      on: p.published_version_id == v.id,
      where: p.site_id == ^site_id,
      where: is_nil(v.embedding_model) or v.embedding_model != ^model,
      order_by: p.inserted_at
    )
    |> Repo.all()
    |> Enum.count(&(embed(&1) == :ok))
  end

  @doc "A vector as stored: little-endian 32-bit floats."
  @spec encode([number()]) :: binary()
  def encode(vector), do: for(x <- vector, into: <<>>, do: <<x::float-32-little>>)

  @doc "A stored vector as a list of floats."
  @spec decode(binary()) :: [float()]
  def decode(binary), do: for(<<x::float-32-little <- binary>>, do: x)
end
