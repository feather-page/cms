defmodule Feather.OllamaTest do
  use ExUnit.Case, async: false

  alias Feather.Ollama

  setup do
    previous = Keyword.take(Application.get_all_env(:feather), [:ollama_url, :ollama_model])
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")

    on_exit(fn ->
      Application.delete_env(:feather, :ollama_url)
      Application.delete_env(:feather, :ollama_model)
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
end
