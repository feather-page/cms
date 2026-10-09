defmodule Feather.StaticSite.ExportPublishedTest do
  use Feather.DataCase

  alias Feather.{Books, Content}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  # Edits a record without publishing them: its unpublished changes.
  defp change_unpublished(record, changes),
    do: record |> Ecto.Changeset.change(changes) |> Repo.update!()

  setup do
    scope = site_scope_fixture()

    published = post_fixture(scope, %{title: "Published title", slug: "/published"})

    change_unpublished(published, %{
      title: "Changed title",
      slug: "/changed",
      content: [paragraph("Half-finished.")]
    })

    post_fixture(scope, %{title: "Draft", slug: "/draft", draft: true})

    about = page_fixture(scope, %{title: "About", slug: "/about", add_to_navigation: true})
    change_unpublished(about, %{title: "About (changed)"})

    secret = page_fixture(scope, %{title: "Secret", slug: "/secret", add_to_navigation: true})
    change_unpublished(secret, %{published_version_id: nil})

    project = project_fixture(scope, %{title: "Project", slug: "/project"})
    change_unpublished(project, %{title: "Project (changed)"})

    book = book_fixture(scope, %{title: "Dune", author: "F. Herbert", read_at: ~D[2025-02-01]})

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{title: "Review", slug: "/dune", content: []})

    {:ok, review} = Content.publish(scope, review)

    change_unpublished(review, %{slug: "/dune-changed"})
    page_fixture(scope, %{title: "Books", slug: "/books", page_type: "books"})

    %{scope: scope}
  end

  defp export(scope, opts) do
    sink = RecordingSink.new(start_supervised!({RecordingSink, []}, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink, opts)
    sink
  end

  test "production shows the published versions only", %{scope: scope} do
    sink = export(scope, content: :published)
    paths = RecordingSink.paths(sink)

    assert RecordingSink.get(sink, "published/index.html") =~ "<h1>Published title</h1>"
    refute "changed/index.html" in paths
    refute "draft/index.html" in paths
    refute "secret/index.html" in paths
    assert RecordingSink.get(sink, "about/index.html") =~ "<h1>About</h1>"
    assert RecordingSink.get(sink, "projects/project/index.html") =~ "<h1>Project</h1>"

    home = RecordingSink.get(sink, "index.html")
    assert home =~ "Published title"
    refute home =~ "Changed title"
    assert home =~ ">About</a>"
    refute home =~ "About (changed)"
    refute home =~ "Secret"

    assert RecordingSink.get(sink, "books/index.html") =~ ~s(href="/dune/")
    refute RecordingSink.get(sink, "feed.xml") =~ "Changed title"
  end

  test "is the default", %{scope: scope} do
    paths = scope |> export([]) |> RecordingSink.paths()

    assert "published/index.html" in paths
    refute "changed/index.html" in paths
  end

  test "an unpublished post is a draft and missing from production, its changes kept",
       %{scope: scope} do
    post = Enum.find(Content.list_posts(scope), &(&1.title == "Changed title"))
    {:ok, _post} = Content.unpublish(scope, post)

    paths = RecordingSink.paths(export(scope, content: :published))
    refute "published/index.html" in paths
    refute "changed/index.html" in paths

    assert RecordingSink.get(export(scope, content: :current), "changed/index.html") =~
             "Half-finished."
  end

  test "production copies only the images of the published versions", %{scope: scope} do
    image_paths = fn sink ->
      sink
      |> RecordingSink.paths()
      |> Enum.flat_map(&(Regex.run(~r{\Aimages/([^/]+)/}, &1, capture: :all_but_first) || []))
      |> MapSet.new()
    end

    [published_header, published_block, draft_header, draft_block] =
      for _ <- 1..4, do: image_fixture(scope)

    [changed_header, changed_block] = for _ <- 1..2, do: image_fixture(scope)

    post =
      post_fixture(scope, %{
        title: "With images",
        slug: "/with-images",
        header_image_id: published_header.id,
        content: [image_block(published_block)]
      })

    change_unpublished(post, %{
      header_image_id: changed_header.id,
      content: [image_block(changed_block)]
    })

    draft =
      post_fixture(scope, %{
        title: "Draft with images",
        slug: "/draft-with-images",
        header_image_id: draft_header.id,
        content: [image_block(draft_block)],
        draft: true
      })

    for image <- [draft_block, changed_block],
        do: image |> Ecto.Changeset.change(post_id: draft.id) |> Repo.update!()

    production = image_paths.(export(scope, content: :published))

    assert MapSet.equal?(
             production,
             MapSet.new([published_header.public_id, published_block.public_id])
           )

    staging = image_paths.(export(scope, content: :current))

    for image <- [draft_header, draft_block, changed_header, changed_block],
        do: assert(image.public_id in staging)
  end

  test "staging shows the records as they are, drafts included", %{scope: scope} do
    sink = export(scope, content: :current)
    paths = RecordingSink.paths(sink)

    assert RecordingSink.get(sink, "changed/index.html") =~ "Half-finished."
    refute "published/index.html" in paths
    assert RecordingSink.get(sink, "draft/index.html") =~ "<h1>Draft</h1>"
    assert RecordingSink.get(sink, "secret/index.html") =~ "<h1>Secret</h1>"

    home = RecordingSink.get(sink, "index.html")
    assert home =~ "Changed title"
    assert home =~ "About (changed)"
    assert home =~ "Secret"
    assert RecordingSink.get(sink, "books/index.html") =~ ~s(href="/dune-changed/")
  end
end
