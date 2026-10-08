defmodule FeatherWeb.HeaderImagePickerTest do
  # Ports features/unsplash_images.feature (through the picker, which
  # replaces the Rails JSON endpoints) and the header image picker.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Content, Media}

  setup [:register_and_log_in_user, :create_site_for_user]

  @picker "#post-header-image-picker"

  @photo %{
    "id" => "abc123",
    "description" => "A beautiful landscape",
    "alt_description" => "Mountains and trees",
    "urls" => %{
      "thumb" => "https://images.unsplash.com/thumb.jpg",
      "regular" => "https://images.unsplash.com/regular.jpg"
    },
    "user" => %{"name" => "John Doe", "links" => %{"html" => "https://unsplash.com/@johndoe"}},
    "links" => %{"download_location" => "https://api.unsplash.com/photos/abc123/download"}
  }

  defp new_post(conn, site), do: live(conn, ~p"/sites/#{site.public_id}/posts/new")

  defp with_unsplash_key(_context) do
    previous = Application.get_env(:feather, :unsplash_access_key)
    Application.put_env(:feather, :unsplash_access_key, "test-key")
    on_exit(fn -> Application.put_env(:feather, :unsplash_access_key, previous) end)
    Req.Test.set_req_test_to_shared()
    on_exit(&Req.Test.set_req_test_to_private/0)
    :ok
  end

  describe "Unsplash" do
    setup :with_unsplash_key

    test "searches, shows photographer info and saves the chosen photo with attribution", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      Req.Test.stub(Feather.Unsplash, fn conn ->
        assert conn.request_path == "/search/photos"
        assert conn.query_params["query"] == "nature"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Client-ID test-key"]
        Req.Test.json(conn, %{"results" => [@photo]})
      end)

      image = File.read!(test_image_path())

      Req.Test.stub(Feather.Media, fn conn ->
        assert conn.host == "images.unsplash.com"
        Plug.Conn.send_resp(conn, 200, image)
      end)

      {:ok, lv, _html} = new_post(conn, site)

      lv |> element("#{@picker}-choose-cover") |> render_click()
      lv |> form("#{@picker}-search-form", query: "nature") |> render_change()

      assert has_element?(lv, "#unsplash-abc123 img[src='https://images.unsplash.com/thumb.jpg']")

      assert has_element?(
               lv,
               "#unsplash-abc123 a[href='https://unsplash.com/@johndoe']",
               "John Doe"
             )

      lv |> element("#unsplash-abc123 button") |> render_click()

      [image] = Media.list_images(scope)
      assert image.source_url == "https://images.unsplash.com/regular.jpg"

      assert image.unsplash_data == %{
               "photographer_name" => "John Doe",
               "photographer_url" => "https://unsplash.com/@johndoe",
               "download_location" => "https://api.unsplash.com/photos/abc123/download"
             }

      refute has_element?(lv, "#{@picker}-panel")
      assert has_element?(lv, "#{@picker}-cover img")
      assert has_element?(lv, ~s(#post_header_image_id[value="#{image.id}"]))

      lv |> form("#post-form", post: %{title: "With cover"}) |> render_submit()
      [post] = Content.list_posts(scope)
      assert post.header_image_id == image.id
    end

    test "does not search for short queries", %{conn: conn, site: site} do
      Req.Test.stub(Feather.Unsplash, fn _conn -> flunk("Unsplash must not be called") end)
      {:ok, lv, _html} = new_post(conn, site)

      lv |> element("#{@picker}-choose-thumbnail") |> render_click()
      lv |> form("#{@picker}-search-form", query: "a") |> render_change()

      refute has_element?(lv, ".unsplash-result")
    end

    test "switches between search and upload", %{conn: conn, site: site} do
      {:ok, lv, _html} = new_post(conn, site)

      lv |> element("#{@picker}-choose-cover") |> render_click()
      assert has_element?(lv, "#{@picker}-search-cover.active")
      assert has_element?(lv, "#{@picker}-search-form")

      lv |> element("#{@picker}-upload-cover") |> render_click()
      assert has_element?(lv, "#{@picker}-upload-cover.active")
      assert has_element?(lv, "#{@picker}-upload-form")
      refute has_element?(lv, "#{@picker}-search-form")
    end
  end

  test "hides the Unsplash search without an access key", %{conn: conn, site: site} do
    {:ok, lv, _html} = new_post(conn, site)
    lv |> element("#{@picker}-choose-cover") |> render_click()

    refute has_element?(lv, "#{@picker}-search-cover")
    refute has_element?(lv, "#{@picker}-search-form")
    assert has_element?(lv, "#{@picker}-upload-form")
  end

  test "shows empty slots with Add and filled slots with Change and Remove", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    cover = image_fixture(scope)
    post = post_fixture(scope, header_image_id: cover.id)

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit")

    assert has_element?(lv, "#{@picker}-choose-cover", "Change")
    assert has_element?(lv, "#{@picker}-remove-cover")
    assert has_element?(lv, "#{@picker}-choose-thumbnail", "Add")
    refute has_element?(lv, "#{@picker}-remove-thumbnail")
    assert has_element?(lv, "#{@picker}-thumbnail-slot .media-slot__tile--empty")
  end

  test "uploads a thumbnail and removes it", %{conn: conn, site: site, scope: scope} do
    {:ok, lv, _html} = new_post(conn, site)

    lv |> element("#{@picker}-choose-thumbnail") |> render_click()

    upload =
      file_input(lv, "#{@picker}-upload-form", :image, [
        %{name: "photo.png", content: File.read!(test_image_path()), type: "image/png"}
      ])

    render_upload(upload, "photo.png")

    [image] = Media.list_images(scope)
    assert image.filename == "photo.png"
    assert has_element?(lv, "#{@picker}-thumbnail img")
    assert has_element?(lv, ~s(#post_thumbnail_image_id[value="#{image.id}"]))

    lv |> element("#{@picker}-remove-thumbnail") |> render_click()
    refute has_element?(lv, "#{@picker}-thumbnail")
    refute has_element?(lv, ~s(#post_thumbnail_image_id[value="#{image.id}"]))

    lv |> form("#post-form", post: %{title: "No thumbnail"}) |> render_submit()
    assert [%{thumbnail_image_id: nil}] = Content.list_posts(scope)
  end

  test "shows an error for files that are not images", %{conn: conn, site: site} do
    {:ok, lv, _html} = new_post(conn, site)
    lv |> element("#{@picker}-choose-cover") |> render_click()

    upload =
      file_input(lv, "#{@picker}-upload-form", :image, [
        %{name: "fake.png", content: "not an image", type: "image/png"}
      ])

    render_upload(upload, "fake.png")
    assert has_element?(lv, "#{@picker}-error", "must be an image")
  end

  test "picks and removes an emoji", %{conn: conn, site: site, scope: scope} do
    {:ok, lv, _html} = new_post(conn, site)

    lv |> element("#{@picker}-choose-emoji") |> render_click()
    assert has_element?(lv, "#{@picker}-emoji-picker", "Animals")

    lv |> element("#{@picker}-emoji-picker button", "🦊") |> render_click()
    refute has_element?(lv, "#{@picker}-emoji-picker")
    assert has_element?(lv, "#{@picker}-emoji", "🦊")
    assert has_element?(lv, ~s(#post_emoji[value="🦊"]))

    lv |> form("#post-form", post: %{title: "Fox"}) |> render_submit()
    assert [%{emoji: "🦊"}] = Content.list_posts(scope)
  end

  test "keeps the existing images of a post when editing", %{conn: conn, site: site, scope: scope} do
    cover = image_fixture(scope)
    post = post_fixture(scope, header_image_id: cover.id, emoji: "🌲")

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit")
    assert has_element?(lv, "#{@picker}-cover img")
    assert has_element?(lv, "#{@picker}-emoji", "🌲")

    lv |> element("#{@picker}-remove-emoji") |> render_click()
    lv |> form("#post-form") |> render_submit()

    post = Content.get_post!(scope, post.public_id)
    assert post.header_image_id == cover.id
    assert post.emoji == nil
  end
end
