defmodule Feather.Ollama do
  @moduledoc """
  Asks the self-hosted Ollama model for suggestions (ADR 0026) over its
  native chat API (`POST /api/chat`), with answers constrained to JSON.

  The URL comes from `config :feather, :ollama_url` (`OLLAMA_URL`); without
  one nothing is asked and every call returns `{:error, :not_configured}`.
  Tests stub the requests with `Req.Test` (`config :feather,
  :ollama_req_options, plug: {Req.Test, Feather.Ollama}`).
  """

  alias Feather.Sites.Languages

  require Logger

  @model "gemma4-26b"
  @timeout 90_000
  @max_alt_length 250
  @max_description_length 300

  @alt_format %{
    "type" => "object",
    "properties" => %{"alt" => %{"type" => "string"}},
    "required" => ["alt"]
  }

  @description_format %{
    "type" => "object",
    "properties" => %{"description" => %{"type" => "string"}},
    "required" => ["description"]
  }

  @doc "Returns true if an Ollama URL is configured."
  @spec configured?() :: boolean()
  def configured?, do: url() not in [nil, ""]

  @doc """
  Suggests the alt text of an image, given as JPEG data, in the language
  with the given code (e.g. `"de"`).
  """
  @spec alt_text(binary(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def alt_text(jpeg, language_code) when is_binary(jpeg) do
    prompt = """
    Write the alt text of this image for a website in #{Languages.name(language_code)}.
    Describe what the image shows for people who cannot see it, in one short
    sentence of at most 125 characters. Do not start with "Image of" or "Photo of".
    Answer with JSON: {"alt": "..."}
    """

    with {:ok, %{"alt" => alt}} when is_binary(alt) <-
           chat_json(prompt, @alt_format, images: [jpeg]),
         alt when alt != "" <- trimmed(alt, @max_alt_length) do
      {:ok, alt}
    else
      {:error, reason} -> {:error, reason}
      _empty -> {:error, :no_answer}
    end
  end

  @doc """
  Suggests the description of a post or page, given its title (nil for a
  short post) and plain text, in the language with the given code: the
  sentence search results and link previews show.
  """
  @spec description(String.t() | nil, String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def description(title, text, language_code) when is_binary(text) do
    prompt = """
    Write the meta description of this web page in #{Languages.name(language_code)}.
    Summarise what the page is about in one or two sentences of at most 155
    characters, for search results and link previews. Do not start with
    "This page" or "This post", and do not repeat the title.
    Answer with JSON: {"description": "..."}

    Title: #{title}

    #{text}
    """

    with {:ok, %{"description" => description}} when is_binary(description) <-
           chat_json(prompt, @description_format),
         description when description != "" <- trimmed(description, @max_description_length) do
      {:ok, description}
    else
      {:error, reason} -> {:error, reason}
      _empty -> {:error, :no_answer}
    end
  end

  @doc """
  Sends one user message and decodes the model's answer, which follows the
  JSON schema `format`. Options: `:images` (binaries sent with the message).
  """
  @spec chat_json(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def chat_json(prompt, format, opts \\ []) do
    if configured?() do
      message = %{
        role: "user",
        content: prompt,
        images: Enum.map(opts[:images] || [], &Base.encode64/1)
      }

      req()
      |> Req.post(
        url: "/api/chat",
        json: %{model: @model, stream: false, format: format, messages: [message]}
      )
      |> decode_answer()
    else
      {:error, :not_configured}
    end
  end

  defp trimmed(text, max_length), do: text |> String.trim() |> String.slice(0, max_length)

  defp decode_answer(
         {:ok, %Req.Response{status: 200, body: %{"message" => %{"content" => content}}}}
       )
       when is_binary(content) do
    case Jason.decode(content) do
      {:ok, %{} = answer} -> {:ok, answer}
      _invalid -> log_failure({:invalid_answer, content})
    end
  end

  defp decode_answer({:ok, %Req.Response{status: status}}), do: log_failure({:status, status})
  defp decode_answer({:error, exception}), do: log_failure(exception)

  defp log_failure(reason) do
    Logger.warning("Ollama gave no answer: #{inspect(reason)}")
    {:error, reason}
  end

  defp req do
    [base_url: url(), receive_timeout: @timeout, retry: false]
    |> Req.new()
    |> Req.merge(Application.get_env(:feather, :ollama_req_options, []))
  end

  defp url, do: Application.get_env(:feather, :ollama_url)
end
