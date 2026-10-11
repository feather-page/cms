defmodule FeatherWeb.ConfirmDialogTest do
  # Every irreversible delete asks in the one shared confirmation dialog of
  # the layout (setzkasten's confirm_dialog, DECISIONS.md 0013), never with
  # the browser's data-confirm; unpublishing does not ask.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Content

  setup [:register_and_log_in_user, :create_site_for_user]

  defp posts_path(site), do: ~p"/sites/#{site.public_id}/posts"
  defp edit_path(site, post), do: posts_path(site) <> "/#{post.public_id}/edit"

  test "the layout renders the dialog once, in English", %{conn: conn, site: site} do
    for path <- [~p"/", posts_path(site), ~p"/users/settings"] do
      {:ok, lv, html} = live(conn, path)

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query("dialog#confirm-delete")
             |> Enum.count() == 1

      assert has_element?(lv, "#confirm-delete-title", "Delete for good?")
      assert has_element?(lv, "#confirm-delete-text", "This cannot be undone.")
      assert has_element?(lv, "#confirm-delete-confirm-label", "Delete")
      assert has_element?(lv, "#confirm-delete .modal-action button[autofocus]", "Cancel")
      refute html =~ "data-confirm="
    end
  end

  test "deleting a post from the list asks first, then deletes", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    post = post_fixture(scope, title: "Old news")
    {:ok, lv, _html} = live(conn, posts_path(site))

    # The trigger only opens the dialog: the delete waits on its confirm button.
    asked = asked(lv, "#delete-post-#{post.public_id}-menu-item")
    assert asked.question == "Delete “Old news”?"
    assert asked.label == nil

    assert asked.action == [
             ["push", %{"event" => "delete", "value" => %{"id" => post.public_id}}]
           ]

    assert asked(lv, "#delete-post-#{post.public_id}-menu-item") == asked
    assert Content.get_post!(scope, post.public_id)

    html = confirm_click(lv, "#delete-post-#{post.public_id}-menu-item", "Delete “Old news”?")

    assert html =~ "Post was successfully deleted."
    refute has_element?(lv, "#post-#{post.public_id}")
    assert_raise Ecto.NoResultsError, fn -> Content.get_post!(scope, post.public_id) end
  end

  test "discarding changes and restoring a version ask with their own button label", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    post = post_fixture(scope, title: "Version 1")
    {:ok, post} = Content.update_post(scope, post, %{title: "Version 2"})
    {:ok, post} = Content.publish(scope, post)
    {:ok, _post} = Content.update_post(scope, post, %{title: "Unpublished"})
    {:ok, lv, _html} = live(conn, edit_path(site, post))

    assert %{question: "Discard the unpublished changes?", label: "Discard"} =
             asked(lv, "#discard-post")

    assert %{question: "Restore version 1?", label: "Restore", action: [["push", push]]} =
             asked(lv, "#restore-version-1")

    assert push == %{"event" => "restore", "value" => %{"number" => "1"}}

    assert %{question: "Delete this post?", label: nil} = asked(lv, "#delete-post")
  end

  test "unpublishing does not ask", %{conn: conn, site: site, scope: scope} do
    post = post_fixture(scope, title: "Live")
    {:ok, lv, _html} = live(conn, edit_path(site, post))

    refute has_element?(lv, "#unpublish-post[aria-haspopup]")
    lv |> element("#unpublish-post") |> render_click()
    assert Content.draft?(Content.get_post!(scope, post.public_id))
  end

  test "removing a member asks with its own label", %{conn: conn, site: site} do
    other = user_fixture()
    {:ok, member} = Feather.Sites.add_member(site, other)
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

    assert %{label: "Remove", question: question} =
             asked(lv, "#remove-member-#{member.id}-menu-item")

    assert question == "Remove #{other.email} from this site?"
  end
end
