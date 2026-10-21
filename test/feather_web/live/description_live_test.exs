defmodule FeatherWeb.DescriptionLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Content

  @moduletag :capture_log

  setup [:register_and_log_in_user, :create_site_for_user]

  setup do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    Req.Test.set_req_test_to_shared()
    on_exit(&Req.Test.set_req_test_to_private/0)
  end

  defp stub_description(description) do
    Req.Test.stub(Feather.Ollama, fn conn ->
      content = Jason.encode!(%{"description" => description})
      Req.Test.json(conn, %{"message" => %{"content" => content}})
    end)
  end

  defp edit_post_path(site, post), do: ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit"

  defp draft_post(scope) do
    post_fixture(scope, %{
      title: "Lighthouses",
      content: [paragraph("Lighthouses guide ships along the coast.")],
      draft: true
    })
  end

  defp description_value(lv) do
    lv
    |> element("#description-field textarea")
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.text()
    |> String.trim()
  end

  test "editing the description saves it as the member's own", c do
    post = draft_post(c.scope)
    {:ok, _post} = Content.put_suggested_description(c.scope, post, "Generated.")
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))

    lv |> form("#post-form", post: %{description: "My own words."}) |> render_change()

    stored = Content.get_post!(c.scope, post.public_id)
    assert stored.description == "My own words."
    refute stored.description_generated
  end

  test "Suggest replaces the description with the model's", c do
    post = draft_post(c.scope)
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))
    lv |> form("#post-form", post: %{description: "Mine."}) |> render_change()

    stub_description("Wie Leuchttürme Schiffe leiten.")
    lv |> element("#suggest-description") |> render_click()
    render_async(lv)

    assert description_value(lv) == "Wie Leuchttürme Schiffe leiten."
    stored = Content.get_post!(c.scope, post.public_id)
    assert stored.description == "Wie Leuchttürme Schiffe leiten."
    assert stored.description_generated

    lv |> form("#post-form", post: %{title: "Lighthouses of the north"}) |> render_change()
    assert Content.get_post!(c.scope, post.public_id).description_generated
  end

  test "Suggest without an answer keeps the description and says so", c do
    post = draft_post(c.scope)
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))

    Req.Test.stub(Feather.Ollama, &Req.Test.transport_error(&1, :timeout))
    lv |> element("#suggest-description") |> render_click()

    assert render_async(lv) =~ "No description could be suggested"
    assert Content.get_post!(c.scope, post.public_id).description == nil
  end

  test "publishing shows the generated description", c do
    post = draft_post(c.scope)
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))

    stub_description("Wie Leuchttürme Schiffe leiten.")
    assert publish_in_form(lv, "#post-content-editor") =~ "Post was published."

    assert description_value(lv) == "Wie Leuchttürme Schiffe leiten."
    assert has_element?(lv, "#status-badge", "Published")
  end

  test "publishing waits for the model with a notice", c do
    post = draft_post(c.scope)
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))
    test = self()

    Req.Test.stub(Feather.Ollama, fn conn ->
      send(test, {:asked, self()})
      receive do: (:answer -> stub_answer(conn))
    end)

    html = lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})
    assert html =~ "Publishing…"
    assert_receive {:asked, model}
    assert Content.draft?(Content.get_post!(c.scope, post.public_id))

    send(model, :answer)
    assert render_async(lv) =~ "Post was published."
    refute Content.draft?(Content.get_post!(c.scope, post.public_id))
  end

  defp stub_answer(conn) do
    Req.Test.json(conn, %{"message" => %{"content" => ~s({"description": "Later."})}})
  end

  test "pages have the description field, projects do not", c do
    page = page_fixture(c.scope, %{title: "About", slug: "/about", draft: true})
    {:ok, lv, _html} = live(c.conn, ~p"/sites/#{c.site.public_id}/pages/#{page.public_id}/edit")
    assert has_element?(lv, "#description-field textarea")
    assert has_element?(lv, "#suggest-description")

    project = project_fixture(c.scope, %{title: "Boat"})

    {:ok, lv, _html} =
      live(c.conn, ~p"/sites/#{c.site.public_id}/projects/#{project.public_id}/edit")

    refute has_element?(lv, "#description-field")
  end

  test "a new post cannot ask for a suggestion yet", c do
    {:ok, lv, _html} = live(c.conn, ~p"/sites/#{c.site.public_id}/posts/new")
    assert has_element?(lv, "#suggest-description[disabled]")
  end
end
