defmodule Feather.Content.DescriptionTest do
  use Feather.DataCase

  alias Feather.Content
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @moduletag :capture_log

  setup do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    %{scope: site_scope_fixture(%{title: "Site", language_code: "de"})}
  end

  defp stub_description(description) do
    test = self()

    Req.Test.stub(Feather.Ollama, fn conn ->
      send(test, :model_asked)
      content = Jason.encode!(%{"description" => description})
      Req.Test.json(conn, %{"message" => %{"content" => content}})
    end)
  end

  defp stub_no_call do
    Req.Test.stub(Feather.Ollama, fn _conn -> flunk("the model must not be asked") end)
  end

  defp draft_post(scope, attrs \\ %{}) do
    post_fixture(
      scope,
      Map.merge(
        %{
          title: "Lighthouses",
          slug: "/lighthouses",
          content: [paragraph("Lighthouses guide ships along the coast.")],
          draft: true
        },
        attrs
      )
    )
  end

  defp export_doc(scope, path) do
    sink = RecordingSink.new(start_supervised!({RecordingSink, []}, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink |> RecordingSink.get(path) |> Floki.parse_document!()
  end

  defp meta(doc, key) do
    case Floki.attribute(doc, ~s(meta[name="#{key}"], meta[property="#{key}"]), "content") do
      [value] -> value
      [] -> nil
    end
  end

  defp change_content(scope, post, text) do
    {:ok, post} = Content.update_post(scope, post, %{content: [paragraph(text)]})
    post
  end

  test "publishing stores a generated description, which the export uses", %{scope: scope} do
    stub_description("  Wie Leuchttürme Schiffe sicher leiten.  ")

    {:ok, post} = Content.publish(scope, draft_post(scope))

    stored = Repo.reload!(post)
    assert stored.description == "Wie Leuchttürme Schiffe sicher leiten."
    assert stored.description_generated
    assert Content.publication_status(stored) == :published
    assert stored.lock_version == post.lock_version

    version = Repo.preload(stored, :published_version).published_version
    assert version.description == "Wie Leuchttürme Schiffe sicher leiten."
    assert version.description_generated

    doc = export_doc(scope, "lighthouses/index.html")
    assert meta(doc, "description") == "Wie Leuchttürme Schiffe sicher leiten."
    assert meta(doc, "og:description") == "Wie Leuchttürme Schiffe sicher leiten."
  end

  test "asks the model in the site's language and the author's voice", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"messages" => [%{"content" => prompt}], "format" => format} = Jason.decode!(body)

      assert prompt =~ "German"
      assert prompt =~ "Lighthouses"
      assert prompt =~ "Lighthouses guide ships along the coast."
      assert prompt =~ "first person"
      assert prompt =~ ~s("Explore")
      assert prompt =~ "Never invent"
      assert format["required"] == ["description"]

      Req.Test.json(conn, %{"message" => %{"content" => ~s({"description": "Leuchttürme"})}})
    end)

    assert {:ok, %{description: "Leuchttürme"}} = Content.publish(scope, draft_post(scope))
  end

  test "the model reads the books and quote sources of the content", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"messages" => [%{"content" => prompt}]} = Jason.decode!(body)

      assert prompt =~ "Book: The Passage by Justin Cronin"
      assert prompt =~ ~s(Quote: "Light the way." \(Fresnel\))

      Req.Test.json(conn, %{"message" => %{"content" => ~s({"description": "Gelesen"})}})
    end)

    content = [
      %{"type" => "paragraph", "text" => "Finished reading:"},
      %{"type" => "book", "title" => "The Passage", "author" => "Justin Cronin"},
      %{"type" => "quote", "text" => "Light the way.", "caption" => "Fresnel"}
    ]

    assert {:ok, %{description: "Gelesen"}} =
             Content.publish(scope, draft_post(scope, %{content: content}))
  end

  test "a generated description follows the content", %{scope: scope} do
    stub_description("First summary.")
    {:ok, post} = Content.publish(scope, draft_post(scope))

    post = change_content(scope, Repo.reload!(post), "Lighthouses now run on solar power.")
    stub_description("Second summary.")
    {:ok, post} = Content.publish(scope, post)

    assert Repo.reload!(post).description == "Second summary."
    assert Repo.reload!(post).description_generated
  end

  test "an overwritten description stays", %{scope: scope} do
    stub_description("Generated summary.")
    {:ok, post} = Content.publish(scope, draft_post(scope))

    {:ok, post} = Content.update_post(scope, Repo.reload!(post), %{description: " Mine. "})
    assert post.description == "Mine."
    refute post.description_generated

    post = change_content(scope, post, "Lighthouses now run on solar power.")
    stub_no_call()
    {:ok, post} = Content.publish(scope, post)

    assert Repo.reload!(post).description == "Mine."

    assert Repo.preload(Repo.reload!(post), :published_version).published_version.description ==
             "Mine."
  end

  test "a generated description stays while title and content do", %{scope: scope} do
    stub_description("Generated summary.")
    {:ok, post} = Content.publish(scope, draft_post(scope))

    {:ok, post} = Content.update_post(scope, Repo.reload!(post), %{tags: "sea"})
    stub_no_call()
    {:ok, post} = Content.publish(scope, post)

    assert Repo.reload!(post).description == "Generated summary."
  end

  test "publishing does not wait for a model that does not answer", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :timeout))

    assert {:ok, post} = Content.publish(scope, draft_post(scope))

    stored = Repo.reload!(post)
    assert stored.description == nil
    refute Content.draft?(stored)

    doc = export_doc(scope, "lighthouses/index.html")
    assert meta(doc, "description") == "Lighthouses guide ships along the coast."
  end

  test "without a configured model nothing is asked", %{scope: scope} do
    Application.put_env(:feather, :ollama_url, nil)
    stub_no_call()

    assert {:ok, post} = Content.publish(scope, draft_post(scope))
    assert Repo.reload!(post).description == nil
  end

  test "publishing a published post without changes asks nothing", %{scope: scope} do
    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))
    {:ok, post} = Content.publish(scope, draft_post(scope))

    stub_no_call()
    assert {:ok, _post} = Content.publish(scope, Repo.reload!(post))
  end

  test "saving with draft: false generates the description, as the content API does",
       %{scope: scope} do
    stub_description("API summary.")

    {:ok, post} =
      Content.create_post(
        scope,
        %{title: "Via API", content: [paragraph("Sent over the API.")]},
        draft: false
      )

    assert_received :model_asked
    stored = Repo.reload!(post)
    assert stored.description == "API summary."
    assert stored.description_generated
    assert Content.publication_status(stored) == :published
  end

  test "pages get descriptions too, projects keep their short description", %{scope: scope} do
    stub_description("About the author.")

    page = page_fixture(scope, %{title: "About", slug: "/about", content: [paragraph("Me.")]})
    assert Repo.reload!(page).description == "About the author."

    stub_no_call()
    project_fixture(scope, %{title: "Boat", content: [paragraph("A boat.")]})
  end

  test "suggest_description/2 asks the model, put_suggested_description/3 stores it flagged",
       %{scope: scope} do
    post = draft_post(scope, %{description: "Mine."})
    stub_description("Suggested.")

    assert {:ok, "Suggested."} = Content.suggest_description(scope, post)
    assert {:ok, saved} = Content.put_suggested_description(scope, post, "Suggested.")
    assert saved.description == "Suggested."
    assert saved.description_generated
    assert saved.lock_version == post.lock_version + 1

    assert {:error, :stale} = Content.put_suggested_description(scope, post, "Again.")
  end

  test "suggest_description/2 fails for a record without text", %{scope: scope} do
    stub_no_call()
    post = draft_post(scope, %{content: []})

    assert {:error, :no_text} = Content.suggest_description(scope, post)
  end
end
