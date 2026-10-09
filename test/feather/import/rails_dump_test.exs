defmodule Feather.Import.RailsDumpTest do
  use Feather.DataCase

  alias Feather.{Accounts, Media}
  alias Feather.Accounts.{ApiToken, User}
  alias Feather.Books.Book
  alias Feather.Content.{Page, Post, PostVersion, Project}
  alias Feather.Import.{RailsDump, Report}
  alias Feather.Media.{Image, Variants}
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Sites.{Invitation, NavigationItem, Site, SiteUser, SocialMediaLink}

  @fixture Path.expand("../../fixtures/rails_dump", __DIR__)
  @image_public_ids ~w(x3BP8Cxu2hMa 5olRHPvR0D5N DrqGSEC4zyvZ XBOKyjLaiLsB)
  # The plain token whose SHA-256 digest is in the fixture's api_tokens.json.
  @api_token String.duplicate("f00d", 16)

  @notes_site "d9ecb81d-e361-430f-a456-00eaff380d36"
  @post_id "d3ed9664-5b57-4ab6-8199-1be1fa12279a"
  @book_id "ba30d799-7144-43bd-a0ff-c71048619d12"

  setup do
    on_exit(fn ->
      for public_id <- @image_public_ids do
        File.rm_rf!(Path.join([Media.storage_root(), "images", public_id]))
      end
    end)
  end

  defp import!(dir \\ @fixture, opts \\ []) do
    assert {:ok, report} =
             RailsDump.run(dir, Keyword.put_new(opts, :now, ~U[2026-10-06 19:00:00Z]))

    report
  end

  # A writable copy of the fixture dump, changed by `fun` (table => rows).
  defp dump_with(fun) do
    dir = Path.join(System.tmp_dir!(), "feather-dump-#{System.unique_integer([:positive])}")
    File.cp_r!(@fixture, dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    tables =
      for path <- Path.wildcard(Path.join(dir, "*.json")),
          table = Path.basename(path, ".json"),
          table != "manifest",
          into: %{},
          do: {table, path |> File.read!() |> Jason.decode!()}

    for {table, rows} <- fun.(tables) do
      File.write!(Path.join(dir, "#{table}.json"), Jason.encode!(rows))
    end

    dir
  end

  defp update_row(tables, table, id, fun) do
    Map.update!(tables, table, fn rows ->
      Enum.map(rows, fn row -> if row["id"] == id, do: fun.(row), else: row end)
    end)
  end

  describe "importing the fixture dump" do
    test "imports every row and reports nothing to fix" do
      report = import!()

      for {table, %{dumped: dumped, imported: imported}} <- report.counts do
        assert dumped == imported, "#{table}: #{dumped} dumped, #{imported} imported"
      end

      assert report.counts["users"] == %{dumped: 2, imported: 2}
      assert report.counts["images"] == %{dumped: 4, imported: 4}

      for kind <- [:missing_file, :dangling_reference, :validation_bypassed, :skipped] do
        assert Report.findings(report, kind) == [],
               "#{kind}: #{inspect(Report.findings(report, kind))}"
      end

      assert Report.findings(report, :content_changed) == []

      counts = %{
        User => 2,
        Site => 2,
        SiteUser => 3,
        Invitation => 1,
        SocialMediaLink => 2,
        ApiToken => 1,
        Image => 4,
        Post => 2,
        Page => 4,
        Project => 1,
        Book => 2,
        NavigationItem => 2,
        DeploymentTarget => 2
      }

      for {schema, count} <- counts,
          do: assert(Repo.aggregate(schema, :count) == count, inspect(schema))

      assert Report.format(report) =~ "posts"
    end

    test "keeps ids, public ids and timestamps with microseconds" do
      import!()

      admin = Repo.get!(User, "66b355ad-332b-469f-8843-68cc9bbb82e3")
      assert admin.email == "admin@example.com"
      assert admin.super_admin
      assert admin.inserted_at == ~U[2026-10-06 18:09:30.919627Z]
      assert admin.confirmed_at == ~U[2026-10-06 18:09:30Z]
      refute Repo.get_by!(User, email: "editor@example.com").super_admin

      post = Repo.get!(Post, @post_id)
      assert post.public_id == "1yQSJLfwG9dV"
      assert post.slug == "/review-pragmatic-programmer"
      assert post.publish_at == ~U[2026-03-15 09:30:00.123456Z]
      assert post.inserted_at == ~U[2026-10-06 18:09:33.340415Z]
      assert post.updated_at == ~U[2026-10-06 18:09:33.340415Z]
      assert Repo.get!(PostVersion, post.published_version_id).number == 1
      assert post.tags == "books, programming"

      assert Enum.map(post.content, & &1["type"]) ==
               ~w(paragraph header list quote code image table embed book)

      draft = Repo.get_by!(Post, public_id: "P37Hnj7PbXtN")
      assert draft.published_version_id == nil

      book = Repo.get!(Book, @book_id)
      assert book.read_at == ~D[2026-03-14]
      assert book.rating == 5
      assert book.updated_at == ~U[2026-10-06 18:09:33.420318Z]

      project = Repo.get_by!(Project, public_id: "1LLmfEq3NVn6")
      assert project.started_at == ~D[2023-05-01]
      assert project.project_type == "open_source"
      assert [%{label: "GitHub"}, %{label: "Website"}] = project.links

      assert Repo.get_by!(Page, public_id: "JY34se6a7ajW").page_type == "books"
    end

    test "links memberships, invitations, images, books and the navigation" do
      import!()

      roles =
        Repo.all(from su in SiteUser, where: su.site_id == ^@notes_site, select: su.role)
        |> Enum.sort()

      assert roles == ~w(admin editor)

      invitation = Repo.one!(Invitation)
      assert invitation.email == "pending@example.com"
      assert invitation.site_id == @notes_site
      refute invitation.accepted_at

      post = Repo.get!(Post, @post_id)
      assert Repo.get!(Image, post.header_image_id).public_id == "x3BP8Cxu2hMa"
      assert Repo.get!(Image, post.thumbnail_image_id).public_id == "5olRHPvR0D5N"

      inline = Repo.get_by!(Image, public_id: "DrqGSEC4zyvZ")
      assert inline.post_id == @post_id

      book = Repo.get!(Book, @book_id)
      assert book.post_id == @post_id
      assert Repo.get!(Image, book.cover_image_id).public_id == "XBOKyjLaiLsB"

      unsplash = Repo.get_by!(Image, public_id: "5olRHPvR0D5N")
      assert unsplash.source_url == "https://images.unsplash.com/photo-123"
      assert Image.unsplash_photographer_name(unsplash) == "Jane Doe"

      navigation =
        Repo.all(
          from n in NavigationItem,
            join: p in assoc(n, :page),
            where: n.site_id == ^@notes_site,
            order_by: n.position,
            select: {n.position, p.slug}
        )

      assert navigation == [{1, "/about"}, {2, "/books"}]
    end

    test "copies the originals and generates every variant" do
      import!()

      for public_id <- @image_public_ids do
        image = Repo.get_by!(Image, public_id: public_id)
        assert File.exists?(Media.original_path(image)), public_id

        for variant <- Variants.all() do
          assert File.exists?(Media.variant_path(image, variant.name)),
                 "#{public_id} #{variant.filename}"
        end
      end

      header = Repo.get_by!(Image, public_id: "x3BP8Cxu2hMa")
      assert {header.width, header.height} == {8, 6}
      assert header.content_type == "image/png"
      assert header.filename == "header.png"
      assert header.byte_size == 145
      assert Path.basename(Media.original_path(header)) == "original.png"
    end

    test "encrypts the deployment config" do
      import!()

      target = Repo.get_by!(DeploymentTarget, public_id: "XhultPlcTLZt")

      assert target.config == %{
               "host" => "ftp.example.com",
               "user" => "u12345",
               "password" => "fixture-password",
               "path" => "/public_html"
             }

      refute target.deploying
      assert target.type == "production"
      assert target.provider == "hetzner_ftps"

      %{rows: [[raw]]} =
        Repo.query!("SELECT config FROM deployment_targets WHERE public_id = 'XhultPlcTLZt'")

      refute raw =~ "fixture-password"
      assert Repo.get_by!(DeploymentTarget, public_id: "XHg1jIOCeNoi").config == %{}
    end

    test "API tokens still authenticate" do
      import!()

      assert %User{email: "admin@example.com"} = Accounts.get_user_by_api_token(@api_token)
      assert [%ApiToken{name: "Test token", token_prefix: "f00df00d"}] = Repo.all(ApiToken)
    end
  end

  describe "exporting imported sites" do
    alias Feather.StaticSite.{Export, RecordingSink, Routes}

    @atelier_site "d2403fc6-a442-4bce-9f45-3c23e1b91b4a"

    defp export(site_id) do
      site = Repo.get!(Site, site_id)
      sink = RecordingSink.new()
      assert :ok = Export.run(site, Routes.new(site), sink, now: ~U[2026-10-06 19:00:00Z])
      sink
    end

    test "every imported site exports with its content and images" do
      import!()

      notes = export(@notes_site)

      for path <- ~w(index.html feed.xml sitemap.xml robots.txt
                     review-pragmatic-programmer/index.html about/index.html books/index.html
                     projects/feather-page/index.html) do
        assert RecordingSink.exists?(notes, path), "notes: #{path} missing"
      end

      refute RecordingSink.exists?(notes, "draft-post/index.html")

      for public_id <- @image_public_ids, variant <- Variants.all() do
        path = "images/#{public_id}/#{variant.filename}"
        image = Repo.get_by!(Image, public_id: public_id)

        assert RecordingSink.get(notes, path) == {:copy, Media.variant_path(image, variant.name)},
               "notes: #{path}"
      end

      post = RecordingSink.get(notes, "review-pragmatic-programmer/index.html")
      assert post =~ "Review: The Pragmatic Programmer"
      assert post =~ "images/DrqGSEC4zyvZ/"
      assert RecordingSink.get(notes, "feed.xml") =~ "review-pragmatic-programmer"
      assert RecordingSink.get(notes, "sitemap.xml") =~ "about/"

      atelier = export(@atelier_site)

      for path <- ~w(index.html feed.xml sitemap.xml robots.txt),
          do: assert(RecordingSink.exists?(atelier, path), "atelier: #{path} missing")

      refute Enum.any?(RecordingSink.paths(atelier), &String.starts_with?(&1, "images/"))
    end
  end

  describe "guard" do
    test "refuses to import into a database with data" do
      import!()
      assert RailsDump.run(@fixture) == {:error, :not_empty}

      user_fixture()
      assert {:ok, _report} = RailsDump.run(@fixture, force: true)
      assert Repo.aggregate(User, :count) == 2
      assert Repo.aggregate(Image, :count) == 4
      assert Repo.aggregate(NavigationItem, :count) == 2
    end

    test "refuses when only users exist" do
      user_fixture()
      assert RailsDump.run(@fixture) == {:error, :not_empty}
    end

    test "rejects a directory that is not a dump" do
      assert {:error, message} = RailsDump.run(Path.join(@fixture, "images"))
      assert message =~ "manifest.json"
      assert {:error, _} = RailsDump.run("/nonexistent/dump")
    end
  end

  describe "problems in the dump" do
    test "skips images without a usable file and drops references to them" do
      dir =
        dump_with(fn tables ->
          tables
          |> update_row(
            "images",
            "d9fe73ec-e149-4235-882a-8776e31b10c7",
            &Map.put(&1, "file", nil)
          )
          |> update_row("images", "19f506f3-e973-4e80-a099-204a6d317cc1", fn row ->
            put_in(row, ["file", "path"], nil)
          end)
          |> update_row("images", "a9745b0c-a649-4c50-b797-5c01238be26c", fn row ->
            put_in(row, ["file", "path"], "images/DrqGSEC4zyvZ/gone.jpg")
          end)
        end)

      report = import!(dir)

      assert length(Report.findings(report, :missing_file)) == 3
      assert report.counts["images"] == %{dumped: 4, imported: 1}

      post = Repo.get!(Post, @post_id)
      refute post.header_image_id
      refute post.thumbnail_image_id

      dangling = Report.findings(report, :dangling_reference)
      assert Enum.any?(dangling, &(&1 =~ "header_image_id"))
      assert Enum.any?(dangling, &(&1 =~ "image block references missing image DrqGSEC4zyvZ"))
    end

    test "imports records violating current validations and reports them" do
      dir =
        dump_with(fn tables ->
          update_row(tables, "sites", "d2403fc6-a442-4bce-9f45-3c23e1b91b4a", fn row ->
            Map.put(row, "language_code", "xx")
          end)
        end)

      report = import!(dir)

      assert Repo.get!(Site, "d2403fc6-a442-4bce-9f45-3c23e1b91b4a").language_code == "xx"
      assert [message] = Report.findings(report, :validation_bypassed)
      assert message =~ "atelier.example.de"
      assert message =~ "language_code"
    end

    test "imports a page with the slug of a published post as a draft and reports it" do
      dir =
        dump_with(fn tables ->
          update_row(tables, "posts", @post_id, &Map.put(&1, "slug", "/about"))
        end)

      report = import!(dir)

      page = Repo.get!(Page, "7ddf3ca5-baec-46b6-a5ae-ec42a4e281eb")
      assert page.slug == "/about"
      assert Feather.Content.draft?(page)
      refute Feather.Content.draft?(Repo.get!(Post, @post_id))

      assert [bypassed] = Report.findings(report, :validation_bypassed)
      assert bypassed =~ "page CTu6pDSKycJL (/about): slug has already been taken"
      assert Enum.any?(Report.findings(report, :notice), &(&1 =~ "(/about): not published"))
    end

    test "skips rows whose parent is missing" do
      dir =
        dump_with(fn tables ->
          tables
          |> update_row("site_users", 5, &Map.put(&1, "user_id", Ecto.UUID.generate()))
          |> update_row("navigation_items", "4ff363ab-f46f-4407-9ea9-00bfeda243af", fn row ->
            Map.put(row, "page_id", Ecto.UUID.generate())
          end)
          |> update_row("books", @book_id, &Map.put(&1, "post_id", Ecto.UUID.generate()))
        end)

      report = import!(dir)

      assert report.counts["site_users"] == %{dumped: 3, imported: 2}
      assert report.counts["navigation_items"] == %{dumped: 2, imported: 1}
      assert [%NavigationItem{position: 1}] = Repo.all(NavigationItem)
      refute Repo.get!(Book, @book_id).post_id
      assert length(Report.findings(report, :dangling_reference)) == 3
    end

    test "reports normalized content and gives unowned embedded images an owner" do
      dir =
        dump_with(fn tables ->
          tables
          |> update_row("images", "a9745b0c-a649-4c50-b797-5c01238be26c", fn row ->
            Map.merge(row, %{"imageable_type" => nil, "imageable_id" => nil})
          end)
          |> update_row("posts", @post_id, fn row ->
            Map.update!(row, "content", fn blocks ->
              blocks ++
                [
                  %{"id" => "old1", "type" => "warning", "text" => "gone"},
                  %{"id" => "hdr9", "type" => "header", "level" => 1, "text" => "Big"}
                ]
            end)
          end)
        end)

      report = import!(dir)

      assert [message] = Report.findings(report, :content_changed)
      assert message =~ "block old1 (warning) dropped"
      assert message =~ "block hdr9 (header) changed"

      post = Repo.get!(Post, @post_id)
      assert %{"level" => 2} = Enum.find(post.content, &(&1["id"] == "hdr9"))
      refute Enum.find(post.content, &(&1["id"] == "old1"))

      assert Repo.get_by!(Image, public_id: "DrqGSEC4zyvZ").post_id == @post_id
    end

    test "reports images the daily cleanup will delete" do
      dir =
        dump_with(fn tables ->
          update_row(tables, "posts", @post_id, fn row ->
            Map.update!(row, "content", &Enum.reject(&1, fn b -> b["type"] == "image" end))
          end)
        end)

      report = import!(dir, now: ~U[2026-10-10 00:00:00Z])

      assert Enum.any?(
               Report.findings(report, :notice),
               &(&1 =~ "DrqGSEC4zyvZ: not embedded by its owner")
             )
    end
  end
end
