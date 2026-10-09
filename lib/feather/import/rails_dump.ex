defmodule Feather.Import.RailsDump do
  @moduledoc """
  One-time import of the Rails app's data from a dump written by its
  `feather:dump` task (see `Feather.Import.Dump` for the layout).

      mix feather.import DIR [--force]
      bin/feather eval 'Feather.Release.import_dump("/data/dump")'

  The import refuses to run unless the database holds no users and no
  sites; `force: true` first deletes all application data and the image
  files of the existing images. Everything runs in one transaction, so a
  failed import leaves the database as it was (image files it wrote are
  removed again; with `force: true` the old image files are gone).

  What it keeps and maps:

    * primary keys (UUIDs) and public ids as they are; timestamps with
      microseconds; `site_users` (integer ids in Rails) get new ids
    * users are confirmed (`confirmed_at` is their creation time)
    * images: the original is copied into `Feather.Media` storage, type
      and dimensions are read with libvips, and all variants generated.
      `imageable` Post/Page/Project becomes the owner column, Book becomes
      the book's `cover_image_id`. Unowned images embedded by an image
      block get that record as owner (as saving it in the CMS would)
    * content is kept, normalized by `Feather.Content.Blocks.normalize/1`
      (blocks that change are reported); posts, pages and projects are
      published as version 1, except draft posts
    * navigation items move from the site's navigation to the site and
      are renumbered 1..n per site in their original order
    * deployment targets take their config from `config_plain` (encrypted
      on insert) and are not deploying

  Records violating a current validation are imported anyway and
  reported; records that cannot be stored (missing parent, missing image
  file, constraint violation) are skipped and reported. Dangling
  references are dropped (header images, review posts) or reported
  (blocks). See `Feather.Import.Report`.
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Accounts.{ApiToken, Scope, User, UserToken}
  alias Feather.Books.Book
  alias Feather.Content
  alias Feather.Content.{Blocks, Page, Post, Project, Slug}
  alias Feather.Import.{Dump, Report}
  alias Feather.Media
  alias Feather.Media.{Image, Processor}
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Sites.{Invitation, NavigationItem, Site, SiteUser, SocialMediaLink}

  @written_dirs {__MODULE__, :written_dirs}
  @owner_fields %{"Post" => :post_id, "Page" => :page_id, "Project" => :project_id}
  @path_safe_public_id ~r/\A[0-9A-Za-z_-]{1,64}\z/
  @sha256_hex ~r/\A[0-9a-f]{64}\z/

  @doc """
  Imports the dump in `dir`. Options: `force: true` wipes existing data
  first; `now:` the time used for the cleanup preview in the report.

  Returns `{:ok, report}`, `{:error, :not_empty}` when the database already
  holds data, or `{:error, message}` for an unreadable dump.
  """
  @spec run(Path.t(), keyword()) :: {:ok, Report.t()} | {:error, :not_empty | String.t()}
  def run(dir, opts \\ []) do
    force? = Keyword.get(opts, :force, false)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    with {:ok, dump} <- Dump.read(dir),
         :ok <- ensure_empty(force?) do
      Process.put(@written_dirs, [])

      try do
        result =
          Repo.transact(
            fn ->
              if force?, do: wipe()
              {:ok, dump |> new_state() |> import_all() |> preview_cleanup(now)}
            end,
            timeout: :infinity
          )

        case result do
          {:ok, state} ->
            {:ok, state.report}

          {:error, reason} ->
            remove_written_dirs()
            {:error, reason}
        end
      rescue
        exception ->
          remove_written_dirs()
          reraise exception, __STACKTRACE__
      after
        Process.delete(@written_dirs)
      end
    end
  end

  defp ensure_empty(true), do: :ok

  defp ensure_empty(false) do
    if Repo.exists?(Site) or Repo.exists?(User), do: {:error, :not_empty}, else: :ok
  end

  # Children before parents; foreign key actions clear the rest.
  defp wipe do
    for image <- Repo.all(Image), do: Media.delete_image_files(image)

    for schema <- [
          NavigationItem,
          Book,
          DeploymentTarget,
          SocialMediaLink,
          Invitation,
          SiteUser,
          ApiToken,
          Image,
          Post,
          Page,
          Project,
          Site,
          UserToken,
          User
        ] do
      Repo.delete_all(schema)
    end
  end

  defp remove_written_dirs do
    @written_dirs |> Process.get([]) |> Enum.each(&File.rm_rf/1)
  end

  defp new_state(dump) do
    report =
      Enum.reduce(Dump.tables(), %Report{}, fn table, report ->
        Report.dumped(report, table, length(Dump.rows(dump, table)))
      end)

    %{
      dump: dump,
      report: report,
      # id => inserted_at
      users: %{},
      # id => %Site{}
      sites: %{},
      # id => %{site_id, public_id, owner}
      images: %{},
      # {site_id, public_id} => id
      image_ids: %{},
      # Book id => image id, from imageable
      covers: %{},
      # :post_id / :page_id / :project_id => id => %{site_id, label, content}
      records: %{post_id: %{}, page_id: %{}, project_id: %{}},
      # {site_id, Slug.url_space/1, slug} of the published records
      published_slugs: MapSet.new(),
      # {site_id, public_id} => id
      books: %{}
    }
  end

  defp import_all(state) do
    state
    |> import_users()
    |> import_sites()
    |> import_site_users()
    |> import_invitations()
    |> import_social_media_links()
    |> import_api_tokens()
    |> import_images()
    |> import_contents("posts", Post, :post_id)
    |> import_contents("pages", Page, :page_id)
    |> import_contents("projects", Project, :project_id)
    |> assign_image_owners()
    |> import_books()
    |> check_content_references()
    |> import_navigation_items()
    |> import_deployment_targets()
  end

  ## Users and sites

  defp import_users(state) do
    each_row(state, "users", fn row, state ->
      inserted_at = Dump.timestamp(row["created_at"])

      changeset =
        %User{id: row["id"], inserted_at: inserted_at, updated_at: updated_at(row)}
        |> User.email_changeset(%{"email" => row["email"] || ""})
        |> Ecto.Changeset.put_change(:super_admin, row["super_admin"] == true)
        |> Ecto.Changeset.put_change(:confirmed_at, DateTime.truncate(inserted_at, :second))

      case insert(state, "users", "user #{row["email"]}", changeset) do
        {:ok, user, state} -> put_in(state.users[user.id], user.inserted_at)
        {:error, state} -> state
      end
    end)
  end

  defp import_sites(state) do
    each_row(state, "sites", fn row, state ->
      label = "site #{row["public_id"]} (#{row["domain"]})"
      {attrs, state} = with_default(state, row, "copyright", "© All rights reserved.", label)

      changeset =
        %Site{id: row["id"], public_id: row["public_id"]}
        |> timestamps(row)
        |> Site.create_changeset(
          Map.take(attrs, ~w(title domain language_code emoji copyright))
          |> Map.update("language_code", "en", &(&1 || "en"))
        )

      state = check_public_id(state, row, label)

      case insert(state, "sites", label, changeset) do
        {:ok, site, state} -> put_in(state.sites[site.id], site)
        {:error, state} -> state
      end
    end)
  end

  defp import_site_users(state) do
    each_row(state, "site_users", fn row, state ->
      label = "membership of user #{row["user_id"]} in site #{row["site_id"]}"

      with {:ok, site} <- fetch(state.sites, row["site_id"], "site"),
           {:ok, user_inserted_at} <- fetch(state.users, row["user_id"], "user") do
        # Rails kept no timestamps for memberships: use the later creation.
        inserted_at = Enum.max([site.inserted_at, user_inserted_at], DateTime)

        changeset =
          %SiteUser{
            site_id: site.id,
            user_id: row["user_id"],
            inserted_at: inserted_at,
            updated_at: inserted_at
          }
          |> SiteUser.changeset(%{"role" => row["role"]})

        insert(state, "site_users", label, changeset) |> state_of()
      else
        {:missing, what} -> skip_dangling(state, label, what)
      end
    end)
  end

  defp import_invitations(state) do
    each_row(state, "user_invitations", fn row, state ->
      label = "invitation of #{row["email"]}"

      with {:ok, site} <- fetch(state.sites, row["site_id"], "site"),
           {:ok, _} <- fetch(state.users, row["inviting_user_id"], "inviting user") do
        changeset =
          %Invitation{
            id: row["id"],
            site_id: site.id,
            inviting_user_id: row["inviting_user_id"],
            accepted_at: Dump.timestamp(row["accepted_at"])
          }
          |> timestamps(row)
          |> Invitation.changeset(%{"email" => row["email"] || ""})

        insert(state, "user_invitations", label, changeset) |> state_of()
      else
        {:missing, what} -> skip_dangling(state, label, what)
      end
    end)
  end

  defp import_social_media_links(state) do
    each_row(state, "social_media_links", fn row, state ->
      label = "social media link #{row["url"]}"

      case fetch(state.sites, row["site_id"], "site") do
        {:ok, site} ->
          changeset =
            %SocialMediaLink{id: row["id"], site_id: site.id}
            |> timestamps(row)
            |> SocialMediaLink.changeset(Map.take(row, ~w(name url icon)))

          insert(state, "social_media_links", label, changeset) |> state_of()

        {:missing, what} ->
          skip_dangling(state, label, what)
      end
    end)
  end

  defp import_api_tokens(state) do
    each_row(state, "api_tokens", fn row, state ->
      label = "API token #{row["token_prefix"]}… (#{row["name"]})"

      case fetch(state.users, row["user_id"], "user") do
        {:ok, _} ->
          state =
            if is_binary(row["token_digest"]) and row["token_digest"] =~ @sha256_hex,
              do: state,
              else: notice(state, "#{label}: digest is not SHA-256 hex, it will not authenticate")

          changeset =
            %ApiToken{id: row["id"], user_id: row["user_id"]}
            |> timestamps(row)
            |> Ecto.Changeset.change(
              name: row["name"],
              token_digest: row["token_digest"],
              token_prefix: row["token_prefix"]
            )
            |> Ecto.Changeset.validate_required([:token_digest, :token_prefix])
            |> Ecto.Changeset.unique_constraint(:token_digest)

          insert(state, "api_tokens", label, changeset) |> state_of()

        {:missing, what} ->
          skip_dangling(state, label, what)
      end
    end)
  end

  ## Images

  defp import_images(state) do
    each_row(state, "images", fn row, state ->
      label = "image #{row["public_id"]}"

      with {:ok, site} <- fetch(state.sites, row["site_id"], "site"),
           :ok <- check_image_public_id(row),
           {:ok, source} <- image_source(state.dump, row["file"]),
           {:ok, info} <- inspect_image(source) do
        state =
          state
          |> check_public_id(row, label)
          |> check_checksum(row["file"], source, label)
          |> collect_cover(row)

        import_image(state, row, site, source, info, label)
      else
        {:missing, what} -> skip_dangling(state, label, what)
        {:invalid_public_id, message} -> skip(state, "#{label}: #{message}")
        {:no_file, message} -> finding(state, :missing_file, "#{label}: #{message}")
      end
    end)
  end

  defp check_image_public_id(%{"public_id" => public_id}) when is_binary(public_id) do
    if public_id =~ @path_safe_public_id,
      do: :ok,
      else: {:invalid_public_id, "public id is not usable as a directory name"}
  end

  defp check_image_public_id(_row), do: {:invalid_public_id, "has no public id"}

  defp image_source(_dump, nil), do: {:no_file, "no file attached in Rails"}
  defp image_source(_dump, %{"path" => nil}), do: {:no_file, "the original could not be dumped"}

  defp image_source(dump, %{"path" => path}) do
    case Dump.file_path(dump, path) do
      {:ok, source} -> {:ok, source}
      {:error, message} -> {:no_file, message}
    end
  end

  defp inspect_image(source) do
    case Processor.inspect_file(source) do
      {:ok, info} -> {:ok, info}
      {:error, :not_an_image} -> {:no_file, "the original is not a supported image"}
    end
  end

  defp check_checksum(state, %{"checksum" => checksum}, source, label) when is_binary(checksum) do
    actual = :md5 |> :crypto.hash(File.read!(source)) |> Base.encode64()

    if actual == checksum,
      do: state,
      else: notice(state, "#{label}: checksum differs from the Rails blob, imported anyway")
  end

  defp check_checksum(state, _file, _source, _label), do: state

  defp collect_cover(state, %{"imageable_type" => "Book", "imageable_id" => book_id} = row)
       when is_binary(book_id) do
    case state.covers do
      %{^book_id => _previous} ->
        state
        |> notice("book #{book_id} has several cover images, using image #{row["public_id"]}")
        |> put_in([:covers, book_id], row["id"])

      _ ->
        put_in(state.covers[book_id], row["id"])
    end
  end

  defp collect_cover(state, _row), do: state

  defp import_image(state, row, site, source, info, label) do
    attrs = %{
      "public_id" => row["public_id"],
      "filename" => image_filename(row),
      "content_type" => info.content_type,
      "byte_size" => File.stat!(source).size,
      "width" => info.width,
      "height" => info.height,
      "source_url" => row["source_url"],
      "unsplash_data" => if(is_map(row["unsplash_data"]), do: row["unsplash_data"])
    }

    changeset =
      %Image{id: row["id"], site_id: site.id}
      |> timestamps(row)
      |> Image.create_changeset(attrs)

    image = Ecto.Changeset.apply_changes(changeset)

    case write_files(image, source, info.extension) do
      :ok ->
        case insert(state, "images", label, changeset) do
          {:ok, image, state} ->
            entry = %{site_id: site.id, public_id: image.public_id, owner: nil}

            state
            |> put_in([:images, image.id], entry)
            |> put_in([:image_ids, {site.id, image.public_id}], image.id)

          {:error, state} ->
            Media.delete_image_files(image)
            state
        end

      {:error, reason} ->
        Media.delete_image_files(image)
        skip(state, "#{label}: generating variants failed (#{inspect(reason)})")
    end
  end

  defp image_filename(row) do
    name = get_in(row, ["file", "filename"]) || ""

    case name |> Path.basename() |> String.trim() do
      "" -> "image"
      name -> String.slice(name, 0, 255)
    end
  end

  defp write_files(image, source, extension) do
    dir = Media.image_dir(image)
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    Process.put(@written_dirs, [dir | Process.get(@written_dirs, [])])
    File.cp!(source, Path.join(dir, "original.#{extension}"))
    Media.generate_variants(image)
  end

  ## Posts, pages and projects

  defp import_contents(state, table, schema, owner_field) do
    each_row(state, table, fn row, state ->
      label = "#{singular(table)} #{row["public_id"]} (#{row["slug"]})"

      case fetch(state.sites, row["site_id"], "site") do
        {:ok, site} ->
          {content, state} = normalize_content(state, row["content"], label)
          {attrs, state} = content_attrs(state, table, row, site, label)

          changeset =
            schema
            |> struct(id: row["id"], site_id: site.id, public_id: row["public_id"])
            |> timestamps(row)
            |> schema.create_changeset(Map.put(attrs, "content", content))

          state = check_public_id(state, row, label)

          case insert(state, table, label, changeset) do
            {:ok, record, state} ->
              state =
                if draft_post?(table, row),
                  do: state,
                  else: publish_imported(state, site, record, label)

              entry = %{site_id: site.id, label: label, content: record.content}
              put_in(state, [:records, owner_field, record.id], entry)

            {:error, state} ->
              state
          end

        {:missing, what} ->
          skip_dangling(state, label, what)
      end
    end)
  end

  defp draft_post?(table, row), do: table == "posts" and row["draft"] == true

  # Rails kept slugs unique per table, so a page may have the slug of a
  # post: the one imported second stays a draft. Checked here, as
  # Content.publish/2 refusing it would roll back the import.
  defp publish_imported(state, site, %schema{slug: slug} = record, label) do
    key = {site.id, Slug.url_space(schema), slug}

    if slug && MapSet.member?(state.published_slugs, key) do
      notice(state, "#{label}: not published, another post or page is published with its slug")
    else
      {:ok, _record} = Content.publish(Scope.for_site(site), record)
      update_in(state.published_slugs, &MapSet.put(&1, key))
    end
  end

  defp content_attrs(state, table, row, site, label) do
    fields =
      case table do
        "posts" -> ~w(title slug emoji tags publish_at)
        "pages" -> ~w(title slug emoji tags page_type)
        "projects" -> ~w(title slug emoji tags short_description company role period
                         started_at ended_at status project_type)
      end

    attrs = Map.take(row, fields)

    {attrs, state} =
      Enum.reduce(~w(header_image_id thumbnail_image_id), {attrs, state}, fn field,
                                                                             {attrs, state} ->
        case site_image(state, row[field], site) do
          {:ok, id} ->
            {Map.put(attrs, field, id), state}

          {:missing, id} ->
            {attrs, dangling(state, "#{label}: #{field} #{id} is not an imported image, dropped")}
        end
      end)

    case {table, row["publish_at"]} do
      {"posts", nil} ->
        {Map.put(attrs, "publish_at", row["created_at"]),
         notice(state, "#{label}: had no publish_at, using its creation time")}

      {"projects", _} ->
        project_links(attrs, state, row["links"], label)

      _ ->
        {attrs, state}
    end
  end

  defp site_image(_state, nil, _site), do: {:ok, nil}

  defp site_image(state, image_id, site) do
    case state.images do
      %{^image_id => %{site_id: site_id}} when site_id == site.id -> {:ok, image_id}
      _ -> {:missing, image_id}
    end
  end

  defp project_links(attrs, state, links, label) when is_list(links) do
    {valid, invalid} =
      Enum.split_with(links, fn
        %{"label" => label, "url" => url} -> present?(label) and present?(url)
        _ -> false
      end)

    state =
      Enum.reduce(invalid, state, fn link, state ->
        notice(state, "#{label}: link #{inspect(link)} has no label or url, dropped")
      end)

    {Map.put(attrs, "links", Enum.map(valid, &Map.take(&1, ~w(label url)))), state}
  end

  defp project_links(attrs, state, links, _label) when links in [nil, %{}],
    do: {Map.put(attrs, "links", []), state}

  defp project_links(attrs, state, links, label) do
    {Map.put(attrs, "links", []),
     notice(state, "#{label}: links #{inspect(links)} are not a list, dropped")}
  end

  # The content is the Rails internal block format already; normalizing it
  # only fills defaults. Report every block that changes.
  defp normalize_content(state, nil, _label), do: {[], state}

  defp normalize_content(state, blocks, label) when is_list(blocks) do
    normalized = Blocks.normalize(blocks)
    by_id = Map.new(normalized, &{&1["id"], &1})

    changes =
      blocks
      |> Enum.with_index()
      |> Enum.flat_map(fn {block, index} ->
        id = is_map(block) && block["id"]

        case {block, id && Map.fetch(by_id, id)} do
          {%{} = block, {:ok, normalized}} when normalized == block ->
            []

          {%{} = block, {:ok, _changed}} ->
            ["block #{id} (#{block["type"]}) changed"]

          {%{} = block, _} when not is_binary(id) ->
            ["block ##{index + 1} (#{block["type"]}) #{gained_or_dropped(block)}"]

          {%{} = block, _} ->
            ["block #{id} (#{block["type"]}) dropped"]

          {other, _} ->
            ["block ##{index + 1} #{inspect(other)} dropped"]
        end
      end)

    state =
      if changes == [],
        do: state,
        else: finding(state, :content_changed, "#{label}: " <> Enum.join(changes, ", "))

    {normalized, state}
  end

  defp normalize_content(state, other, label) do
    {[], finding(state, :content_changed, "#{label}: content #{inspect(other)} dropped")}
  end

  defp gained_or_dropped(block) do
    if Blocks.normalize([block]) == [], do: "dropped", else: "got a new id"
  end

  # Rails' imageable Post/Page/Project becomes the owner column.
  defp assign_image_owners(state) do
    rows = Dump.rows(state.dump, "images")

    Enum.reduce(rows, state, fn row, state ->
      image_id = row["id"]
      type = row["imageable_type"]
      owner_id = row["imageable_id"]

      cond do
        not Map.has_key?(state.images, image_id) or is_nil(type) or type == "Book" ->
          state

        not Map.has_key?(@owner_fields, type) ->
          notice(state, "image #{row["public_id"]}: unknown imageable #{type}, left unowned")

        true ->
          field = Map.fetch!(@owner_fields, type)
          image = state.images[image_id]

          case state.records[field] do
            %{^owner_id => %{site_id: site_id}} when site_id == image.site_id ->
              set_owner(state, image_id, field, owner_id)

            _ ->
              dangling(
                state,
                "image #{row["public_id"]}: owner #{type} #{owner_id} was not imported, left unowned"
              )
          end
      end
    end)
  end

  defp set_owner(state, image_id, field, owner_id) do
    Repo.update_all(from(i in Image, where: i.id == ^image_id), set: [{field, owner_id}])
    put_in(state.images[image_id].owner, {field, owner_id})
  end

  ## Books

  defp import_books(state) do
    state = Map.put(state, :review_posts, MapSet.new())

    state =
      each_row(state, "books", fn row, state ->
        label = "book #{row["public_id"]} (#{row["title"]})"

        case fetch(state.sites, row["site_id"], "site") do
          {:ok, site} -> import_book(state, row, site, label)
          {:missing, what} -> skip_dangling(state, label, what)
        end
      end)

    Map.delete(state, :review_posts)
  end

  defp import_book(state, row, site, label) do
    {post_id, state} = review_post(state, row["post_id"], site, label)
    {cover_id, state} = cover_image(state, row["id"], site, label)

    attrs =
      row
      |> Map.take(~w(title author emoji isbn open_library_key rating reading_status))
      |> Map.put("read_at", Dump.date(row["read_at"]))
      |> Map.put("cover_image_id", cover_id)

    changeset =
      %Book{id: row["id"], site_id: site.id, public_id: row["public_id"], post_id: post_id}
      |> timestamps(row)
      |> Book.create_changeset(attrs)

    state = check_public_id(state, row, label)

    case insert(state, "books", label, changeset) do
      {:ok, book, state} ->
        state = put_in(state.books[{site.id, book.public_id}], book.id)
        if post_id, do: update_in(state.review_posts, &MapSet.put(&1, post_id)), else: state

      {:error, state} ->
        state
    end
  end

  defp review_post(state, nil, _site, _label), do: {nil, state}

  defp review_post(state, post_id, site, label) do
    cond do
      not match?(%{site_id: site_id} when site_id == site.id, state.records.post_id[post_id]) ->
        {nil, dangling(state, "#{label}: review post #{post_id} was not imported, dropped")}

      MapSet.member?(state.review_posts, post_id) ->
        {nil, dangling(state, "#{label}: post #{post_id} already reviews another book, dropped")}

      true ->
        {post_id, state}
    end
  end

  defp cover_image(state, book_id, site, label) do
    case Map.fetch(state.covers, book_id) do
      :error ->
        {nil, state}

      {:ok, image_id} ->
        case site_image(state, image_id, site) do
          {:ok, id} -> {id, state}
          {:missing, id} -> {nil, dangling(state, "#{label}: cover image #{id} not imported")}
        end
    end
  end

  ## Content references

  # Image blocks must point at images of the site (unowned ones are given
  # to the embedding record, as saving it in the CMS would do); book blocks
  # at books of the site.
  defp check_content_references(state) do
    for {field, records} <- state.records,
        {id, record} <- Enum.sort_by(records, fn {_id, r} -> r.label end),
        reduce: state do
      state ->
        state =
          Enum.reduce(Blocks.image_ids(record.content), state, fn public_id, state ->
            case state.image_ids[{record.site_id, public_id}] do
              nil ->
                dangling(
                  state,
                  "#{record.label}: image block references missing image #{public_id}"
                )

              image_id ->
                case state.images[image_id].owner do
                  nil ->
                    state
                    |> set_owner(image_id, field, id)
                    |> notice(
                      "image #{public_id}: unowned but embedded by #{record.label}, now owned by it"
                    )

                  _owner ->
                    state
                end
            end
          end)

        Enum.reduce(Blocks.book_ids(record.content), state, fn public_id, state ->
          if Map.has_key?(state.books, {record.site_id, public_id}),
            do: state,
            else:
              dangling(state, "#{record.label}: book block references missing book #{public_id}")
        end)
    end
  end

  ## Navigation

  defp import_navigation_items(state) do
    navigations =
      state.dump
      |> Dump.rows("navigations")
      |> Map.new(&{&1["id"], &1["site_id"]})

    {by_site, state} =
      state.dump
      |> Dump.rows("navigation_items")
      |> Enum.reduce({%{}, state}, fn row, {by_site, state} ->
        label = "navigation item #{row["public_id"]}"
        site_id = navigations[row["navigation_id"]]
        page = state.records.page_id[row["page_id"]]

        cond do
          is_nil(site_id) or not Map.has_key?(state.sites, site_id) ->
            {by_site, skip_dangling(state, label, "navigation #{row["navigation_id"]}")}

          not match?(%{site_id: ^site_id}, page) ->
            {by_site, skip_dangling(state, label, "page #{row["page_id"]}")}

          Enum.any?(Map.get(by_site, site_id, []), &(&1["page_id"] == row["page_id"])) ->
            {by_site,
             skip(state, "#{label}: page #{row["page_id"]} is already in the navigation")}

          true ->
            {Map.update(by_site, site_id, [row], &[row | &1]), state}
        end
      end)

    by_site
    |> Enum.sort()
    |> Enum.reduce(state, fn {site_id, rows}, state ->
      rows
      |> Enum.sort_by(&{&1["position"] || 0, &1["created_at"] || ""})
      |> Enum.with_index(1)
      |> Enum.reduce(state, fn {row, position}, state ->
        changeset =
          %NavigationItem{id: row["id"], site_id: site_id, page_id: row["page_id"]}
          |> timestamps(row)
          |> Ecto.Changeset.change(position: position)
          |> Ecto.Changeset.unique_constraint([:site_id, :page_id])

        insert(state, "navigation_items", "navigation item #{row["public_id"]}", changeset)
        |> state_of()
      end)
    end)
    |> count_navigations(navigations)
  end

  # Navigations have no table of their own any more: they are counted as
  # imported when their site is.
  defp count_navigations(state, navigations) do
    count = Enum.count(navigations, fn {_id, site_id} -> Map.has_key?(state.sites, site_id) end)
    update_in(state.report, &Report.imported(&1, "navigations", count))
  end

  ## Deployment targets

  defp import_deployment_targets(state) do
    each_row(state, "deployment_targets", fn row, state ->
      label = "deployment target #{row["public_id"]} (#{row["public_hostname"]})"

      case fetch(state.sites, row["site_id"], "site") do
        {:ok, site} ->
          {config, state} = deployment_config(state, row, label)

          changeset =
            %DeploymentTarget{id: row["id"], site_id: site.id, public_id: row["public_id"]}
            |> timestamps(row)
            |> DeploymentTarget.create_changeset(
              row
              |> Map.take(~w(type provider public_hostname))
              |> Map.put("config", config)
            )
            |> Ecto.Changeset.put_change(:deploying, false)

          state = check_public_id(state, row, label)
          insert(state, "deployment_targets", label, changeset) |> state_of()

        {:missing, what} ->
          skip_dangling(state, label, what)
      end
    end)
  end

  defp deployment_config(state, %{"config_plain" => %{} = config}, _label), do: {config, state}

  defp deployment_config(state, %{"encrypted_config" => raw}, label) when is_binary(raw) do
    case Jason.decode(raw) do
      {:ok, %{} = config} ->
        {config, state}

      _ ->
        {%{}, notice(state, "#{label}: config could not be read, imported empty: set it again")}
    end
  end

  defp deployment_config(state, _row, _label), do: {%{}, state}

  ## Cleanup preview

  # Images the daily cleanup will delete: worth a look before go-live.
  defp preview_cleanup(state, now) do
    %{unreferenced: unreferenced, unused: unused} = Media.orphaned_images(now)

    state =
      Enum.reduce(unreferenced, state, fn image, state ->
        notice(state, "image #{image.public_id}: used nowhere, the daily cleanup will delete it")
      end)

    Enum.reduce(unused, state, fn image, state ->
      notice(
        state,
        "image #{image.public_id}: not embedded by its owner, the daily cleanup will delete it"
      )
    end)
  end

  ## Helpers

  defp each_row(state, table, fun) do
    state.dump |> Dump.rows(table) |> Enum.reduce(state, fun)
  end

  defp timestamps(struct, row) do
    %{struct | inserted_at: Dump.timestamp(row["created_at"]), updated_at: updated_at(row)}
  end

  defp updated_at(row), do: Dump.timestamp(row["updated_at"] || row["created_at"])

  defp with_default(state, row, field, default, label) do
    case row[field] do
      nil ->
        {Map.put(row, field, default),
         notice(state, "#{label}: #{field} was empty, set to #{inspect(default)}")}

      _ ->
        {row, state}
    end
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp fetch(map, id, what) do
    case map do
      %{^id => value} -> {:ok, value}
      _ -> {:missing, "#{what} #{id}"}
    end
  end

  defp check_public_id(state, %{"public_id" => public_id}, label) do
    if Feather.PublicId.valid?(public_id),
      do: state,
      else: notice(state, "#{label}: legacy public id #{inspect(public_id)} kept")
  end

  defp check_public_id(state, _row, _label), do: state

  # Inserts the changeset. A changeset failing only rule validations
  # (format, inclusion, ...) is inserted anyway and reported; one missing
  # required or uncastable values, or hitting a constraint, is skipped.
  defp insert(state, table, label, %Ecto.Changeset{} = changeset) do
    case bypass_validations(changeset, state, label) do
      {:ok, changeset, state} ->
        try do
          case Repo.insert(changeset) do
            {:ok, record} -> {:ok, record, update_in(state.report, &Report.imported(&1, table))}
            {:error, changeset} -> {:error, skip(state, "#{label}: #{errors(changeset)}")}
          end
        rescue
          exception in [Ecto.ConstraintError, Exqlite.Error] ->
            {:error, skip(state, "#{label}: #{Exception.message(exception)}")}
        end

      {:error, changeset} ->
        {:error, skip(state, "#{label}: #{errors(changeset)}")}
    end
  end

  defp bypass_validations(%Ecto.Changeset{valid?: true} = changeset, state, _label),
    do: {:ok, changeset, state}

  defp bypass_validations(changeset, state, label) do
    # Missing or uncastable values cannot be stored; nested changesets
    # (project links) are cleaned before casting.
    storable? =
      Enum.all?(changeset.errors, fn {_field, {_message, opts}} ->
        opts[:validation] not in [:required, :cast]
      end)

    if storable? do
      state = finding(state, :validation_bypassed, "#{label}: #{errors(changeset)}")
      {:ok, %{changeset | valid?: true, errors: []}, state}
    else
      {:error, changeset}
    end
  end

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, messages} ->
      "#{field} #{Enum.join(List.flatten(messages) |> Enum.map(&format_error/1), ", ")}"
    end)
  end

  defp format_error(message) when is_binary(message), do: message
  defp format_error(other), do: inspect(other)

  defp state_of({:ok, _record, state}), do: state
  defp state_of({:error, state}), do: state

  defp singular("posts"), do: "post"
  defp singular("pages"), do: "page"
  defp singular("projects"), do: "project"

  defp finding(state, kind, message), do: update_in(state.report, &Report.add(&1, kind, message))
  defp notice(state, message), do: finding(state, :notice, message)
  defp dangling(state, message), do: finding(state, :dangling_reference, message)
  defp skip(state, message), do: finding(state, :skipped, message)

  defp skip_dangling(state, label, what),
    do: finding(state, :dangling_reference, "#{label}: #{what} missing, not imported")
end
