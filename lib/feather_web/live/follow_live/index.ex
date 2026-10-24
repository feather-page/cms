defmodule FeatherWeb.FollowLive.Index do
  @moduledoc """
  The accounts the site's account follows, whose posts make up its
  Timeline, and its followers (`Feather.Fediverse.Following`), newest
  first, 20 per page (`?page=`), the followers with `?list=followers`.
  Members reach it from the Timeline, where they follow accounts.

  A follow its account has not accepted yet shows as requested.
  Unfollowing asks first.
  """
  use FeatherWeb, :live_view

  import FeatherWeb.FediverseComponents

  alias Feather.Fediverse
  alias Feather.Fediverse.{FollowedAccount, RemoteAccount}

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      unread_mentions={@site_unread_mentions}
      active={:timeline}
    >
      <.header back={~p"/sites/#{@site.public_id}/timeline"} back_label="Timeline">
        Following
        <:subtitle :if={@handle}>
          The accounts {@handle} follows, whose posts show in the Timeline, and its followers.
        </:subtitle>
        <:actions>
          <.segmented
            id="follow-list"
            mode={:patch}
            label="Show"
            size={:sm}
            value={@list}
            options={[
              {"Following", "following", following_path(@site, :following)},
              {"Followers", "followers", following_path(@site, :followers)}
            ]}
          />
        </:actions>
      </.header>

      <.empty_state
        :if={@pagination.total_entries == 0}
        id="no-accounts"
        icon="user-plus"
        title={empty_title(@list)}
      >
        {empty_text(@list)}
      </.empty_state>

      <.list id="accounts" phx-update="stream" class={@pagination.total_entries == 0 && "hidden"}>
        <li :for={{dom_id, account} <- @streams.accounts} id={dom_id} class="list-row items-center">
          <.account_row id={dom_id} account={account} site={@site} />
        </li>
      </.list>

      <.pagination pagination={@pagination} path={&following_path(@site, @list, &1)} />
    </.site_shell>
    """
  end

  attr :id, :string, required: true
  attr :account, :any, required: true
  attr :site, :map, required: true

  defp account_row(%{account: %FollowedAccount{}} = assigns) do
    ~H"""
    <.followed_picture site={@site} followed={@account} />
    <.account_name id={@id} account={@account.remote_account}>
      <.badge :if={!FollowedAccount.accepted?(@account)} tone={:warning}>Requested</.badge>
    </.account_name>
    <.button
      id={"#{@id}-unfollow"}
      size={:sm}
      phx-click="unfollow"
      phx-value-id={@account.id}
      confirm={"Unfollow #{author_address(@account.remote_account)}?"}
      confirm_text="Its posts leave the Timeline."
      confirm_label="Unfollow"
    >
      Unfollow
    </.button>
    """
  end

  defp account_row(%{account: %RemoteAccount{}} = assigns) do
    ~H"""
    <.avatar initials={initials(author_name(@account))} shape={:round} size={:sm} tone={:base} />
    <.account_name id={@id} account={@account} />
    """
  end

  attr :id, :string, required: true
  attr :account, RemoteAccount, required: true
  slot :inner_block

  defp account_name(assigns) do
    ~H"""
    <p id={"#{@id}-name"} class="list-col-grow flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
      <a
        href={@account.uri}
        target="_blank"
        rel="noopener noreferrer"
        class="link link-hover font-medium wrap-anywhere"
      >
        {author_name(@account)}
      </a>
      <span class="text-sm text-base-content/70 wrap-anywhere">{author_address(@account)}</span>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    site = socket.assigns.current_scope.site

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:handle, Fediverse.handle(site))
     |> assign(:page_title, "Following")
     |> stream_configure(:accounts, dom_id: &dom_id/1)}
  end

  defp dom_id(%FollowedAccount{id: id}), do: "followed-#{id}"
  defp dom_id(%RemoteAccount{id: id}), do: "follower-#{id}"

  @impl true
  def handle_params(params, _uri, socket) do
    list = if params["list"] == "followers", do: :followers, else: :following

    {:noreply,
     socket
     |> assign(:list, list)
     |> load_accounts(params["page"])}
  end

  @impl true
  def handle_event("unfollow", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    followed = Fediverse.get_followed_account!(scope, id)
    :ok = Fediverse.unfollow(scope, followed)

    {:noreply,
     socket
     |> load_accounts(socket.assigns.pagination.page)
     |> put_flash(:info, "Unfollowed #{author_address(followed.remote_account)}.")}
  end

  defp load_accounts(socket, page) do
    scope = socket.assigns.current_scope

    pagination =
      case socket.assigns.list do
        :following -> Fediverse.paginate_followed_accounts(scope, page)
        :followers -> Fediverse.paginate_followers(scope, page)
      end

    socket
    |> assign(:pagination, pagination)
    |> stream(:accounts, pagination.entries, reset: true)
  end

  defp following_path(site, list, page \\ 1) do
    params = [list: if(list == :followers, do: list), page: if(page > 1, do: page)]

    case Enum.reject(params, fn {_key, value} -> is_nil(value) end) do
      [] -> ~p"/sites/#{site.public_id}/following"
      query -> ~p"/sites/#{site.public_id}/following?#{query}"
    end
  end

  defp empty_title(:following), do: "Not following anyone yet"
  defp empty_title(:followers), do: "No followers yet"

  defp empty_text(:following), do: "Follow accounts in the Timeline to read their posts there."

  defp empty_text(:followers),
    do: "People in the fediverse who follow the site's handle show up here."
end
