defmodule FeatherWeb.ProjectLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorHelpers

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
    |> render_change()

    [project] = Content.list_projects(scope)
    assert project.title == "Feather"
    assert project.project_type == "open_source"
    assert Enum.map(project.links, & &1.label) == ["Code", "Site"]
    assert Content.draft?(project)
    assert_patch(lv, projects_path(site) <> "/#{project.public_id}/edit")

    lv
    |> element("#project-content-editor")
    |> render_hook(
      "sync",
      sync_params(project, ["block00001"], [paragraph_node("block00001", "All about it")])
    )

    assert_reply(lv, %{status: "saved"})
    assert [%{"text" => "All about it"}] = Feather.Repo.reload!(project).content
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
    lv |> form("#project-form") |> render_change(%{"project" => %{"links_drop" => ["0"]}})
    refute has_element?(lv, "#project-link-1")

    assert [%{label: "Two"}] = Content.get_project!(scope, project.public_id).links
  end

  test "a new project is created only once its required fields are valid", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/new")

    html = lv |> form("#project-form", project: %{title: "Only a title"}) |> render_change()

    assert html =~ "can&#39;t be blank"
    assert has_element?(lv, ~s(#project-content-editor[data-form-status="invalid"]))
    assert Content.list_projects(scope) == []
  end

  test "an invalid field is not saved while the valid ones are", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    project = project_fixture(scope, title: "Old", company: "ACME")
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/#{project.public_id}/edit")

    lv
    |> form("#project-form", project: %{title: "", company: "Feather Inc."})
    |> render_change()

    assert has_element?(lv, "#project-form .invalid-feedback", "can't be blank")
    assert has_element?(lv, "#publish-project[disabled]")

    assert %{title: "Old", company: "Feather Inc."} =
             Content.get_project!(scope, project.public_id)
  end

  test "unpublishes a project", %{conn: conn, site: site, scope: scope} do
    project = project_fixture(scope, title: "Old project")
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/#{project.public_id}/edit")
    refute has_element?(lv, "#publication-badge")

    lv |> element("#unpublish-project") |> render_click()

    assert has_element?(lv, "#publication-badge", "Draft")
    refute has_element?(lv, "#unpublish-project")
    assert Content.draft?(Content.get_project!(scope, project.public_id))
  end

  test "publishes and discards the changes of a project", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    project = project_fixture(scope, title: "Old project")
    edit_path = projects_path(site) <> "/#{project.public_id}/edit"
    {:ok, lv, _html} = live(conn, edit_path)
    assert has_element?(lv, "#version-1", "Published")

    lv |> form("#project-form", project: %{title: "New project"}) |> render_change()

    html =
      lv |> element("#project-content-editor") |> render_hook("publish", %{"editor" => "saved"})

    assert html =~ "Project was published."
    assert has_element?(lv, "#version-2", "Published")

    {:ok, _project} =
      Content.update_project(scope, Content.get_project!(scope, project.public_id), %{
        title: "Draft"
      })

    {:ok, lv, _html} = live(conn, edit_path)
    assert has_element?(lv, "#publication-badge", "Unpublished changes")

    {:ok, _lv, _html} =
      lv |> element("#discard-project") |> render_click() |> follow_redirect(conn, edit_path)

    assert Content.get_project!(scope, project.public_id).title == "New project"
  end

  test "restores an earlier version of a project", %{conn: conn, site: site, scope: scope} do
    project = project_fixture(scope, title: "Old project")
    {:ok, project} = Content.update_project(scope, project, %{title: "New project"})
    {:ok, project} = Content.publish(scope, project)
    edit_path = projects_path(site) <> "/#{project.public_id}/edit"
    {:ok, lv, _html} = live(conn, edit_path)

    {:ok, lv, _html} =
      lv |> element("#restore-version-1") |> render_click() |> follow_redirect(conn, edit_path)

    assert has_element?(lv, "#project_title[value='Old project']")
    assert has_element?(lv, "#version-2", "Published")
  end

  test "shows the status and deletes the project from its edit page", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    project = project_fixture(scope, title: "Old project", status: "completed")
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/#{project.public_id}/edit")

    assert has_element?(lv, "h1", "Old project")
    assert has_element?(lv, "#status-badge", "Completed")

    {:ok, _lv, html} =
      lv
      |> element("#delete-project")
      |> render_click()
      |> follow_redirect(conn, projects_path(site))

    assert html =~ "The project was successfully deleted."
    assert_raise Ecto.NoResultsError, fn -> Content.get_project!(scope, project.public_id) end
  end

  test "a project of another site is not found", %{conn: conn, site: site} do
    other = project_fixture(site_scope_fixture())

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, projects_path(site) <> "/#{other.public_id}/edit")
    end
  end

  test "autosaves the content of a project", %{conn: conn, site: site, scope: scope} do
    project = project_fixture(scope, content: [paragraph("Built")])
    [%{"id" => id}] = project.content
    {:ok, lv, _html} = live(conn, projects_path(site) <> "/#{project.public_id}/edit")

    lv
    |> element("#project-content-editor")
    |> render_hook("sync", sync_params(project, nil, [paragraph_node(id, "Built it")]))

    assert_reply(lv, %{status: "saved"})
    assert [%{"text" => "Built it"}] = Feather.Repo.reload!(project).content
  end
end
