defmodule Feather.Content.BackfillTest do
  use Feather.DataCase

  alias Feather.Content
  alias Feather.Redirects

  @moduletag :capture_log

  setup do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    %{scope: site_scope_fixture(%{title: "Site", language_code: "de"})}
  end

  defp stub_model(title, slug) do
    test = self()

    Req.Test.stub(Feather.Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"format" => %{"required" => required}} = Jason.decode!(body)
      send(test, {:model_asked, required})

      answer =
        if "slug" in required,
          do: %{"title" => title, "slug" => slug},
          else: %{"description" => "Eine Beschreibung."}

      Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
    end)
  end

  # Published while the model was down, as content published before the suggestions existed.
  defp published_before_suggestions(fun) do
    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))
    fun.()
  end

  defp short_post(scope, attrs \\ %{}) do
    published_before_suggestions(fn ->
      post_fixture(
        scope,
        Map.merge(
          %{
            title: nil,
            slug: nil,
            content: [paragraph("Mein E-Ink-Display zeigt den Solarertrag.")]
          },
          attrs
        )
      )
    end)
  end

  test "republishes a published short post under its new slug and stores the redirect",
       %{scope: scope} do
    post = short_post(scope)
    old_path = "/posts/#{String.downcase(post.public_id)}"
    stub_model("E-Ink-Solar-Dashboard", "e-ink-solar-dashboard")

    assert [%{id: id}] = Content.backfill_suggestions(scope)
    assert id == post.id

    stored = post |> Repo.reload!() |> Repo.preload(:published_version)
    assert stored.slug == "/e-ink-solar-dashboard"
    assert stored.meta_title == "E-Ink-Solar-Dashboard"
    assert stored.description == "Eine Beschreibung."
    assert stored.description_generated
    assert stored.lock_version == post.lock_version
    assert stored.published_version.number == 2
    assert stored.published_version.slug == "/e-ink-solar-dashboard"
    assert Content.publication_status(stored) == :published

    assert [redirect] = Redirects.list_redirects(scope)
    assert redirect.old_path == old_path
    assert redirect.post_id == post.id
    assert redirect.kind == :permanent
  end

  test "skips a record with unpublished changes", %{scope: scope} do
    post = short_post(scope)
    {:ok, _changed} = Content.update_post(scope, post, %{content: [paragraph("Not yet out.")]})
    stub_model("Generated", "generated")

    assert Content.backfill_suggestions(scope) == []

    assert %{slug: nil, meta_title: nil, description: nil} = Repo.reload!(post)
    assert Redirects.list_redirects(scope) == []
    refute_received {:model_asked, _}
  end

  test "skips drafts and records that lack nothing", %{scope: scope} do
    published_before_suggestions(fn ->
      post_fixture(scope, %{title: nil, content: [paragraph("Draft.")], draft: true})
    end)

    post_fixture(scope, %{title: "Titled", description: "Mine.", content: [paragraph("Text.")]})
    page_fixture(scope, %{title: "About", description: "Mine.", content: [paragraph("Text.")]})
    stub_model("Generated", "generated")

    assert Content.backfill_suggestions(scope) == []
    refute_received {:model_asked, _}
  end

  test "gives a page and a titled post only a description", %{scope: scope} do
    page =
      published_before_suggestions(fn ->
        page_fixture(scope, %{title: "About", slug: "/about", content: [paragraph("Me.")]})
      end)

    stub_model("Generated", "generated")

    assert [%{id: id}] = Content.backfill_suggestions(scope)
    assert id == page.id
    assert %{slug: "/about", description: "Eine Beschreibung."} = Repo.reload!(page)
    assert_received {:model_asked, ["description"]}
    refute_received {:model_asked, ["title", "slug"]}
  end

  test "keeps the slug of a short post that has one", %{scope: scope} do
    post = short_post(scope, %{slug: "/mine", description: "Mine."})
    stub_model("Generated", "generated")

    assert [_republished] = Content.backfill_suggestions(scope)
    assert %{slug: "/mine", meta_title: "Generated", description: "Mine."} = Repo.reload!(post)
    assert Redirects.list_redirects(scope) == []
  end

  test "keeps the meta title of a short post that has one and gives it a slug", %{scope: scope} do
    post = short_post(scope, %{meta_title: "Mine", description: "Mine."})
    stub_model("Generated", "generated")

    assert [_republished] = Content.backfill_suggestions(scope)
    assert %{slug: "/generated", meta_title: "Mine"} = Repo.reload!(post)
  end

  test "skips a short post with a meta title and a slug", %{scope: scope} do
    short_post(scope, %{meta_title: "Mine", slug: "/mine", description: "Mine."})
    stub_model("Generated", "generated")

    assert Content.backfill_suggestions(scope) == []
    refute_received {:model_asked, _}
  end

  test "without an answer nothing is republished", %{scope: scope} do
    post = short_post(scope)
    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :econnrefused))

    assert Content.backfill_suggestions(scope) == []
    assert Repo.preload(Repo.reload!(post), :published_version).published_version.number == 1
  end
end
