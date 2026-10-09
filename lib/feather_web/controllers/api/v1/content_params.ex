defmodule FeatherWeb.Api.V1.ContentParams do
  @moduledoc """
  Turns the `post` / `page` object of a content API request into
  attributes for `Feather.Content`.

    * Only the permitted fields are taken.
    * `content` is validated against the block schemas
      (`Feather.Content.BlockValidator`) and normalized. On create a
      missing or null `content` means no content; on update it leaves the
      content unchanged.
    * `header_image_id` and `thumbnail_image_id` are image public ids in the
      API. They are resolved to images of the scope's site; an unknown id
      is a validation error, null or `""` clears the image.

  `draft/2` reads the resource's `draft` field, which is not an attribute
  but decides whether saving publishes (see "Saving" in `Feather.Content`).
  """

  alias Feather.Accounts.Scope
  alias Feather.Content.BlockValidator
  alias Feather.Media
  alias Feather.Media.Image

  @image_fields ~w(header_image_id thumbnail_image_id)

  @doc """
  Extracts the attributes of the resource `key` (`"post"`, `"page"`) from
  the request params.
  """
  @spec attrs(Scope.t(), map(), String.t(), [String.t()], :create | :update) ::
          {:ok, map()}
          | {:error, :bad_request, String.t()}
          | {:error, {:content, [String.t()]}}
          | {:error, {:validation, map()}}
  def attrs(%Scope{} = scope, params, key, permitted, action) do
    with {:ok, resource} <- fetch_resource(params, key),
         {:ok, attrs} <- put_content(Map.take(resource, permitted), resource, action) do
      resolve_images(scope, attrs)
    end
  end

  @doc """
  The `draft` field of the resource `key`: `false` when it is missing or
  null, so that saving publishes.
  """
  @spec draft(map(), String.t()) :: {:ok, boolean()} | {:error, {:validation, map()}}
  def draft(params, key) do
    with {:ok, resource} <- fetch_resource(params, key) do
      case Ecto.Type.cast(:boolean, Map.get(resource, "draft")) do
        {:ok, draft} -> {:ok, draft == true}
        :error -> {:error, {:validation, %{"draft" => ["is invalid"]}}}
      end
    end
  end

  defp fetch_resource(params, key) do
    case Map.get(params, key) do
      %{} = resource -> {:ok, resource}
      _ -> {:error, :bad_request, "Parameter #{key} is required and must be an object"}
    end
  end

  defp put_content(attrs, resource, action) do
    case {Map.get(resource, "content"), action} do
      {nil, :create} ->
        {:ok, Map.put(attrs, "content", [])}

      {nil, :update} ->
        {:ok, attrs}

      {content, _action} ->
        case BlockValidator.validate(content) do
          {:ok, blocks} -> {:ok, Map.put(attrs, "content", blocks)}
          {:error, messages} -> {:error, {:content, messages}}
        end
    end
  end

  defp resolve_images(scope, attrs) do
    {attrs, errors} =
      attrs
      |> Map.take(@image_fields)
      |> Enum.reduce({attrs, %{}}, fn {field, public_id}, {attrs, errors} ->
        case resolve_image(scope, public_id) do
          {:ok, image_id} -> {Map.put(attrs, field, image_id), errors}
          {:error, message} -> {attrs, Map.put(errors, field, [message])}
        end
      end)

    if errors == %{}, do: {:ok, attrs}, else: {:error, {:validation, errors}}
  end

  defp resolve_image(_scope, blank) when blank in [nil, ""], do: {:ok, nil}

  defp resolve_image(scope, public_id) when is_binary(public_id) do
    case Media.get_image(scope, public_id) do
      %Image{id: id} -> {:ok, id}
      nil -> {:error, "is not an image of this site"}
    end
  end

  defp resolve_image(_scope, _other), do: {:error, "is invalid"}
end
