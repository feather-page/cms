defmodule Feather.Repo.Migrations.BackfillRedirects do
  use Ecto.Migration

  @records [
    {"posts", "post_versions", "post_id"},
    {"pages", "page_versions", "page_id"},
    {"projects", "project_versions", "project_id"}
  ]
  @path_format ~r{\A/[A-Za-z0-9\-._~!$&'()*+,;=:@/]*\z}
  @public_id_alphabet ~c"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def up do
    held = held_paths()
    redirected = existing_redirects()

    redirects =
      @records
      |> Enum.flat_map(&earlier_urls/1)
      |> Enum.reject(&(MapSet.member?(redirected, key(&1)) or held_by_other?(held, &1)))
      |> Enum.group_by(&key/1)
      |> Enum.map(fn {_key, candidates} -> Enum.max_by(candidates, & &1.published_at) end)

    now = DateTime.to_iso8601(DateTime.utc_now())
    Enum.each(redirects, &insert_redirect(&1, now))

    for site_id <- redirects |> Enum.map(& &1.site_id) |> Enum.uniq() do
      repo().query!("UPDATE sites SET updated_at = ?1 WHERE id = ?2", [now, site_id])
    end
  end

  def down, do: :ok

  defp earlier_urls({table, versions, owner}) do
    """
    SELECT r.site_id, r.id, r.public_id, v.slug, v.number, v.published_at
    FROM #{versions} v JOIN #{table} r ON r.id = v.#{owner}
    """
    |> repo().query!()
    |> Map.fetch!(:rows)
    |> Enum.group_by(fn [_site_id, id | _rest] -> id end)
    |> Enum.flat_map(fn {_id, versions} ->
      [_, _, public_id, newest_slug, _, _] =
        Enum.max_by(versions, fn [_, _, _, _, number, _] -> number end)

      newest_url = url(table, public_id, newest_slug)

      for [site_id, id, public_id, slug, _number, published_at] <- versions,
          path = url(table, public_id, slug),
          path not in [newest_url, "/"] and Regex.match?(@path_format, path) do
        %{
          site_id: site_id,
          old_path: path,
          record: {owner, id},
          published_at: published_at
        }
      end
    end)
  end

  # A record also holds the URL its published version shows, which its slug may have left.
  defp held_paths do
    @records
    |> Enum.flat_map(fn {table, versions, owner} ->
      """
      SELECT r.site_id, r.id, r.public_id, r.slug FROM #{table} r
      UNION ALL
      SELECT r.site_id, r.id, r.public_id, v.slug
      FROM #{table} r JOIN #{versions} v ON v.id = r.published_version_id
      """
      |> repo().query!()
      |> Map.fetch!(:rows)
      |> Enum.flat_map(fn [site_id, id, public_id, slug] ->
        paths = [url(table, public_id, slug)]
        paths = if table == "posts", do: [url(table, public_id, nil) | paths], else: paths
        for path <- paths, do: {{site_id, path}, {owner, id}}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {key, records} -> {key, MapSet.new(records)} end)
  end

  defp existing_redirects do
    "SELECT site_id, old_path FROM redirects"
    |> repo().query!()
    |> Map.fetch!(:rows)
    |> MapSet.new(fn [site_id, old_path] -> {site_id, old_path} end)
  end

  defp held_by_other?(held, %{record: record} = redirect) do
    held |> Map.get(key(redirect), MapSet.new()) |> MapSet.delete(record) |> Enum.any?()
  end

  defp key(%{site_id: site_id, old_path: old_path}), do: {site_id, old_path}

  defp url("posts", public_id, slug) do
    case strip(slug) do
      "" -> "/posts/" <> String.downcase(public_id)
      segment -> "/" <> segment
    end
  end

  defp url("pages", _public_id, slug), do: "/" <> strip(slug)
  defp url("projects", _public_id, slug), do: "/projects/" <> strip(slug)

  defp strip(nil), do: ""
  defp strip(slug), do: slug |> String.trim() |> String.trim("/")

  defp insert_redirect(%{site_id: site_id, old_path: old_path, record: {owner, id}}, now) do
    repo().query!(
      """
      INSERT INTO redirects (id, public_id, site_id, old_path, kind, #{owner},
                             inserted_at, updated_at)
      VALUES (?1, ?2, ?3, ?4, 'permanent', ?5, ?6, ?6)
      """,
      [Ecto.UUID.generate(), public_id(), site_id, old_path, id, now]
    )
  end

  defp public_id, do: for(_ <- 1..12, into: "", do: <<Enum.random(@public_id_alphabet)>>)
end
