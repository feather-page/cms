defmodule Feather.ReleaseTest do
  use Feather.DataCase

  import ExUnit.CaptureIO

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
      previous = Application.get_env(:feather, :ollama_url)
      on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)
    end

    @tag :capture_log
    test "fills in alt texts and republishes short posts of every site" do
      Application.delete_env(:feather, :ollama_url)
      scope = site_scope_fixture(%{language_code: "de"})
      image = image_fixture(scope)
      post = post_fixture(scope, %{title: nil, slug: nil, content: [paragraph("Solar.")]})

      Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")

      Req.Test.stub(Feather.Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        answer =
          case Jason.decode!(body)["format"]["required"] do
            ["alt"] -> %{"alt" => "Grau"}
            ["description"] -> %{"description" => "Solar."}
            ["title", "slug"] -> %{"title" => "Solar", "slug" => "solar"}
          end

        Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
      end)

      output = capture_io(fn -> assert Release.backfill_suggestions() == :ok end)

      assert output =~ "#{scope.site.domain}: alt texts filled in: 1, records published again: 1"
      assert Repo.reload!(image).alt == "Grau"
      assert Repo.reload!(post).slug == "/solar"
    end

    test "refuses without a model" do
      Application.delete_env(:feather, :ollama_url)

      assert capture_io(:stderr, fn ->
               assert Release.backfill_suggestions() == {:error, :not_configured}
             end) =~ "OLLAMA_URL is not set."
    end
  end
end
