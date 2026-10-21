defmodule FeatherWeb.PublishLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Content

  @moduletag :capture_log

  setup [:register_and_log_in_user, :create_site_for_user]

  setup %{scope: scope, site: site} do
    previous = Application.get_env(:feather, :ollama_url)
    Application.put_env(:feather, :ollama_url, "http://ollama.test:11434")
    on_exit(fn -> Application.put_env(:feather, :ollama_url, previous) end)

    Req.Test.set_req_test_to_shared()
    on_exit(&Req.Test.set_req_test_to_private/0)

    test = self()

    Req.Test.stub(Feather.Ollama, fn conn ->
      send(test, {:asked, self()})

      receive do
        :answer -> Req.Test.json(conn, %{"message" => %{"content" => ~s({"description": "D."})}})
      end
    end)

    post =
      post_fixture(scope, %{
        title: "Lighthouses",
        content: [paragraph("Lighthouses guide ships along the coast.")],
        draft: true
      })

    %{post: post, path: ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit"}
  end

  defp click_publish(lv),
    do: lv |> element("#post-content-editor") |> render_hook("publish", %{"editor" => "saved"})

  test "a publish finishes after the form is left", c do
    {:ok, lv, _html} = live(c.conn, c.path)
    click_publish(lv)
    assert_receive {:asked, model}

    [publisher | _callers] =
      Process.info(model, :dictionary) |> elem(1) |> Keyword.fetch!(:"$callers")

    ref = Process.monitor(publisher)
    Process.flag(:trap_exit, true)
    lv_ref = Process.monitor(lv.pid)
    Process.exit(lv.pid, :shutdown)
    assert_receive {:DOWN, ^lv_ref, :process, _pid, :shutdown}

    send(model, :answer)
    assert_receive {:DOWN, ^ref, :process, ^publisher, :normal}
    refute Content.draft?(Content.get_post!(c.scope, c.post.public_id))
  end

  test "a second click while publishing publishes once", c do
    {:ok, lv, _html} = live(c.conn, c.path)
    click_publish(lv)
    assert_receive {:asked, model}

    click_publish(lv)
    refute_receive {:asked, _model}, 50

    send(model, :answer)
    assert render_async(lv) =~ "Post was published."

    assert [_version] =
             Content.list_versions(c.scope, Content.get_post!(c.scope, c.post.public_id))
  end

  test "a change while publishing asks to publish again", c do
    {:ok, lv, _html} = live(c.conn, c.path)
    click_publish(lv)
    assert_receive {:asked, model}

    lv |> form("#post-form", post: %{title: "Lighthouses of the north"}) |> render_change()

    send(model, :answer)
    assert render_async(lv) =~ "it changed while it was being published, publish again."
    assert Content.draft?(Content.get_post!(c.scope, c.post.public_id))
  end
end
