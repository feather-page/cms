defmodule Feather.PublishingTest do
  use Feather.DataCase

  alias Feather.{Content, Publishing, Sites}

  setup do
    %{scope: site_scope_fixture()}
  end

  test "targets are listed oldest first, only the site's own", %{scope: scope} do
    assert Publishing.list_targets(scope) == []

    %{id: first} = deployment_target_fixture(scope)
    %{id: second} = deployment_target_fixture(scope)
    deployment_target_fixture(site_scope_fixture())

    assert [%{id: ^first}, %{id: ^second}] = Publishing.list_targets(scope)
  end

  test "validates provider and a unique, normalized hostname", %{scope: scope} do
    target = deployment_target_fixture(scope, public_hostname: "  WWW.Example.COM ")
    assert target.public_hostname == "www.example.com"

    assert {:error, changeset} =
             Publishing.create_target(scope, %{
               provider: "s3",
               public_hostname: "www.example.com"
             })

    errors = errors_on(changeset)
    assert "is invalid" in errors.provider
    assert "has already been taken" in errors.public_hostname
  end

  test "update_target/3 changes the hostname only", %{scope: scope} do
    target = deployment_target_fixture(scope)

    assert {:ok, updated} =
             Publishing.update_target(scope, target, %{
               public_hostname: "New.Example.com",
               provider: "s3"
             })

    assert updated.public_hostname == "new.example.com"
    assert updated.provider == "hetzner_ftps"

    assert {:error, changeset} = Publishing.update_target(scope, target, %{public_hostname: ""})
    assert "can't be blank" in errors_on(changeset).public_hostname
  end

  describe "encrypted config" do
    test "round trips and is not stored in plaintext", %{scope: scope} do
      target = deployment_target_fixture(scope)

      config = %{
        "host" => "ftp.example.com",
        "user" => "u1",
        "password" => "secret",
        "path" => "/site"
      }

      assert Publishing.get_target!(scope, target.public_id).config == config

      [[raw]] =
        Repo.query!("SELECT config FROM deployment_targets WHERE id = ?", [target.id]).rows

      assert is_binary(raw)
      refute raw =~ "secret"
      refute raw =~ "ftp.example.com"

      {:ok, updated} = Publishing.update_target_config(scope, target, %{password: "new"})
      assert Publishing.get_target!(scope, updated.public_id).config == %{"password" => "new"}
    end

    test "uses a fresh IV for every write" do
      {:ok, a} = Feather.Encrypted.Map.dump(%{"a" => 1})
      {:ok, b} = Feather.Encrypted.Map.dump(%{"a" => 1})
      refute a == b
      assert {:ok, %{"a" => 1}} = Feather.Encrypted.Map.load(a)
    end

    test "tampered ciphertext does not load" do
      {:ok, <<head::binary-size(30), byte, rest::binary>>} =
        Feather.Encrypted.Map.dump(%{"a" => 1})

      tampered = <<head::binary, Bitwise.bxor(byte, 1), rest::binary>>
      assert :error = Feather.Encrypted.Map.load(tampered)
    end
  end

  describe "deploy lock" do
    test "only one caller acquires the lock", %{scope: scope} do
      target = deployment_target_fixture(scope)

      assert Publishing.acquire_deploy_lock(target)
      refute Publishing.acquire_deploy_lock(target)
      assert Publishing.deploying?(target)

      :ok = Publishing.release_deploy_lock(target)
      refute Publishing.deploying?(target)
      assert Publishing.acquire_deploy_lock(target)
    end

    test "release_stale_locks/0 releases every held lock", %{scope: scope} do
      target = deployment_target_fixture(scope)
      other = deployment_target_fixture(scope)
      assert Publishing.acquire_deploy_lock(target)
      assert Publishing.acquire_deploy_lock(other)

      assert Publishing.release_stale_locks() == 2
      refute Publishing.deploying?(target)
      refute Publishing.deploying?(other)
    end
  end

  describe "undeployed_count/1" do
    defp deployed(target, at) do
      target |> Ecto.Changeset.change(last_deployed_at: at) |> Repo.update!()
    end

    defp in_a_minute, do: DateTime.add(DateTime.utc_now(), 60)

    test "is 0 without a deployment target", %{scope: scope} do
      post_fixture(scope)
      social_media_link_fixture(scope)

      assert Publishing.undeployed_count(scope) == 0
    end

    test "compares the newest publish of posts, pages and projects with the last deploy", %{
      scope: scope
    } do
      target = deployment_target_fixture(scope)

      for publish <- [&post_fixture/1, &page_fixture/1, &project_fixture/1] do
        deployed(target, DateTime.utc_now())
        assert Publishing.undeployed_count(scope) == 0

        publish.(scope)
        assert Publishing.undeployed_count(scope) > 0
      end
    end

    test "ignores drafts and other sites", %{scope: scope} do
      scope |> deployment_target_fixture() |> deployed(in_a_minute())
      later = DateTime.add(DateTime.utc_now(), 3600)
      other = site_scope_fixture()
      post_fixture(other)

      Repo.update_all(Feather.Content.PostVersion, set: [published_at: later])

      assert Publishing.undeployed_count(scope) == 0
      post_fixture(scope, draft: true)
      assert Publishing.undeployed_count(scope) == 0
    end

    test "a target never deployed counts every published record and the site", %{
      scope: scope
    } do
      scope |> deployment_target_fixture() |> deployed(in_a_minute())
      deployment_target_fixture(scope)
      post_fixture(scope)

      # The homepage, the post and the site.
      assert Publishing.undeployed_count(scope) == 3
    end

    test "counts the records published after the oldest deploy",
         %{scope: scope} do
      assert Publishing.undeployed_count(scope) == 0

      target = deployment_target_fixture(scope)
      deployed(target, DateTime.utc_now())
      assert Publishing.undeployed_count(scope) == 0

      post_fixture(scope)
      page_fixture(scope)
      post_fixture(scope, draft: true)
      assert Publishing.undeployed_count(scope) == 2

      deployed(target, in_a_minute())
      assert Publishing.undeployed_count(scope) == 0
    end
  end

  describe "undeployed_count/1 and the site's own changes" do
    setup %{scope: scope} do
      target = deployment_target_fixture(scope)
      rewind(target)
      %{target: target}
    end

    defp site_changes_count(scope, change) do
      assert Publishing.undeployed_count(scope) == 0
      change.()
      Publishing.undeployed_count(scope)
    end

    test "a changed setting counts once, until the next deploy", %{scope: scope, target: target} do
      assert site_changes_count(scope, fn ->
               {:ok, _site} = Sites.update_site(scope, scope.site, %{title: "New title"})
               {:ok, _site} = Sites.update_site(scope, scope.site, %{copyright: "CC BY"})
             end) == 1

      post_fixture(scope)
      assert Publishing.undeployed_count(scope) == 2

      deployed(target, DateTime.add(DateTime.utc_now(), 1, :minute))
      assert Publishing.undeployed_count(scope) == 0
    end

    test "saving the settings unchanged does not count", %{scope: scope} do
      assert site_changes_count(scope, fn ->
               {:ok, _site} = Sites.update_site(scope, scope.site, %{title: scope.site.title})
             end) == 0
    end

    test "adding and deleting social media links counts", %{scope: scope, target: target} do
      assert site_changes_count(scope, fn -> social_media_link_fixture(scope) end) == 1

      link = social_media_link_fixture(scope)
      rewind(target)

      assert site_changes_count(scope, fn ->
               {:ok, _link} = Sites.delete_social_media_link(scope, link)
             end) == 1
    end

    test "setting and removing a mascot or the portrait counts", %{scope: scope, target: target} do
      upload = fn put ->
        path = test_image_path(90, 30)
        {:ok, _site} = put.(path)
        File.rm(path)
      end

      changes = [
        fn -> upload.(&Sites.put_mascot(scope, :footer, &1, "mascot.png")) end,
        fn -> {:ok, _site} = Sites.remove_mascot(scope, :footer) end,
        fn -> upload.(&Sites.put_portrait(scope, &1, "portrait.png")) end,
        fn -> {:ok, _site} = Sites.remove_portrait(scope) end
      ]

      for change <- changes do
        rewind(target)
        assert site_changes_count(scope, change) == 1
      end
    end

    test "adding, moving and removing navigation items counts", %{scope: scope, target: target} do
      about = page_fixture(scope, title: "About", draft: true)
      contact = page_fixture(scope, title: "Contact", draft: true)

      changes = [
        fn -> {:ok, _item} = Sites.add_to_navigation(scope, about) end,
        fn -> {:ok, _item} = Sites.add_to_navigation(scope, contact) end,
        fn ->
          item = Enum.find(Sites.list_navigation_items(scope), &(&1.page_id == contact.id))
          :ok = Sites.move_navigation_item_up(scope, item)
        end,
        fn -> :ok = Sites.remove_from_navigation(scope, about) end,
        fn ->
          {:ok, _page} = Content.delete_page(scope, Content.get_page(scope, contact.public_id))
        end
      ]

      for change <- changes do
        rewind(target)
        assert site_changes_count(scope, change) == 1
      end
    end

    test "toggling a page's add_to_navigation counts", %{scope: scope, target: target} do
      page = page_fixture(scope, title: "About", draft: true)

      assert site_changes_count(scope, fn ->
               {:ok, _page} = Content.update_page(scope, page, %{add_to_navigation: true})
             end) == 1

      rewind(target)
      page = Content.get_page(scope, page.public_id)

      assert site_changes_count(scope, fn ->
               {:ok, _page} = Content.update_page(scope, page, %{add_to_navigation: false})
             end) == 1
    end

    test "changes to the navigation that change nothing do not count", %{
      scope: scope,
      target: target
    } do
      page = page_fixture(scope, title: "About", draft: true)
      {:ok, item} = Sites.add_to_navigation(scope, page)
      rewind(target)

      assert site_changes_count(scope, fn ->
               {:ok, _item} = Sites.add_to_navigation(scope, page)
               :ok = Sites.move_navigation_item_up(scope, item)
               :ok = Sites.remove_from_navigation(scope, page_fixture(scope, draft: true))
             end) == 0
    end

    # The site and its records last changed before the deploy, which was before now.
    defp rewind(target) do
      an_hour_ago = DateTime.add(DateTime.utc_now(), -1, :hour)
      Repo.update_all(Feather.Sites.Site, set: [updated_at: an_hour_ago])
      Repo.update_all(Feather.Content.PageVersion, set: [published_at: an_hour_ago])
      deployed(target, DateTime.add(DateTime.utc_now(), -1, :minute))
    end
  end

  describe "scheduled posts" do
    setup %{scope: scope} do
      Repo.update_all(Feather.Sites.Site, set: [updated_at: at("06:00")])
      Repo.update_all(Feather.Content.PageVersion, set: [published_at: at("06:00")])
      target = scope |> deployment_target_fixture() |> deployed(at("07:00"))
      %{target: target}
    end

    defp at(hh_mm),
      do: DateTime.new!(~D[2026-10-01], Time.from_iso8601!(hh_mm <> ":00.000000"), "Etc/UTC")

    defp post_published(scope, published_at, publish_at) do
      post = post_fixture(scope)

      Repo.update_all(
        from(v in Feather.Content.PostVersion, where: v.post_id == ^post.id),
        set: [published_at: published_at, publish_at: publish_at]
      )

      post
    end

    defp republished(scope, post, published_at, publish_at) do
      post = Content.get_post(scope, post.public_id)
      {:ok, post} = Content.update_post(scope, post, %{title: "#{post.title} again"})
      {:ok, post} = Content.publish(scope, post)

      Repo.update_all(
        from(v in Feather.Content.PostVersion, where: v.id == ^post.published_version_id),
        set: [published_at: published_at, publish_at: publish_at]
      )

      post
    end

    test "undeployed_count/2 counts a scheduled post once it is due", %{
      scope: scope,
      target: target
    } do
      post_published(scope, at("07:24"), at("08:08"))
      deployed(target, at("07:25"))

      assert Publishing.undeployed_count(scope, at("08:00")) == 0
      assert Publishing.undeployed_count(scope, at("08:09")) == 1

      deployed(target, at("08:10"))
      assert Publishing.undeployed_count(scope, at("08:11")) == 0
    end

    test "undeployed_count/2 leaves out a post not due yet, even for a target never deployed",
         %{scope: scope} do
      deployment_target_fixture(scope)
      post_published(scope, at("07:24"), at("08:08"))

      # The homepage and the site.
      assert Publishing.undeployed_count(scope, at("08:00")) == 2
      assert Publishing.undeployed_count(scope, at("08:09")) == 3
    end

    test "undeployed_count/2 ignores the date of a scheduled version republished for now", %{
      scope: scope,
      target: target
    } do
      post = post_published(scope, at("07:24"), at("08:08"))
      republished(scope, post, at("07:30"), at("07:30"))
      deployed(target, at("07:55"))

      assert Publishing.undeployed_count(scope, at("08:00")) == 0
      assert Publishing.undeployed_count(scope, at("08:09")) == 0
    end

    test "undeployed_count/2 does not count a scheduled post unpublished before its date", %{
      scope: scope,
      target: target
    } do
      post = post_published(scope, at("07:24"), at("08:08"))
      deployed(target, at("07:25"))
      {:ok, _post} = Content.unpublish(scope, Content.get_post(scope, post.public_id))

      assert Publishing.undeployed_count(scope, at("08:09")) == 0
    end

    test "undeployed_count/2 counts a rescheduled post from its new date", %{
      scope: scope,
      target: target
    } do
      post = post_published(scope, at("07:24"), at("08:08"))
      republished(scope, post, at("07:26"), at("10:00"))
      deployed(target, at("07:27"))

      assert Publishing.undeployed_count(scope, at("08:09")) == 0
      assert Publishing.undeployed_count(scope, at("10:01")) == 1
    end

    test "publishing without a future date does not deploy", %{scope: scope} do
      post_published(scope, at("07:40"), at("07:30"))

      assert Publishing.undeployed_count(scope, at("07:41")) == 1
      assert Publishing.deploy_due_posts(at("07:00"), at("07:41")) == []
      assert Publishing.deploy_due_posts(nil, at("07:41")) == []
      refute_received {:deploy_requested, _target}
    end

    test "deploy_due_posts/2 deploys only the targets of a site deployed before the post was due",
         %{scope: scope, target: target} do
      %{id: other_id} = scope |> deployment_target_fixture() |> deployed(at("08:08"))
      post_published(scope, at("07:24"), at("08:08"))
      deployed(target, at("07:25"))

      assert [%{id: id}] = Publishing.deploy_due_posts(at("08:07"), at("08:09"))
      assert id == target.id
      refute_received {:deploy_requested, %{id: ^other_id}}
    end

    test "deploy_due_posts/2 skips a target whose config does not decrypt", %{
      scope: scope,
      target: target
    } do
      other = site_scope_fixture()
      other_target = other |> deployment_target_fixture() |> deployed(at("07:00"))
      post_published(scope, at("07:24"), at("08:08"))
      post_published(other, at("07:24"), at("08:08"))

      Repo.query!("UPDATE deployment_targets SET config = ? WHERE id = ?", [
        "garbage",
        target.id
      ])

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert [%{id: id}] = Publishing.deploy_due_posts(at("08:07"), at("08:09"))
          assert id == other_target.id
        end)

      assert log =~ target.public_hostname
      assert_received {:deploy_requested, %{id: id}}
      assert id == other_target.id
      refute_received {:deploy_requested, _target}
    end

    test "deploy_due_posts/2 deploys the targets deployed before a post became due", %{
      scope: scope,
      target: target
    } do
      post_published(scope, at("07:24"), at("08:08"))
      deployed(target, at("07:25"))

      assert [%{id: id}] = Publishing.deploy_due_posts(at("08:07"), at("08:08"))
      assert id == target.id
      assert_received {:deploy_requested, %{id: ^id}}
    end

    test "deploy_due_posts/2 deploys each target once", %{scope: scope, target: target} do
      post_published(scope, at("07:24"), at("08:08"))
      post_published(scope, at("07:24"), at("08:08"))

      assert [_target] = Publishing.deploy_due_posts(at("08:00"), at("08:09"))
      assert_received {:deploy_requested, %{id: id}}
      assert id == target.id
      refute_received {:deploy_requested, _target}
    end

    test "deploy_due_posts/2 catches up on everything due and undeployed without a lower bound",
         %{scope: scope} do
      post_published(scope, at("07:24"), at("08:08"))

      assert [_target] = Publishing.deploy_due_posts(nil, at("12:00"))
      assert_received {:deploy_requested, _target}
    end

    test "deploy_due_posts/2 deploys only the site of the due post", %{scope: scope} do
      other = site_scope_fixture()
      other_target = other |> deployment_target_fixture() |> deployed(at("07:00"))
      post_published(other, at("07:24"), at("08:08"))
      post_published(scope, at("07:24"), at("07:30"))

      assert [%{id: id}] = Publishing.deploy_due_posts(at("08:00"), at("08:09"))
      assert id == other_target.id
    end

    test "deploy_due_posts/2 deploys nothing for posts that are not due in the window", %{
      scope: scope,
      target: target
    } do
      none_due = fn from, to ->
        assert Publishing.deploy_due_posts(from, to) == []
        refute_received {:deploy_requested, _target}
      end

      # A normal publish: the publish date had passed when it was published.
      post_published(scope, at("07:40"), at("07:30"))
      none_due.(at("07:00"), at("08:09"))

      post = post_published(scope, at("07:24"), at("08:08"))
      none_due.(at("08:00"), at("08:07"))
      none_due.(at("08:08"), at("08:30"))

      {:ok, _post} = Content.unpublish(scope, Content.get_post(scope, post.public_id))
      none_due.(at("08:00"), at("08:09"))
      none_due.(nil, at("08:09"))

      post_published(scope, at("07:24"), at("08:08"))
      deployed(target, at("08:08"))
      none_due.(nil, at("08:09"))

      deployed(target, nil)
      none_due.(nil, at("08:09"))
    end
  end

  describe "live?/3" do
    test "a published version is live once every deployment target deployed after it" do
      now = DateTime.utc_now()
      version = %{published_at: DateTime.add(now, -1, :hour)}

      assert Publishing.live?([%{last_deployed_at: now}], version)
      refute Publishing.live?([%{last_deployed_at: now}, %{last_deployed_at: nil}], version)
      refute Publishing.live?([%{last_deployed_at: DateTime.add(now, -2, :hour)}], version)

      # Without a deployment target or a published version there is nothing to wait for.
      assert Publishing.live?([], version)
      assert Publishing.live?([%{last_deployed_at: nil}], nil)
    end

    test "a post is live once every deployment target deployed after its publish_at" do
      now = DateTime.utc_now()
      published_at = DateTime.add(now, -3, :hour)
      deployed = [%{last_deployed_at: DateTime.add(now, -1, :hour)}]

      assert Publishing.live?(deployed, %{
               published_at: published_at,
               publish_at: DateTime.add(now, -2, :hour)
             })

      # Due since the last deploy: the export left it out.
      refute Publishing.live?(deployed, %{published_at: published_at, publish_at: now}, now)

      # Scheduled: not live, not even without a deployment target.
      tomorrow = DateTime.add(now, 1, :day)
      refute Publishing.live?(deployed, %{published_at: published_at, publish_at: tomorrow})
      refute Publishing.live?([], %{published_at: published_at, publish_at: tomorrow})
    end
  end
end
