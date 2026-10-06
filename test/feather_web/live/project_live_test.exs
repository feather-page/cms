defmodule FeatherWeb.ProjectLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorJsHelpers

  alias Feather.Content

  setup [:register_and_log_in_user, :create_site_for_user]

  defp projects_path(site), do: ~p"/sites/#{site.public_id}/projects"

  test "shows an empty state", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, projects_path(site))
    assert has_element?(lv, "#no-projects")
  end

  test "lists projects by start date, newest first", %{conn: conn, site: site, scope: scope} do
    old = project_fixture(scope, title: "Old", started_at: ~D[2019-01-01], company: "ACME")
    new = project_fixture(scope, title: "New", started_at: ~D[2024-01-01], status: "completed")

    {:ok, lv, html} = live(conn, projects_path(site))

    assert has_element?(lv, "#project-#{old.public_id}", "ACME")
    assert has_element?(lv, "#project-#{new.public_id}", "Completed")

    ids = Regex.scan(~r/id="project-([0-9a-zA-Z]{12})"/, html) |> Enum.map(&List.last/1)
    assert ids == [new.public_id, old.public_id]
  end

  test "deletes a project", %{conn: conn, site: site, scope: scope} do
    project = project_fixture(scope)
    {:ok, lv, _html} = live(conn, projects_path(site))

    lv |> element("#delete-project-#{project.public_id}") |> render_click()

    refute has_element?(lv, "#project-#{project.public_id}")
    assert Content.list_projects(scope) == []
  end

  test "creates a project with links", %{conn: conn, site: site, scope: scope} do
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/new")

    # The "Add Link" button sends its name and value with a change event.
    assert has_element?(lv, ~s(#add-link[name="project[links_sort][]"][value="new"]))
    lv |> element("#project-form") |> render_change(%{"project" => %{"links_sort" => ["new"]}})
    assert has_element?(lv, "#project-link-0")

    lv
    |> element("#project-form")
    |> render_change(%{"project" => %{"links_sort" => ["0", "new"]}})

    assert has_element?(lv, "#project-link-1")

    lv
    |> form("#project-form",
      project: %{
        title: "Feather",
        slug: "/feather",
        company: "Me",
        started_at: "2024-03-01",
        status: "ongoing",
        project_type: "open_source",
        short_description: "A CMS.",
        links: %{
          "0" => %{label: "Code", url: "https://github.com/feather-page/cms"},
          "1" => %{label: "Site", url: "https://feather.page"}
        }
      }
    )
    |> render_submit(%{"project" => %{"content" => editor_json("All about it")}})

    [project] = Content.list_projects(scope)
    assert project.title == "Feather"
    assert project.project_type == "open_source"
    assert Enum.map(project.links, & &1.label) == ["Code", "Site"]
    assert [%{"text" => "All about it"}] = project.content
  end

  test "removes a link", %{conn: conn, site: site, scope: scope} do
    project =
      project_fixture(scope,
        links: [
          %{label: "One", url: "https://one.example"},
          %{label: "Two", url: "https://two.example"}
        ]
      )

    {:ok, lv, _html} = live(conn, projects_path(site) <> "/#{project.public_id}/edit")
    # The "Remove" button sends its name and value with a change event.
    assert has_element?(lv, ~s(#remove-link-0[name="project[links_drop][]"][value="0"]))
    lv |> element("#project-form") |> render_change(%{"project" => %{"links_drop" => ["0"]}})
    refute has_element?(lv, "#project-link-1")

    lv |> form("#project-form") |> render_submit()

    assert [%{label: "Two"}] = Content.get_project!(scope, project.public_id).links
  end

  test "shows validation errors", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/new")

    html = lv |> form("#project-form", project: %{title: "Only a title"}) |> render_submit()
    assert html =~ "can&#39;t be blank"
  end

  test "a project of another site is not found", %{conn: conn, site: site} do
    other = project_fixture(site_scope_fixture())

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, projects_path(site) <> "/#{other.public_id}/edit")
    end
  end
end
