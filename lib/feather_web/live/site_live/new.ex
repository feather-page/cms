defmodule FeatherWeb.SiteLive.New do
  @moduledoc """
  Creates a site: title, domain and language. The creator becomes a
  member; the site gets a homepage and a staging target
  (`Feather.Sites.create_site/2`).
  """
  use FeatherWeb, :live_view

  alias Feather.Sites
  alias Feather.Sites.{Languages, Site}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header back={~p"/"} back_label="Sites">New site</.header>

      <.form
        for={@form}
        id="site-form"
        class="form-narrow"
        phx-change="validate"
        phx-submit="save"
      >
        <div class="row g-3">
          <div class="col-12">
            <.input
              field={@form[:title]}
              type="text"
              label="Title"
              placeholder="Timon's Blog"
              wrapper_class={nil}
            />
          </div>
          <div class="col-12 col-sm-8">
            <.input
              field={@form[:domain]}
              type="text"
              label="Domain"
              placeholder="timon.blog"
              help="Without https://"
              wrapper_class={nil}
            />
          </div>
          <div class="col-12 col-sm-4">
            <.input
              field={@form[:language_code]}
              type="select"
              label="Language"
              options={Languages.options()}
              wrapper_class={nil}
            />
          </div>
        </div>
        <.action_bar>
          <.button variant="primary" phx-disable-with="Creating...">Create site</.button>
          <.link navigate={~p"/"} class="btn btn-light">Cancel</.link>
        </.action_bar>
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
         |> push_navigate(to: ~p"/sites/#{site.public_id}/posts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end
end
