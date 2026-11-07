defmodule Feather.OllamaTest do
  use ExUnit.Case, async: false

  alias Feather.Ollama

  setup do
    previous =
      Keyword.take(Application.get_all_env(:feather), [
        :ollama_url,
        :ollama_model,
        :ollama_embedding_model
      ])

    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")

    on_exit(fn ->
      Application.delete_env(:feather, :ollama_url)
      Application.delete_env(:feather, :ollama_model)
      Application.delete_env(:feather, :ollama_embedding_model)
      Enum.each(previous, fn {key, value} -> Application.put_env(:feather, key, value) end)
    end)
  end

  defp stub_answer(test) do
    Req.Test.stub(Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:request, Jason.decode!(body)})
      Req.Test.json(conn, %{"message" => %{"content" => ~s({"alt": "A lighthouse."})}})
    end)
  end

  test "asks the configured model without thinking, at temperature 0" do
    Application.put_env(:feather, :ollama_model, "gemma4:e4b")
    stub_answer(self())

    assert {:ok, "A lighthouse."} = Ollama.alt_text("jpeg", "en")

    assert_received {:request, request}
    assert request["model"] == "gemma4:e4b"
    assert request["think"] == false
    assert request["options"] == %{"temperature" => 0}
  end

  test "asks Gemma 4 26B without a configured model" do
    stub_answer(self())

    assert {:ok, _alt} = Ollama.alt_text("jpeg", "en")
    assert_received {:request, %{"model" => "gemma4:26b-a4b-it-qat"}}
  end

  test "an empty model setting counts as none" do
    Application.put_env(:feather, :ollama_model, "")
    stub_answer(self())

    assert {:ok, _alt} = Ollama.alt_text("jpeg", "en")
    assert_received {:request, %{"model" => "gemma4:26b-a4b-it-qat"}}
  end

  describe "embedding/1" do
    defp stub_embedding(test, response) do
      Req.Test.stub(Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test, {:request, conn.method, conn.request_path, Jason.decode!(body)})
        Req.Test.json(conn, response)
      end)
    end

    test "posts the text to the embed API of EmbeddingGemma 2, truncated to the model's window" do
      stub_embedding(self(), %{"embeddings" => [[0.6, 0.8]]})

      assert Ollama.embedding("task: clustering | query: Bikes.") == {:ok, [0.6, 0.8]}

      assert_received {:request, "POST", "/api/embed", request}

      assert request == %{
               "model" => "embeddinggemma-2:270m",
               "input" => ["task: clustering | query: Bikes."],
               "truncate" => true
             }
    end

    test "asks the configured embedding model, an empty setting counts as none" do
      Application.put_env(:feather, :ollama_embedding_model, "nomic-embed-text")
      stub_embedding(self(), %{"embeddings" => [[1.0]]})
      assert {:ok, _vector} = Ollama.embedding("text")
      assert_received {:request, _method, _path, %{"model" => "nomic-embed-text"}}

      Application.put_env(:feather, :ollama_embedding_model, "")
      assert {:ok, _vector} = Ollama.embedding("text")
      assert_received {:request, _method, _path, %{"model" => "embeddinggemma-2:270m"}}
    end

    @tag :capture_log
    test "an answer without a vector of numbers is an error" do
      for response <- [
            %{"embeddings" => []},
            %{"embeddings" => [[]]},
            %{"embeddings" => [["a"]]},
            %{"error" => "no model"}
          ] do
        stub_embedding(self(), response)
        assert {:error, _reason} = Ollama.embedding("text")
      end
    end

    @tag :capture_log
    test "a failing model is an error with its status" do
      Req.Test.stub(Ollama, &Plug.Conn.send_resp(&1, 503, ""))

      assert Ollama.embedding("text") == {:error, {:status, 503}}
    end

    test "without a URL nothing is asked" do
      Application.delete_env(:feather, :ollama_url)

      assert Ollama.embedding("text") == {:error, :not_configured}
    end
  end
end
