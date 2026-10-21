defmodule Feather.Content.ShortPostTest do
  use Feather.DataCase

  alias Feather.Content
  alias Feather.Content.ShortPost
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @moduletag :capture_log

  setup do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    %{scope: site_scope_fixture(%{title: "Site", language_code: "de"})}
  end

  # Answers the short post title request with `title` and `slug`, every other one with a description.
  defp stub_model(title, slug) do
    test = self()

    Req.Test.stub(Feather.Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"format" => %{"required" => required}} = Jason.decode!(body)
      send(test, {:model_asked, required})

      answer =
        if "slug" in required,
          do: %{"title" => title, "slug" => slug},
          else: %{"description" => "A description."}

      Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
    end)
  end

  defp short_post(scope, attrs \\ %{}) do
    post_fixture(
      scope,
      Map.merge(
        %{
          title: nil,
          slug: nil,
          content: [paragraph("Mein E-Ink-Display zeigt jetzt den Solarertrag.")],
          draft: true
        },
        attrs
      )
    )
  end

  defp export(scope) do
    sink = RecordingSink.new(start_supervised!({RecordingSink, []}, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink
  end

  defp meta(doc, key) do
    case Floki.attribute(doc, ~s(meta[property="#{key}"]), "content") do
      [value] -> value
      [] -> nil
    end
  end

  test "the first publish stores slug and meta title, which the export and the feed use",
       %{scope: scope} do
    stub_model("E-Ink-Solar-Dashboard", "e-ink-solar-dashboard")

    {:ok, post} = Content.publish(scope, short_post(scope))

    stored = Repo.reload!(post)
    assert stored.slug == "/e-ink-solar-dashboard"
    assert stored.meta_title == "E-Ink-Solar-Dashboard"
    assert stored.title == nil
    assert stored.lock_version == post.lock_version

    version = Repo.preload(stored, :published_version).published_version
    assert version.slug == "/e-ink-solar-dashboard"
    assert version.meta_title == "E-Ink-Solar-Dashboard"

    sink = export(scope)
    doc = sink |> RecordingSink.get("e-ink-solar-dashboard/index.html") |> Floki.parse_document!()
    assert Floki.text(Floki.find(doc, "title")) =~ "E-Ink-Solar-Dashboard"
    assert meta(doc, "og:title") == "E-Ink-Solar-Dashboard"
    refute doc |> Floki.find("body") |> Floki.text() =~ "E-Ink-Solar-Dashboard"

    feed = sink |> RecordingSink.get("feed.xml") |> IO.iodata_to_binary()
    assert feed =~ "<title>E-Ink-Solar-Dashboard</title>"
  end

  test "asks the model in the site's language with the post's text", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"messages" => [%{"content" => prompt}], "format" => format} = Jason.decode!(body)

      answer =
        if "slug" in format["required"] do
          assert prompt =~ "German"
          assert prompt =~ "Mein E-Ink-Display zeigt jetzt den Solarertrag."
          %{"title" => "Solarertrag", "slug" => "solarertrag"}
        else
          %{"description" => "Kurz."}
        end

      Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
    end)

    assert {:ok, %{slug: "/solarertrag", meta_title: "Solarertrag"}} =
             Content.publish(scope, short_post(scope))
  end

  test "a short post keeps its URL", %{scope: scope} do
    stub_model("E-Ink-Solar-Dashboard", "e-ink-solar-dashboard")
    {:ok, post} = Content.publish(scope, short_post(scope))
    assert_received {:model_asked, ["title", "slug"]}

    {:ok, post} =
      Content.update_post(scope, Repo.reload!(post), %{content: [paragraph("Now with a graph.")]})

    stub_model("Another title", "another-slug")
    {:ok, post} = Content.publish(scope, post)

    stored = Repo.reload!(post)
    assert stored.slug == "/e-ink-solar-dashboard"
    assert stored.meta_title == "E-Ink-Solar-Dashboard"
    refute_received {:model_asked, ["title", "slug"]}
  end

  test "keeps a meta title a member typed and still gets a slug", %{scope: scope} do
    stub_model("Model title", "model-slug")

    {:ok, post} = Content.publish(scope, short_post(scope, %{meta_title: "Mine"}))

    assert %{meta_title: "Mine", slug: "/model-slug"} = Repo.reload!(post)
    assert Repo.preload(post, :published_version).published_version.meta_title == "Mine"
  end

  test "takes a free slug", %{scope: scope} do
    stub_model("E-Ink-Solar-Dashboard", "e-ink-solar-dashboard")
    post_fixture(scope, %{title: "Taken", slug: "/e-ink-solar-dashboard"})

    {:ok, post} = Content.publish(scope, short_post(scope))

    assert post.slug == "/e-ink-solar-dashboard1"
  end

  test "makes the slug from the title when the model's slug is unusable", %{scope: scope} do
    stub_model("Solar dashboard", "!!!")

    {:ok, post} = Content.publish(scope, short_post(scope))

    assert post.slug == "/solar-dashboard"
  end

  test "without an answer the short post is published without slug and meta title",
       %{scope: scope} do
    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))

    {:ok, post} = Content.publish(scope, short_post(scope))

    assert %{slug: nil, meta_title: nil} = Repo.reload!(post)
    assert Content.publication_status(post) == :published

    assert export(scope) |> RecordingSink.get("feed.xml") |> IO.iodata_to_binary() =~
             "<title>Post</title>"
  end

  test "posts with a title or a slug, and later publishes, get no meta title", %{scope: scope} do
    stub_model("Generated", "generated")

    {:ok, titled} = Content.publish(scope, short_post(scope, %{title: "Mine"}))
    {:ok, slugged} = Content.publish(scope, short_post(scope, %{slug: "/mine"}))

    {:ok, published} = Content.publish(scope, short_post(scope))
    {:ok, unpublished} = Content.unpublish(scope, Repo.reload!(published))
    {:ok, cleared} = Content.update_post(scope, unpublished, %{slug: ""})
    {:ok, republished} = Content.publish(scope, cleared)

    assert %{meta_title: nil, slug: nil} = titled
    assert %{meta_title: nil, slug: "/mine"} = slugged
    assert %{slug: nil} = Repo.reload!(republished)
  end

  test "saving with draft: false generates them, as the content API does", %{scope: scope} do
    stub_model("Über die API", "ueber-die-api")

    {:ok, post} =
      Content.create_post(scope, %{content: [paragraph("Sent over the API.")]}, draft: false)

    assert %{slug: "/ueber-die-api", meta_title: "Über die API"} = Repo.reload!(post)
    assert Content.publication_status(Repo.reload!(post)) == :published
  end

  describe "generate/2" do
    test "shortens a long slug at a dash" do
      Req.Test.stub(Feather.Ollama, fn conn ->
        answer = %{"title" => "Long", "slug" => String.duplicate("word-", 20)}
        Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
      end)

      post = %Content.Post{content: [paragraph("Text.")]}
      assert {:ok, %{slug: slug}} = ShortPost.generate(post, "en")

      assert String.length(slug) <= 60
      assert slug =~ ~r/\Aword(-word)*\z/
    end

    test "fails for a post without text" do
      assert {:error, :no_text} = ShortPost.generate(%Content.Post{content: []}, "en")
    end

    test "a post of only a book asks about the book" do
      Req.Test.stub(Feather.Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        %{"messages" => [%{"content" => prompt}]} = Jason.decode!(body)
        assert prompt =~ "Book: The Passage by Justin Cronin"

        answer = %{"title" => "The Passage", "slug" => "the-passage"}
        Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
      end)

      book = %{"type" => "book", "title" => "The Passage", "author" => "Justin Cronin"}
      post = %Content.Post{content: [book]}
      assert {:ok, %{meta_title: "The Passage"}} = ShortPost.generate(post, "en")
    end
  end
end
