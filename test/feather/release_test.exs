defmodule Feather.ReleaseTest do
  use Feather.DataCase

  import ExUnit.CaptureIO

  alias Feather.Content.PostVersion
  alias Feather.Release

  describe "set_target_config/2" do
    test "replaces the config of the target of the site with the domain" do
      scope = site_scope_fixture()
      target = deployment_target_fixture(scope, config: %{})
      config = %{"host" => "ftp.example.com", "user" => "u2", "password" => "new", "path" => "/"}

      output =
        capture_io(fn ->
          domain = "https://" <> String.upcase(scope.site.domain)
          assert {:ok, _} = Release.set_target_config(domain, config)
        end)

      assert output =~ "Config of #{scope.site.domain} (ftps) set."
      assert Repo.reload!(target).config == config
    end

    test "reports a domain without a target" do
      scope = site_scope_fixture()

      for domain <- ["unknown.example.com", scope.site.domain] do
        assert capture_io(:stderr, fn ->
                 assert Release.set_target_config(domain, %{}) == {:error, :not_found}
               end) =~ "No deployment target for #{domain}."
      end
    end
  end

  describe "backfill_suggestions/0" do
    setup do
      previous = Keyword.take(Application.get_all_env(:feather), [:ollama_url, :post_embeddings])

      on_exit(fn ->
        Application.delete_env(:feather, :ollama_url)
        Application.delete_env(:feather, :post_embeddings)
        Enum.each(previous, fn {key, value} -> Application.put_env(:feather, key, value) end)
      end)
    end

    defp stub_model(test) do
      Req.Test.stub(Feather.Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case conn.request_path do
          "/api/embed" ->
            send(test, {:embedded_in, self()})
            Req.Test.json(conn, %{"embeddings" => [[1.0, 0.0]]})

          "/api/chat" ->
            answer = chat_answer(Jason.decode!(body)["format"]["required"])
            Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
        end
      end)
    end

    defp chat_answer(["alt"]), do: %{"alt" => "Grau"}
    defp chat_answer(["description"]), do: %{"description" => "Solar."}
    defp chat_answer(["title", "slug"]), do: %{"title" => "Solar", "slug" => "solar"}

    @tag :capture_log
    test "fills in alt texts and republishes short posts of every site" do
      Application.delete_env(:feather, :ollama_url)
      scope = site_scope_fixture(%{language_code: "de"})
      image = image_fixture(scope)
      post = post_fixture(scope, %{title: nil, slug: nil, content: [paragraph("Solar.")]})

      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")

      stub_model(self())

      output = capture_io(fn -> assert Release.backfill_suggestions() == :ok end)

      assert output =~ "#{scope.site.domain}: alt texts filled in: 1, records published again: 1"
      assert Repo.reload!(image).alt == "Grau"
      assert Repo.reload!(post).slug == "/solar"
    end

    @tag :capture_log
    test "reads the republished posts before it returns, as a release runs no background tasks" do
      Application.delete_env(:feather, :ollama_url)
      scope = site_scope_fixture()
      post = post_fixture(scope, %{title: nil, slug: nil, content: [paragraph("Solar.")]})
      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
      Application.put_env(:feather, :post_embeddings, :background)
      stub_model(self())

      capture_io(fn -> assert Release.backfill_suggestions() == :ok end)

      assert_received {:embedded_in, pid}
      assert pid == self()
      version = Repo.get!(PostVersion, Repo.reload!(post).published_version_id)
      assert version.embedding_model == "embeddinggemma-2:270m"
      assert Application.get_env(:feather, :post_embeddings) == :background
    end

    test "refuses without a model" do
      Application.delete_env(:feather, :ollama_url)

      assert capture_io(:stderr, fn ->
               assert Release.backfill_suggestions() == {:error, :not_configured}
             end) =~ "OLLAMA_URL is not set."
    end
  end
end
