defmodule Feather.Content.RelatedPostsTest do
  use ExUnit.Case, async: true

  alias Feather.Content.{Embedding, Post, PostVersion, RelatedPosts}

  @model "embeddinggemma-2:270m"
  @size 40

  # Its cosine to `a/1` is `cosine`; dimension `k` keeps it apart from the others.
  defp similar(cosine, k) do
    for i <- 0..(@size - 1) do
      cond do
        i == 0 -> cosine
        i == k -> :math.sqrt(1 - cosine * cosine)
        true -> 0.0
      end
    end
  end

  defp post(id, vector, opts \\ []) do
    publish_at = opts[:publish_at] || ~U[2026-11-01 12:00:00Z]

    %Post{
      id: id,
      tags: Keyword.get(opts, :current_tags, opts[:tags]),
      publish_at: publish_at,
      published_version: %PostVersion{
        tags: opts[:tags],
        publish_at: publish_at,
        embedding: vector && Embedding.encode(normalise(vector)),
        embedding_model: Keyword.get(opts, :model, @model)
      }
    }
  end

  defp normalise(vector) do
    length = :math.sqrt(Enum.reduce(vector, 0.0, &(&1 * &1 + &2)))
    Enum.map(vector, &(&1 / length))
  end

  defp a(opts \\ []), do: post("a", similar(1.0, 0), opts)

  defp at(id, cosine, k, opts \\ []), do: post(id, similar(cosine, k), opts)

  defp fillers(count, opts \\ []),
    do: for(n <- 1..count, do: at("filler#{n}", 0.0, 30 + rem(n, 9), opts))

  defp of(posts, post), do: RelatedPosts.of(posts, post, @model, 3)

  test "lists the three posts closest in content, closest first" do
    posts = [
      a(),
      at("far", 0.1, 1),
      at("near", 0.9, 2),
      at("nearer", 0.95, 3),
      at("middle", 0.5, 4),
      at("opposite", -0.9, 5)
    ]

    assert of(posts, a()) == ["nearer", "near", "middle"]
  end

  test "keeps the given number of the best" do
    posts = [a(), at("near", 0.9, 1), at("far", 0.5, 2)]

    assert RelatedPosts.of(posts, a(), @model, 1) == ["near"]
    assert RelatedPosts.all(posts, @model, 1)["a"] == ["near"]
  end

  test "lists dissimilar posts too when there are no better ones" do
    posts = [a(), at("orthogonal", 0.0, 1), at("opposite", -1.0, 2)]

    assert of(posts, a()) == ["orthogonal", "opposite"]
  end

  test "adds 0.06 for a shared tag" do
    a = a(tags: "bikes")

    tagged = at("tagged", 0.80, 1, tags: "bikes")
    posts = [a, tagged, at("above", 0.87, 2), at("below", 0.85, 3) | fillers(12)]

    assert of(posts, a) == ["above", "tagged", "below"]
  end

  test "adds at most 0.12 for shared tags" do
    a = a(tags: "bikes, rain, tea")

    tagged = at("tagged", 0.80, 1, tags: "bikes, rain, tea")
    posts = [a, tagged, at("above", 0.93, 2), at("below", 0.91, 3) | fillers(12)]

    assert of(posts, a) == ["above", "tagged", "below"]
  end

  test "a tag counts while at most three posts or a fifth of the posts carry it" do
    a = a(tags: "three, four")
    b = at("b", 0.80, 1, tags: "three, four")
    others = [at("c", 0.0, 2, tags: "three, four"), at("d", 0.0, 3, tags: "four")]
    rivals = [at("above", 0.865, 4), at("below", 0.855, 5)]

    assert of([a, b | others] ++ rivals ++ fillers(4), a) == ["above", "b", "below"]
    assert of([a, b | others] ++ rivals ++ fillers(14), a) == ["b", "above", "below"]
  end

  test "counts the tags of the published versions, not the unpublished ones" do
    a = a(current_tags: "bikes")
    posts = [a, at("tagged", 0.80, 1, tags: "bikes"), at("plain", 0.84, 2)]

    assert of(posts, a) == ["plain", "tagged"]
  end

  test "drafts carry no tags that count" do
    a = a(tags: "bikes")
    drafts = for n <- 1..3, do: %Post{id: "draft#{n}", tags: "bikes", published_version: nil}
    posts = [a, at("tagged", 0.80, 1, tags: "bikes"), at("plain", 0.85, 2) | drafts]

    assert of(posts, a) == ["tagged", "plain"]
  end

  test "on equal scores the post closer in date wins" do
    a = a(publish_at: ~U[2026-06-01 12:00:00Z])

    posts = [
      post("newer", similar(0.8, 1), publish_at: ~U[2026-06-20 12:00:00Z]),
      a,
      post("older", similar(0.8, 1), publish_at: ~U[2026-05-20 12:00:00Z]),
      post("oldest", similar(0.8, 1), publish_at: ~U[2025-01-01 12:00:00Z]),
      post("newest", similar(0.8, 1), publish_at: ~U[2026-10-01 12:00:00Z])
    ]

    assert of(posts, a) == ["older", "newer", "newest"]
  end

  test "posts without a vector of the model take no part on either side" do
    unread = post("unread", nil)
    other_model = at("other model", 1.0, 1, model: "old-model")
    draft = %Post{id: "draft", published_version: nil}
    read = at("read", 0.9, 2)
    posts = [a(), unread, other_model, draft, read]

    assert of(posts, a()) == ["read"]
    assert of(posts, read) == ["a"]
    assert of(posts, unread) == []
    assert of(posts, other_model) == []
    assert of(posts, draft) == []
    assert of(posts, post("elsewhere", similar(1.0, 0))) == []
  end

  test "all/3 lists for every post with a vector what of/4 lists for it" do
    posts =
      [
        a(tags: "bikes"),
        at("b", 0.9, 1, tags: "bikes"),
        at("c", 0.7, 2),
        at("d", 0.7, 3, publish_at: ~U[2026-01-01 12:00:00Z]),
        at("e", 0.2, 4, tags: "bikes"),
        post("unread", nil)
      ] ++ fillers(3)

    all = RelatedPosts.all(posts, @model, 3)

    assert Enum.sort(Map.keys(all)) ==
             posts |> Enum.map(& &1.id) |> List.delete("unread") |> Enum.sort()

    for post <- posts, post.id != "unread", do: assert(all[post.id] == of(posts, post))
  end
end
