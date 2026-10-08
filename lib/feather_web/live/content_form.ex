defmodule FeatherWeb.ContentForm do
  @moduledoc """
  Form helpers shared by the post, page, project and review forms: the
  Editor.js data, the server-side slug suggestion, the short post rule and
  changes coming from the header image picker.

  ## Slug suggestion

  Like the Rails `slug` Stimulus controller: while the user has not edited
  the slug (and the record had none), every change of the title suggests a
  free slug with `Feather.Content.suggest_slug/2`.

  ## Short posts

  Like the Rails `post_form` controller: a post (or review) whose content is
  shorter than #{300} characters and that has neither title nor slug hides
  the title and slug fields. The editor hook sends the content with every
  change, so the server computes the length
  (`Feather.Content.Blocks.content_length/1`).
  """

  alias Feather.Content
  alias Feather.Content.Blocks

  @short_post_length 300

  @doc "Content shorter than this many characters makes a short post."
  @spec short_post_length() :: pos_integer()
  def short_post_length, do: @short_post_length

  @doc "The content of a record as Editor.js JSON, for the editor hook."
  @spec editor_json(Feather.Accounts.Scope.t(), map()) :: String.t()
  def editor_json(scope, record), do: Jason.encode!(Content.editor_js(scope, record))

  @doc """
  Returns true when the change event was triggered by the slug input of the
  form `as` (e.g. `"post"`).
  """
  @spec slug_target?(map(), String.t()) :: boolean()
  def slug_target?(%{"_target" => [as, "slug"]}, as), do: true
  def slug_target?(_params, _as), do: false

  @doc """
  Puts a suggested slug for the title into the record params when the
  change came from the title input and the slug was never edited.
  """
  @spec maybe_suggest_slug(map(), map(), String.t(), Feather.Accounts.Scope.t(), boolean()) ::
          map()
  def maybe_suggest_slug(record_params, event_params, as, scope, slug_touched?) do
    if not slug_touched? and event_params["_target"] == [as, "title"] do
      Map.put(record_params, "slug", Content.suggest_slug(scope, record_params["title"] || ""))
    else
      record_params
    end
  end

  @doc """
  The content length of the current form: from the Editor.js JSON in the
  params if present, otherwise from the record.
  """
  @spec content_length(map(), map()) :: non_neg_integer()
  def content_length(%{"content" => json}, _record) when is_binary(json) do
    json |> Blocks.from_editor_js() |> Blocks.content_length()
  end

  def content_length(_params, %{content: content}), do: Blocks.content_length(content)

  @doc """
  Whether the title and slug fields are shown: when either has a value or
  the content is not short.
  """
  @spec show_title_and_slug?(Phoenix.HTML.Form.t(), non_neg_integer()) :: boolean()
  def show_title_and_slug?(form, content_length) do
    present?(form[:title].value) or present?(form[:slug].value) or
      content_length >= @short_post_length
  end

  @doc """
  Applies a change from `FeatherWeb.HeaderImagePicker` to the record params.
  """
  @spec put_picker_change(map(), FeatherWeb.HeaderImagePicker.change()) :: map()
  def put_picker_change(params, {:cover, image}),
    do: Map.put(params, "header_image_id", image && image.id)

  def put_picker_change(params, {:thumbnail, image}),
    do: Map.put(params, "thumbnail_image_id", image && image.id)

  def put_picker_change(params, {:emoji, emoji}), do: Map.put(params, "emoji", emoji || "")

  @doc """
  The assigns a picker change updates (`header_image`, `thumbnail_image`).
  """
  @spec picker_assigns(FeatherWeb.HeaderImagePicker.change()) :: keyword()
  def picker_assigns({:cover, image}), do: [header_image: image]
  def picker_assigns({:thumbnail, image}), do: [thumbnail_image: image]
  def picker_assigns({:emoji, _emoji}), do: []

  @doc """
  The page title of an edit page: the record's title, else the start of
  its content (short posts), else `fallback`.
  """
  @spec heading(map(), String.t()) :: String.t()
  def heading(record, fallback) do
    cond do
      present?(record.title) -> record.title
      (excerpt = Content.content_excerpt(record, 80)) != "" -> excerpt
      true -> fallback
    end
  end

  @doc """
  Whether the details card starts open: after a failed save, so errors in
  its fields are visible.
  """
  @spec details_open?(Phoenix.HTML.Form.t()) :: boolean()
  def details_open?(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}) do
    changeset.action in [:insert, :update] and not changeset.valid?
  end

  @doc "A loaded association, or nil when it is not loaded."
  @spec loaded(term()) :: term()
  def loaded(%Ecto.Association.NotLoaded{}), do: nil
  def loaded(value), do: value

  @doc "Returns true for a non-blank value."
  @spec present?(term()) :: boolean()
  def present?(nil), do: false
  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(_value), do: true
end
