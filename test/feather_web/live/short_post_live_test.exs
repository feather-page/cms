defmodule FeatherWeb.ShortPostLiveTest do
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

  defp edit_post_path(site, post), do: ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit"

  defp short_post(scope) do
    post_fixture(scope, %{
      title: nil,
      slug: nil,
      content: [paragraph("My e-ink display now shows the solar yield.")],
      draft: true
    })
  end

  test "a short post shows its meta title and slug in the details", c do
    post = short_post(c.scope)
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))

    assert has_element?(lv, "#title-field.hidden")
    assert has_element?(lv, "#meta-title-field input")
    assert has_element?(lv, "#slug-field input")

    lv |> form("#post-form", post: %{meta_title: " Solar yield "}) |> render_change()
    assert Content.get_post!(c.scope, post.public_id).meta_title == "Solar yield"

    lv |> form("#post-form", post: %{title: "A title"}) |> render_change()
    refute has_element?(lv, "#meta-title-field")
  end

  test "publishing shows the generated slug and meta title", c do
    Req.Test.stub(Feather.Ollama, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"format" => %{"required" => required}} = Jason.decode!(body)

      answer =
        if "slug" in required,
          do: %{"title" => "E-ink solar dashboard", "slug" => "e-ink-solar-dashboard"},
          else: %{"description" => "A description."}

      Req.Test.json(conn, %{"message" => %{"content" => Jason.encode!(answer)}})
    end)

    post = short_post(c.scope)
    {:ok, lv, _html} = live(c.conn, edit_post_path(c.site, post))

    assert publish_in_form(lv, "#post-content-editor") =~ "Post was published."

    assert has_element?(lv, ~s(#post_slug[value="/e-ink-solar-dashboard"]))
    assert has_element?(lv, ~s(#post_meta_title[value="E-ink solar dashboard"]))
    assert has_element?(lv, "#title-field.hidden")
  end
end
