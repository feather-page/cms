defmodule FeatherWeb.SiteLive.New do
  @moduledoc """
  Creates a site: title, domain and language. The creator becomes a
  member; the site gets a homepage and a staging target
  (`Feather.Sites.create_site/2`).
  """
  use FeatherWeb, :live_view

  alias Feather.Sites
  alias Feather.Sites.{Languages, Site}
  alias FeatherWeb.SiteAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>New site</.header>

      <.form for={@form} id="site-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" placeholder="Timon's Blog" />
        <div class="row">
          <div class="col-md">
            <.input
              field={@form[:domain]}
              type="text"
              label="Domain"
              placeholder="timon.blog"
              help="Without https://, for example timon.blog"
            />
          </div>
          <div class="col-md">
            <.input
              field={@form[:language_code]}
              type="select"
              label="Language"
              options={Languages.options()}
            />
          </div>
        </div>
        <div class="d-flex gap-2">
          <.button variant="primary" phx-disable-with="Creating...">Create site</.button>
          <.button navigate={~p"/"}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New site")
     |> assign(:form, to_form(Sites.change_site(%Site{})))}
  end

  @impl true
  def handle_event("validate", %{"site" => params}, socket) do
    changeset = Sites.change_site(%Site{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"site" => params}, socket) do
    case Sites.create_site(socket.assigns.current_scope, params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Site was successfully created.")
         |> push_navigate(to: SiteAuth.site_home_path(site))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end
end
