defmodule Feather.Content.RelatedPosts do
  @moduledoc """
  Ranks a site's posts as related posts of each other (ADR 0036): the
  other posts closest in content by the cosine similarity of their published
  versions' embeddings (`Feather.Content.Embedding`), plus 0.06 per
  shared tag, at most 0.12. A tag counts only while at most three posts
  or at most a fifth of the due posts handed in carry it, whichever is more,
  so tags on many posts add nothing. On equal scores the post closer in
  publish date wins. Posts without a vector of the model take no part on
  either side.

  Everything comes from the published versions (preloaded): their
  vectors, tags and publish dates. The preview ranks the same published
  versions, but among the posts it shows, so drafts and changed publish
  dates can change its list. `all/3` compares every pair once
  (the export), `of/4` one post with all others (the preview); both keep
  the `limit` best.
  """

  alias Feather.Content.{Embedding, Post, PostVersion, Tags}

  @tag_bonus 0.06
  @max_tag_bonus 0.12
  @min_tag_limit 3

  @doc "The ids of the `limit` best related posts of each post with a vector, best first, by post id."
  @spec all([Post.t()], String.t(), pos_integer()) :: %{Ecto.UUID.t() => [Ecto.UUID.t()]}
  def all(posts, model, limit) do
    readings = readings(posts, model)
    scored = readings |> Map.values() |> pair_scores(%{})

    Map.new(readings, fn {id, reading} ->
      {id, best(reading, Map.get(scored, id, []), limit)}
    end)
  end

  @doc "The ids of the `limit` best related posts of one of the posts, best first; none without a vector."
  @spec of([Post.t()], Post.t(), String.t(), pos_integer()) :: [Ecto.UUID.t()]
  def of(posts, %Post{id: id}, model, limit) do
    case Map.pop(readings(posts, model), id) do
      {nil, _readings} ->
        []

      {reading, others} ->
        best(reading, Enum.map(Map.values(others), &{&1, score(reading, &1)}), limit)
    end
  end

  defp readings(posts, model) do
    versions = for %Post{published_version: %PostVersion{} = v} = post <- posts, do: {post.id, v}
    counting = counting_tags(versions)

    for {id, %PostVersion{embedding: embedding, embedding_model: ^model} = version} <- versions,
        is_binary(embedding),
        into: %{} do
      {id,
       %{
         id: id,
         vector: Embedding.decode(embedding),
         tags: version |> Tags.tag_list() |> MapSet.new() |> MapSet.intersection(counting),
         publish_at: version.publish_at
       }}
    end
  end

  defp counting_tags(versions) do
    limit = max(@min_tag_limit, length(versions) / 5)

    for {tag, count} <-
          versions |> Enum.flat_map(fn {_id, v} -> Tags.tag_list(v) end) |> Enum.frequencies(),
        count <= limit,
        into: MapSet.new(),
        do: tag
  end

  defp pair_scores([], scored), do: scored

  defp pair_scores([reading | rest], scored) do
    scored =
      Enum.reduce(rest, scored, fn other, scored ->
        score = score(reading, other)

        scored
        |> Map.update(reading.id, [{other, score}], &[{other, score} | &1])
        |> Map.update(other.id, [{reading, score}], &[{reading, score} | &1])
      end)

    pair_scores(rest, scored)
  end

  defp best(reading, scored_others, limit) do
    scored_others
    |> Enum.sort_by(fn {other, score} -> {-score, date_distance(reading, other), other.id} end)
    |> Enum.take(limit)
    |> Enum.map(fn {other, _score} -> other.id end)
  end

  defp score(reading, other),
    do: dot(reading.vector, other.vector, 0.0) + tag_bonus(reading.tags, other.tags)

  defp dot([x | xs], [y | ys], sum), do: dot(xs, ys, sum + x * y)
  defp dot(_rest, _other_rest, sum), do: sum

  defp tag_bonus(tags, other_tags) do
    shared = tags |> MapSet.intersection(other_tags) |> MapSet.size()
    min(@tag_bonus * shared, @max_tag_bonus)
  end

  defp date_distance(%{publish_at: %DateTime{} = a}, %{publish_at: %DateTime{} = b}),
    do: abs(DateTime.diff(a, b))

  defp date_distance(_reading, _other), do: :undated
end
