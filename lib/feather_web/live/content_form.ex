defmodule FeatherWeb.ContentForm do
  @moduledoc """
  Form helpers shared by the post, page, project and review forms: the
  autosave of their fields and editor, publishing, the editor's document,
  the server-side slug suggestion, the short post rule, changes coming
  from the header image picker, the record's publication status and
  versions, discarding changes and restoring a version.

  ## Autosave

  Every change is saved at once; there is no Save button. A form
  implements this module's callbacks, mounts with `mount_record/2` and
  hands the shared events to `handle_event/3` and the header image
  picker's messages to `handle_info/2`.

  Form fields: the form's `phx-change` (`autosave`) saves the valid
  fields (`c:save_fields/3`, built on `Feather.Content.autosave/4`) and
  shows the errors of the others, which stay unsaved until they are
  valid. A new record is created with the
  first input that leaves it valid, then the view is patched to the
  record's edit path and goes on as the edit view. After a reconnect
  LiveView sends the values of the form as it was before as `recover`
  (`phx-auto-recover`), with the counter the earlier view rendered into
  the form (`FeatherWeb.ContentFormComponents.lock_version_field/1`):
  they are saved unless the record changed meanwhile and they would
  change it, which shows the conflict instead.

  Editor: the hook (`assets/js/hooks/prose_mirror.js`) pushes debounced
  `sync` events: `%{"lock_version" => n | nil, "order" => [block ids] |
  nil, "blocks" => [changed top-level ProseMirror nodes]}`, everything
  after a failed push or a reconnect. They are saved with
  `Feather.Content.sync_content/4` (a new record is created from the form
  params and the synced blocks); the reply is `%{status: "saved",
  lock_version: n}`, `%{status: "stale"}` when the record changed
  elsewhere (the hook then stops and offers to reload) or `%{status:
  "invalid"}`.

  Both build on the `lock_version` of the record in the socket, which
  every save of the socket advances. The editor names the counter it
  knows (the one it loaded with, then those of the replies and of the
  `lock_version` events the view pushes after each field save); one
  this view handed out since it mounted builds on the current one (see
  `Feather.Content.sync_content/4`), so field saves and editor syncs of
  one tab never conflict with each other, while a change made elsewhere
  (another tab, the API) is still detected. After a reconnect the view
  mounts again and its counters start anew: the editor's resend names
  the counter of the earlier view, which is the current one unless the
  record changed elsewhere meanwhile, and is rejected then.

  `autosave_status/2` tells the hook how the form fields stand
  (`"saved"`, `"invalid"`, `"conflict"`); the hook shows one status for
  the fields and the editor together.

  ## Slug suggestion

  Like the Rails `slug` Stimulus controller: while the user has not edited
  the slug (and the record had none), every change of the title suggests a
  free slug with `Feather.Content.suggest_slug/3`.

  ## Short posts

  A post (or review) without a title is a short post
  (`Feather.Content.ShortPost`): its details show the meta title, and while
  its content is shorter than #{300} characters the title field is hidden.
  The length is the saved content's (`content_length/1`), so it follows
  the editor's syncs. The slug field is always shown.
  """

  alias Feather.Content
  alias Feather.Content.{Blocks, Page, Post, Project}
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  require Phoenix.LiveView

  @short_post_length 300
  @changed_elsewhere "was changed elsewhere, reload the page to see the changes"

  @typedoc "A post, page or project."
  @type content_record :: map()

  @doc "The record the form edits."
  @callback record(Socket.t()) :: content_record()

  @doc """
  Saves the valid fields of `attrs` into the record (see
  `Feather.Content.autosave/4`, which takes the `opts`). Returns the saved
  record and the socket with what else the save changed assigned.
  """
  @callback save_fields(Socket.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, content_record(), Socket.t()} | {:error, :stale | term()}

  @doc "Assigns the record (and what the form derives from it)."
  @callback assign_record(Socket.t(), content_record()) :: Socket.t()

  @doc "Builds the form from the params on the assigned record."
  @callback assign_form(Socket.t(), params :: map(), action :: atom() | nil) :: Socket.t()

  @doc "The path of the record's edit view."
  @callback edit_path(Socket.t(), content_record()) :: String.t()

  @doc ~s(What the form edits, for flash messages, e.g. "Post".)
  @callback noun() :: String.t()

  @doc "While a short post's content is shorter than this many characters, its title field is hidden."
  @spec short_post_length() :: pos_integer()
  def short_post_length, do: @short_post_length

  @doc """
  Mounts the form on `record` (a new one has no id): assigns the record,
  its publication status (`publication_status`), its `versions`,
  `header_image`, `thumbnail_image`, the editor's document
  (`editor_json`), what autosaving needs and the form.
  """
  @spec mount_record(Socket.t(), content_record()) :: Socket.t()
  def mount_record(socket, record) do
    scope = socket.assigns.current_scope

    socket
    |> Phoenix.Component.assign(:site, scope.site)
    |> put_record(record, versions: true)
    |> init_autosave(record)
    |> Phoenix.Component.assign(
      header_image: loaded(record.header_image),
      thumbnail_image: loaded(record.thumbnail_image),
      editor_json: editor_json(scope, record)
    )
    |> socket.view.assign_form(%{}, nil)
  end

  # Not reloaded per save: only publish changes it, discard and restore mount again.
  defp put_record(socket, record, opts \\ []) do
    record =
      case socket.assigns[:published_version] do
        %{id: id} = version when id == record.published_version_id ->
          %{record | published_version: version}

        _other ->
          record
      end

    record = if record.id, do: Content.preload_published_version(record), else: record

    socket
    |> socket.view.assign_record(record)
    |> Phoenix.Component.assign(
      published_version: record.id && record.published_version,
      publication_status: Content.publication_status(record)
    )
    |> then(fn socket ->
      if opts[:versions],
        do: Phoenix.Component.assign(socket, :versions, versions(socket, record)),
        else: socket
    end)
  end

  defp versions(_socket, %{id: nil}), do: []
  defp versions(socket, record), do: Content.list_versions(socket.assigns.current_scope, record)

  @doc """
  Handles the events the forms share: `autosave` (the form's
  `phx-change`), `recover` (its `phx-auto-recover`), `sync` (the editor), `publish`, `discard`, `restore`
  (with the version's `number`), `unpublish` and `suggest_description`.
  Publishing and suggesting a description run asynchronously, since the
  model may take up to 90 seconds; the forms hand their results to
  `handle_async/3`. A publish finishes even when the form is left.
  """
  @spec handle_event(String.t(), map(), Socket.t()) ::
          {:noreply, Socket.t()} | {:reply, map(), Socket.t()}
  def handle_event("autosave", params, socket),
    do: {:noreply, change(socket, socket.assigns.form.name, params, [])}

  def handle_event("recover", params, socket) do
    lock_version =
      case Integer.parse(params["lock_version"] || "") do
        {lock_version, ""} -> lock_version
        _none -> nil
      end

    {:noreply, change(socket, socket.assigns.form.name, params, lock_version: lock_version)}
  end

  def handle_event("sync", params, socket), do: sync(socket, params)
  def handle_event("publish", params, socket), do: {:noreply, publish(socket, params)}

  def handle_event("suggest_description", _params, socket),
    do: {:noreply, suggest_description(socket, socket.view.record(socket))}

  def handle_event(event, params, socket) when event in ~w(discard restore unpublish) do
    # Only a crafted event gets here for a new record.
    case {event, socket.view.record(socket)} do
      {_event, %{id: nil}} -> {:noreply, socket}
      {"discard", _record} -> {:noreply, discard_changes(socket)}
      {"restore", _record} -> {:noreply, restore_version(socket, params["number"])}
      {"unpublish", _record} -> {:noreply, unpublish(socket)}
    end
  end

  @doc """
  Handles a change from `FeatherWeb.HeaderImagePicker`: puts it into the
  form params and autosaves them.
  """
  @spec handle_info(
          {FeatherWeb.HeaderImagePicker, FeatherWeb.HeaderImagePicker.change()},
          Socket.t()
        ) ::
          {:noreply, Socket.t()}
  def handle_info({FeatherWeb.HeaderImagePicker, change}, socket) do
    params = put_picker_change(socket.assigns.params, change)

    {:noreply,
     socket
     |> Phoenix.Component.assign(picker_assigns(change))
     |> autosave(params)}
  end

  defp discard_changes(socket) do
    socket.assigns.current_scope
    |> Content.discard_changes(socket.view.record(socket))
    |> handle_version_result(
      socket,
      "Changes were discarded.",
      "The changes could not be discarded"
    )
  end

  defp restore_version(socket, number) do
    scope = socket.assigns.current_scope
    record = socket.view.record(socket)

    result =
      with {number, ""} <- Integer.parse(number || ""),
           %{} = version <- Content.get_version(scope, record, number) do
        Content.restore_version(scope, record, version)
      else
        _no_such_version -> {:error, :no_such_version}
      end

    handle_version_result(
      result,
      socket,
      "Version #{number} was restored.",
      "Version #{number} could not be restored"
    )
  end

  defp handle_version_result({:ok, record}, socket, success, _failure) do
    socket
    |> LiveView.put_flash(:info, success)
    |> LiveView.push_navigate(to: socket.view.edit_path(socket, record))
  end

  defp handle_version_result({:error, reason}, socket, _success, failure) do
    socket
    |> Phoenix.Component.assign(
      :changed_elsewhere?,
      socket.assigns.changed_elsewhere? or reason == :stale
    )
    |> LiveView.put_flash(:error, "#{failure}: #{error_sentence(reason)}.")
  end

  defp error_sentence(:stale), do: "it #{@changed_elsewhere}"
  defp error_sentence(:not_published), do: "it is not published"
  defp error_sentence(:no_such_version), do: "there is no such version"

  defp error_sentence(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map_join(", ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end

  defp unpublish(socket) do
    {:ok, record} = Content.unpublish(socket.assigns.current_scope, socket.view.record(socket))

    socket
    |> put_record(record)
    |> socket.view.assign_form(socket.assigns.params, socket.assigns.form.source.action)
    |> LiveView.put_flash(:info, "#{socket.view.noun()} was unpublished.")
    |> FeatherWeb.SiteAuth.refresh_deploy_status()
  end

  defp init_autosave(socket, record) do
    Phoenix.Component.assign(socket,
      autosave_base: if(record.id, do: record.lock_version, else: 0),
      changed_elsewhere?: false,
      publishing: nil,
      suggesting_description?: false,
      slug_touched?: present?(record.slug)
    )
  end

  defp change(socket, as, event_params, opts) do
    record_params = Map.get(event_params, as, %{})

    socket =
      Phoenix.Component.assign(
        socket,
        :slug_touched?,
        socket.assigns.slug_touched? or slug_target?(event_params, as)
      )

    params = maybe_suggest_slug(record_params, event_params, as, socket)
    save_fields(socket, params, params, opts)
  end

  defp autosave(socket, params), do: save_fields(socket, params, params, [])

  defp save_fields(socket, attrs, form_params, opts) do
    view = socket.view
    record = view.record(socket)

    socket =
      case view.save_fields(socket, attrs, opts) do
        {:ok, saved, socket} -> socket |> put_record(saved) |> push_lock_version(record, saved)
        {:error, :stale} -> Phoenix.Component.assign(socket, :changed_elsewhere?, true)
        {:error, _nothing_saved} -> socket
      end

    socket
    |> view.assign_form(form_params, :validate)
    |> patch_when_created(record)
  end

  # Pushed, not rendered: a render after a reconnect may show another view's counter.
  defp push_lock_version(socket, %{id: id, lock_version: same}, %{lock_version: same})
       when is_binary(id),
       do: socket

  defp push_lock_version(socket, _record, saved),
    do: LiveView.push_event(socket, "lock_version", %{lock_version: saved.lock_version})

  defp patch_when_created(socket, %{id: nil}) do
    case socket.view.record(socket) do
      %{id: id} = created when is_binary(id) ->
        LiveView.push_patch(socket, to: socket.view.edit_path(socket, created))

      _still_new ->
        socket
    end
  end

  defp patch_when_created(socket, _stored), do: socket

  defp sync(socket, params) do
    case parse_sync(params) do
      {:ok, sync} -> sync_record(socket, socket.view.record(socket), sync)
      {:error, :invalid} -> {:reply, %{status: "invalid"}, socket}
    end
  end

  defp sync_record(socket, %{id: nil}, sync) do
    attrs = Map.put(socket.assigns.params, "content", Content.synced_doc(sync))
    socket = save_fields(socket, attrs, socket.assigns.params, [])

    case socket.view.record(socket) do
      %{id: id, lock_version: lock_version} when is_binary(id) ->
        {:reply, %{status: "saved", lock_version: lock_version}, socket}

      _not_created ->
        {:reply, %{status: "invalid"}, socket}
    end
  end

  defp sync_record(socket, record, sync) do
    %{current_scope: scope, autosave_base: base} = socket.assigns

    case Content.sync_content(scope, record, sync, base: base) do
      {:ok, saved} ->
        %{params: params, form: form} = socket.assigns

        socket =
          socket
          |> put_record(saved)
          |> socket.view.assign_form(params, form.source.action)

        {:reply, %{status: "saved", lock_version: saved.lock_version}, socket}

      {:error, :stale} ->
        {:reply, %{status: "stale"}, Phoenix.Component.assign(socket, :changed_elsewhere?, true)}

      {:error, _invalid} ->
        {:reply, %{status: "invalid"}, socket}
    end
  end

  defp parse_sync(%{"lock_version" => lock_version, "blocks" => blocks} = params)
       when (is_integer(lock_version) or is_nil(lock_version)) and is_list(blocks) do
    case params["order"] do
      nil ->
        {:ok, %{lock_version: lock_version, order: nil, blocks: blocks}}

      order when is_list(order) ->
        if Enum.all?(order, &is_binary/1),
          do: {:ok, %{lock_version: lock_version, order: order, blocks: blocks}},
          else: {:error, :invalid}

      _other ->
        {:error, :invalid}
    end
  end

  defp parse_sync(_params), do: {:error, :invalid}

  @doc """
  The form's status for the editor hook: `"conflict"` once the record was
  changed elsewhere, `"invalid"` while a field fails validation (it is
  not saved), else `"saved"`.
  """
  @spec autosave_status(Phoenix.HTML.Form.t(), boolean()) :: String.t()
  def autosave_status(_form, true = _changed_elsewhere?), do: "conflict"
  def autosave_status(form, false), do: if(invalid?(form), do: "invalid", else: "saved")

  @doc """
  Whether the record can be published: it exists, no field is invalid and
  it was not changed elsewhere.
  """
  @spec publishable?(content_record(), Phoenix.HTML.Form.t(), boolean()) :: boolean()
  def publishable?(record, form, changed_elsewhere?) do
    not is_nil(record.id) and not invalid?(form) and not changed_elsewhere?
  end

  defp invalid?(%Phoenix.HTML.Form{source: changeset}),
    do: changeset.action != nil and not changeset.valid?

  defp publish(socket, params) do
    record = socket.view.record(socket)

    cond do
      is_nil(record.id) or invalid?(socket.assigns.form) ->
        LiveView.put_flash(socket, :error, "Not published: fix the marked fields first.")

      socket.assigns.changed_elsewhere? ->
        LiveView.put_flash(socket, :error, "Not published: this #{@changed_elsewhere}.")

      params["editor"] == "unsaved" ->
        LiveView.put_flash(socket, :error, "Not published: the content is not saved yet.")

      socket.assigns[:publishing] ->
        socket

      true ->
        scope = socket.assigns.current_scope

        socket
        |> Phoenix.Component.assign(:publishing, record)
        |> LiveView.put_flash(:info, "Publishing…")
        |> LiveView.start_async(:publish, fn -> publish_unlinked(scope, record) end)
    end
  end

  # Finishes even when the form is left while it waits for the model.
  defp publish_unlinked(scope, record) do
    Feather.TaskSupervisor
    |> Task.Supervisor.async_nolink(fn -> Content.publish(scope, record) end)
    |> Task.await(:infinity)
  end

  @doc """
  Handles the results of publishing (`:publish`) and of suggesting a
  description (`:suggest_description`), see `handle_event/3`.
  """
  @spec handle_async(atom(), {:ok, term()} | {:exit, term()}, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_async(:publish, result, socket) do
    publishing = socket.assigns.publishing
    socket = Phoenix.Component.assign(socket, :publishing, nil)

    {:noreply, published(socket, publishing, result)}
  end

  def handle_async(:suggest_description, result, socket) do
    socket = Phoenix.Component.assign(socket, :suggesting_description?, false)
    {:noreply, suggested_description(socket, result)}
  end

  defp published(socket, _publishing, {:ok, {:ok, published}}) do
    socket
    |> put_record(published, versions: true)
    |> Phoenix.Component.assign(:slug_touched?, present?(published.slug))
    |> assign_form_from_record(~w(description meta_title slug))
    |> FeatherWeb.SiteAuth.refresh_deploy_status()
    |> LiveView.put_flash(:info, "#{socket.view.noun()} was published.")
  end

  defp published(socket, publishing, {:ok, {:error, :stale}}) do
    if socket.view.record(socket).lock_version == publishing.lock_version do
      socket
      |> Phoenix.Component.assign(:changed_elsewhere?, true)
      |> LiveView.put_flash(:error, "Not published: this #{@changed_elsewhere}.")
    else
      LiveView.put_flash(
        socket,
        :error,
        "Not published: it changed while it was being published, publish again."
      )
    end
  end

  defp published(socket, publishing, {:ok, {:error, :slug_taken}}) do
    LiveView.put_flash(
      socket,
      :error,
      "Not published: another #{slug_rivals(publishing)} is published with this slug."
    )
  end

  defp published(socket, _publishing, {:exit, _reason}),
    do: LiveView.put_flash(socket, :error, "Not published: something went wrong, try again.")

  defp suggest_description(socket, %schema{id: id} = record)
       when schema in [Post, Page] and is_binary(id) do
    if socket.assigns[:suggesting_description?] do
      socket
    else
      scope = socket.assigns.current_scope

      socket
      |> Phoenix.Component.assign(:suggesting_description?, true)
      |> LiveView.start_async(:suggest_description, fn ->
        Content.suggest_description(scope, record)
      end)
    end
  end

  defp suggest_description(socket, _new_record_or_project), do: socket

  defp suggested_description(socket, {:ok, {:ok, description}}) do
    record = socket.view.record(socket)

    case Content.put_suggested_description(socket.assigns.current_scope, record, description) do
      {:ok, saved} ->
        socket
        |> put_record(saved)
        |> push_lock_version(record, saved)
        |> assign_form_from_record(~w(description))

      {:error, :stale} ->
        Phoenix.Component.assign(socket, :changed_elsewhere?, true)
    end
  end

  defp suggested_description(socket, _no_description) do
    LiveView.put_flash(
      socket,
      :error,
      "No description could be suggested: the model did not answer or there is no text yet."
    )
  end

  # The form shows the record's values of the fields in place of what was typed before.
  defp assign_form_from_record(socket, fields) do
    %{params: params, form: form} = socket.assigns
    socket.view.assign_form(socket, Map.drop(params, fields), form.source.action)
  end

  defp slug_rivals(%Project{}), do: "project"
  defp slug_rivals(_post_or_page), do: "post or page"

  defp editor_json(scope, record), do: Jason.encode!(Content.editor_doc(scope, record))

  defp slug_target?(%{"_target" => [as, "slug"]}, as), do: true
  defp slug_target?(_params, _as), do: false

  defp maybe_suggest_slug(record_params, event_params, as, socket) do
    %{current_scope: scope, slug_touched?: slug_touched?} = socket.assigns

    if not slug_touched? and event_params["_target"] == [as, "title"] do
      title = record_params["title"] || ""

      Map.put(
        record_params,
        "slug",
        Content.suggest_slug(scope, title, socket.view.record(socket))
      )
    else
      record_params
    end
  end

  @doc "The content length of a record."
  @spec content_length(map()) :: non_neg_integer()
  def content_length(%{content: content}), do: Blocks.content_length(content)

  @doc "Whether the form has no title, so it edits a short post."
  @spec untitled?(Phoenix.HTML.Form.t()) :: boolean()
  def untitled?(form), do: not present?(form[:title].value)

  @doc "Whether the title field is shown: when it has a value or the content is not short."
  @spec show_title?(Phoenix.HTML.Form.t(), non_neg_integer()) :: boolean()
  def show_title?(form, content_length) do
    not untitled?(form) or content_length >= @short_post_length
  end

  defp put_picker_change(params, {:cover, image}),
    do: Map.put(params, "header_image_id", image && image.id)

  defp put_picker_change(params, {:thumbnail, image}),
    do: Map.put(params, "thumbnail_image_id", image && image.id)

  defp put_picker_change(params, {:emoji, emoji}), do: Map.put(params, "emoji", emoji || "")

  defp picker_assigns({:cover, image}), do: [header_image: image]
  defp picker_assigns({:thumbnail, image}), do: [thumbnail_image: image]
  defp picker_assigns({:emoji, _emoji}), do: []

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
  Whether the details card is open: while a field fails validation, so
  errors in its fields are visible.
  """
  @spec details_open?(Phoenix.HTML.Form.t()) :: boolean()
  def details_open?(form), do: invalid?(form)

  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(value), do: value

  @doc "Returns true for a non-blank value."
  @spec present?(term()) :: boolean()
  def present?(nil), do: false
  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(_value), do: true
end
