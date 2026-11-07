defmodule Feather.Content.EmbeddingTest do
  use Feather.DataCase

  import ExUnit.CaptureIO

  alias Feather.Content
  alias Feather.Content.{Embedding, PostVersion}
  alias Feather.Release

  @moduletag :capture_log

  setup do
    previous = Keyword.take(Application.get_all_env(:feather), [:ollama_url, :post_embeddings])
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    Application.put_env(:feather, :post_embeddings, :inline)

    on_exit(fn ->
      Application.delete_env(:feather, :ollama_url)
      Application.delete_env(:feather, :post_embeddings)
      Enum.each(previous, fn {key, value} -> Application.put_env(:feather, key, value) end)
    end)

    %{scope: site_scope_fixture()}
  end

  defp stub_embedding(vector) do
    test = self()

    Req.Test.stub(Feather.Ollama, fn conn ->
      case conn.request_path do
        "/api/embed" ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          send(test, {:embed, Jason.decode!(body)})
          Req.Test.json(conn, %{"embeddings" => [vector]})

        "/api/chat" ->
          Plug.Conn.send_resp(conn, 503, "")
      end
    end)
  end

  defp published_version(post),
    do: Repo.get!(PostVersion, Repo.reload!(post).published_version_id)

  defp decoded(%PostVersion{embedding: embedding}), do: Embedding.decode(embedding)

  defp assert_vector(actual, expected) do
    assert length(actual) == length(expected)
    Enum.zip_with(actual, expected, &assert_in_delta(&1, &2, 1.0e-6))
  end

  describe "publishing a post" do
    test "asks the model for an embedding of the clustering input and stores it on the new version",
         %{scope: scope} do
      stub_embedding([0.6, 0.8, 0.0])

      post =
        post_fixture(scope, %{
          title: "Bikes",
          description: "Why I ride.",
          content: [paragraph("Every day."), paragraph("Rain or shine.")]
        })

      assert_received {:embed, request}

      assert request == %{
               "model" => "embeddinggemma-2:270m",
               "input" => [
                 "task: clustering | query: Bikes. Why I ride.\n\nEvery day.\n\nRain or shine."
               ],
               "truncate" => true
             }

      version = published_version(post)
      assert version.embedding_model == "embeddinggemma-2:270m"
      assert_vector(decoded(version), [0.6, 0.8, 0.0])
    end

    test "asks the configured embedding model", %{scope: scope} do
      Application.put_env(:feather, :ollama_embedding_model, "nomic-embed-text")
      on_exit(fn -> Application.delete_env(:feather, :ollama_embedding_model) end)
      stub_embedding([1.0, 0.0])

      post = post_fixture(scope)

      assert_received {:embed, %{"model" => "nomic-embed-text"}}
      assert published_version(post).embedding_model == "nomic-embed-text"
    end

    test "reads at most 4000 characters of the text", %{scope: scope} do
      stub_embedding([1.0, 0.0])
      post_fixture(scope, %{title: "Long", content: [paragraph(String.duplicate("word ", 2000))]})

      assert_received {:embed, %{"input" => [input]}}
      ["task: clustering | query: Long. ", text] = String.split(input, "\n\n", parts: 2)
      assert String.length(text) in 3_990..4_000
    end

    test "a short post uses its meta title, one without either says none", %{scope: scope} do
      stub_embedding([1.0, 0.0])

      post_fixture(scope, %{
        title: nil,
        meta_title: "Solar",
        slug: "/solar",
        content: [paragraph("Sun.")]
      })

      assert_received {:embed, %{"input" => ["task: clustering | query: Solar. \n\nSun."]}}

      post_fixture(scope, %{title: nil, slug: "/rain", content: [paragraph("Rain.")]})
      assert_received {:embed, %{"input" => ["task: clustering | query: none. \n\nRain."]}}
    end

    test "embeds every new version, but not a version already read", %{scope: scope} do
      stub_embedding([1.0, 0.0])
      post = post_fixture(scope, %{title: "Bikes"})
      assert_received {:embed, _request}

      {:ok, post} = Content.publish(scope, post)
      refute_received {:embed, _request}

      {:ok, post} = Content.update_post(scope, post, %{title: "Bicycles"})
      stub_embedding([0.0, 1.0])
      {:ok, _published} = Content.publish(scope, post)

      assert_received {:embed, %{"input" => ["task: clustering | query: Bicycles. " <> _text]}}
      assert_vector(decoded(published_version(post)), [0.0, 1.0])
    end

    test "succeeds without an embedding when Ollama is not configured", %{scope: scope} do
      Application.delete_env(:feather, :ollama_url)

      version = scope |> post_fixture() |> published_version()

      assert version.embedding == nil
      assert version.embedding_model == nil
    end

    test "succeeds without an embedding when the model fails", %{scope: scope} do
      Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))

      version = scope |> post_fixture() |> published_version()

      assert version.embedding == nil
    end

    test "reads in the background under the task supervisor by default", %{scope: scope} do
      Application.put_env(:feather, :post_embeddings, :background)
      test = self()

      Req.Test.stub(Feather.Ollama, fn conn ->
        send(test, {:asked, self()})
        receive do: (:answer -> Req.Test.json(conn, %{"embeddings" => [[1.0, 0.0]]}))
      end)

      post = post_fixture(scope, %{description: "Set."})

      assert_receive {:asked, task}
      assert task in Task.Supervisor.children(Feather.TaskSupervisor)
      ref = Process.monitor(task)
      send(task, :answer)
      assert_receive {:DOWN, ^ref, :process, ^task, :normal}

      assert_vector(decoded(published_version(post)), [1.0, 0.0])
    end

    test "a post republished by the suggestions backfill is read too", %{scope: scope} do
      Application.delete_env(:feather, :ollama_url)
      post = post_fixture(scope, %{title: "Bikes"})
      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")

      Req.Test.stub(Feather.Ollama, fn conn ->
        case conn.request_path do
          "/api/embed" ->
            Req.Test.json(conn, %{"embeddings" => [[1.0, 0.0]]})

          "/api/chat" ->
            Req.Test.json(conn, %{"message" => %{"content" => ~s({"description": "D."})}})
        end
      end)

      assert [_republished] = Content.backfill_suggestions(scope)

      version = published_version(post)
      assert version.number == 2
      assert_vector(decoded(version), [1.0, 0.0])
    end

    test "a post without plain text gets no embedding", %{scope: scope} do
      stub_embedding([1.0, 0.0])

      version =
        scope |> post_fixture(%{title: "Only a title", content: []}) |> published_version()

      refute_received {:embed, _request}
      assert version.embedding == nil
    end

    test "a page gets no embedding", %{scope: scope} do
      stub_embedding([1.0, 0.0])
      page_fixture(scope)

      refute_received {:embed, _request}
    end
  end

  describe "storing a reading" do
    alias Feather.Publishing

    setup %{scope: scope} do
      Application.delete_env(:feather, :ollama_url)
      %{target: deployment_target_fixture(scope)}
    end

    defp deploy_after(target, post) do
      :ok = Publishing.record_deploy(target, published_version(post).published_at)
    end

    test "of a post published since the last deploy adds no change of its own",
         %{scope: scope, target: target} do
      :ok = Publishing.record_deploy(target, DateTime.utc_now())
      post = post_fixture(scope)
      assert Publishing.undeployed_count(scope) == 1

      put_embedding(post, [1.0, 0.0])

      assert Publishing.undeployed_count(scope) == 1
    end

    test "of a post already deployed counts the site as changed", %{scope: scope, target: target} do
      post = post_fixture(scope)
      deploy_after(target, post)
      assert Publishing.undeployed_count(scope) == 0

      put_embedding(post, [1.0, 0.0])

      assert Publishing.undeployed_count(scope) == 1
    end

    test "of a scheduled post or a version no longer published changes nothing",
         %{scope: scope, target: target} do
      scheduled = post_fixture(scope, %{publish_at: DateTime.add(DateTime.utc_now(), 1, :day)})
      post = post_fixture(scope, %{title: "Bikes"})
      first = published_version(post)
      {:ok, post} = Content.update_post(scope, post, %{title: "Bicycles"})
      {:ok, post} = Content.publish(scope, post)
      deploy_after(target, post)
      assert Publishing.undeployed_count(scope) == 0

      put_embedding(scheduled, [1.0, 0.0])
      :ok = Embedding.store(first, [1.0, 0.0], "embeddinggemma-2:270m")

      assert Publishing.undeployed_count(scope) == 0
    end
  end

  describe "backfill_embeddings/1" do
    setup %{scope: scope} do
      Application.delete_env(:feather, :ollama_url)
      unread = post_fixture(scope, %{title: "Unread"})

      other_model =
        scope |> post_fixture(%{title: "Other model"}) |> put_embedding([0.0, 1.0], "old-model")

      read = scope |> post_fixture(%{title: "Read"}) |> put_embedding([0.0, 1.0])
      draft = post_fixture(scope, %{title: "Draft", draft: true})
      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")

      %{unread: unread, other_model: other_model, read: read, draft: draft}
    end

    test "embeds the published versions without a vector of the configured model and leaves the others alone",
         %{scope: scope} = c do
      stub_embedding([1.0, 0.0])

      assert Content.backfill_embeddings(scope) == 2

      for post <- [c.unread, c.other_model] do
        version = published_version(post)
        assert version.embedding_model == "embeddinggemma-2:270m"
        assert_vector(decoded(version), [1.0, 0.0])
      end

      assert_vector(decoded(published_version(c.read)), [0.0, 1.0])
      assert Repo.aggregate(PostVersion, :count) == 3
    end

    test "publishes nothing again", %{scope: scope} = c do
      stub_embedding([1.0, 0.0])
      before = published_version(c.unread)

      Content.backfill_embeddings(scope)

      after_backfill = published_version(c.unread)
      assert after_backfill.id == before.id
      assert after_backfill.number == 1
      assert Repo.reload!(c.unread).updated_at == c.unread.updated_at
    end

    test "reads only the scope's site", %{scope: scope} do
      Application.delete_env(:feather, :ollama_url)
      elsewhere = post_fixture(site_scope_fixture(), %{title: "Elsewhere"})
      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
      stub_embedding([1.0, 0.0])

      assert Content.backfill_embeddings(scope) == 2
      assert published_version(elsewhere).embedding == nil
    end

    test "leaves out posts without plain text", %{scope: scope} do
      Application.delete_env(:feather, :ollama_url)
      empty = post_fixture(scope, %{title: "Empty", content: []})
      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
      stub_embedding([1.0, 0.0])

      assert Content.backfill_embeddings(scope) == 2
      assert published_version(empty).embedding == nil
    end

    test "counts only the versions the model read", %{scope: scope} do
      Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))

      assert Content.backfill_embeddings(scope) == 0
    end

    test "the release task embeds every site's posts", %{scope: scope} do
      stub_embedding([1.0, 0.0])

      output = capture_io(fn -> assert Release.backfill_embeddings() == :ok end)

      assert output =~ "#{scope.site.domain}: posts read: 2"
    end

    test "the release task refuses without a model" do
      Application.delete_env(:feather, :ollama_url)

      assert capture_io(:stderr, fn ->
               assert Release.backfill_embeddings() == {:error, :not_configured}
             end) =~ "OLLAMA_URL is not set."
    end
  end
end
