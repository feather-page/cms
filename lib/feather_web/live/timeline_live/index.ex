defmodule FeatherWeb.TimelineLive.Index do
  @moduledoc """
  The Timeline of the site's account (`Feather.Fediverse.Timeline`): the
  posts of the accounts it follows, newest first, 20 per page (`?page=`).
  New posts appear on the first page as they come, pushing its oldest
  off, changed ones change and removed ones go.

  Members follow accounts in a dialog the header's button opens, by their
  handles, several at once, such as the list of the accounts they followed
  on micro.blog (`Feather.Fediverse.Following`). The handles are looked up
  in the background; the dialog closes when all were followed, otherwise
  it says which could not be followed and why, and keeps them in the
  field. The numbers of followed accounts and followers lead to their
  lists (`FeatherWeb.FollowLive.Index`).

  Each post shows its author's picture, name and verified handle, when it
  was published, its title, content warning and content (sanitized
  again), its pictures and other attachments and a link to it on its
  server. Pictures load through the CMS
  (`FeatherWeb.FediversePictureController`), so the servers do not see the
  members' addresses. Members answer a post as they answer mentions, in
  the background (`Feather.Fediverse.MemberReplies`); their replies show
  below it. The menu of a post blocks its author or its author's server
  (`Feather.Fediverse.Blocks`), which also unfollows them.
  """
  use FeatherWeb, :live_view

  import FeatherWeb.FediverseComponents

  alias Feather.Content.HTML
  alias Feather.Fediverse
  alias Feather.Fediverse.{Block, TimelinePost}

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
      <.header>
        Timeline
        <:badge>
          <.badge tone={:success} style={:dot}>Live</.badge>
        </:badge>
        <:subtitle :if={@handle}>
          Posts of the accounts {@handle} follows. Kept for 30 days.
        </:subtitle>
        <:actions>
          <.button id="open-follow" icon="user-plus" phx-click="open_follow">
            Follow accounts
          </.button>
        </:actions>
      </.header>

      <.modal
        id="follow-dialog"
        title="Follow accounts"
        show={@follow_dialog?}
        on_cancel={JS.push("close_follow")}
        close_label="Close"
      >
        <.form for={@follow_form} id="follow-form" phx-submit="follow" class="grid gap-2">
          <.input
            field={@follow_form[:handles]}
            type="textarea"
            label="Handles"
            rows="4"
            placeholder="@ana@example.social"
            help="One handle per line: paste the list from micro.blog to follow everyone at once."
            required
          />
        </.form>

        <.alert
          :if={@failures != []}
          id="follow-failures"
          tone={:warning}
          title="These accounts could not be followed"
          class="mt-4"
        >
          <ul class="grid gap-1">
            <li :for={{handle, reason} <- @failures} class="wrap-anywhere">
              {handle}: {failure_text(reason)}
            </li>
          </ul>
        </.alert>

        <:actions>
          <.button type="button" phx-click={hide_modal("follow-dialog")}>Cancel</.button>
          <.button
            type="submit"
            form="follow-form"
            variant={:primary}
            icon="user-plus"
            loading={@following?}
            disabled={@following?}
          >
            Follow
          </.button>
        </:actions>
      </.modal>

      <p id="timeline-stats" class="flex flex-wrap gap-x-4 gap-y-1 text-sm text-base-content/70">
        <span><b class="text-base-content">{@following_count}</b> following</span>
        <span><b class="text-base-content">{@follower_count}</b> {followers(@follower_count)}</span>
        <.link navigate={~p"/sites/#{@site.public_id}/following"} class="link">Manage</.link>
      </p>

      <.empty_state :if={@empty?} id="no-timeline-posts" icon="newspaper" title="Nothing here yet">
        Follow accounts, and their posts show up here as they come.
      </.empty_state>

      <.list id="timeline" phx-update="stream" class={["mt-4", @empty? && "hidden"]}>
        <li :for={{dom_id, post} <- @streams.posts} id={dom_id} class="list-row items-start">
          <.followed_picture site={@site} followed={post.followed_account} />
          <div class="list-col-grow grid min-w-0 gap-2">
            <p id={"#{dom_id}-author"} class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
              <span class="font-medium wrap-anywhere">
                {author_name(post.followed_account.remote_account)}
              </span>
              <span class="text-base-content/70 wrap-anywhere">
                {author_address(post.followed_account.remote_account)}
              </span>
              <time datetime={DateTime.to_iso8601(post.published_at)} class="text-base-content/70">
                {time_ago(post.published_at)}
              </time>
              <.badge :if={post.visibility == :followers} style={:plain}>Followers only</.badge>
            </p>
            <h2 :if={post.name} id={"#{dom_id}-name"} class="font-semibold wrap-anywhere">
              {post.name}
            </h2>
            <details :if={post.summary} id={"#{dom_id}-summary"}>
              <summary class="cursor-pointer text-sm font-medium wrap-anywhere">
                {post.summary}
              </summary>
              <.post_body id={"#{dom_id}-content"} post={post} site={@site} />
            </details>
            <.post_body :if={!post.summary} id={"#{dom_id}-content"} post={post} site={@site} />
            <.member_replies
              id={"#{dom_id}-member-replies"}
              replies={post.member_replies}
              site_title={@site.title}
            />
            <details id={"#{dom_id}-reply"} phx-mounted={JS.ignore_attributes(["open"])}>
              <summary class="flex list-none flex-wrap items-center gap-x-4 gap-y-1 text-sm text-base-content/70 [&::-webkit-details-marker]:hidden">
                <span class="link link-hover flex cursor-pointer items-center gap-1">
                  <.icon name="reply" class="size-4" /> Reply
                </span>
                <a
                  href={post.url || post.uri}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="link link-hover flex items-center gap-1"
                >
                  <.icon name="external-link" class="size-4" /> Open on its server
                </a>
              </summary>
              <div class="mt-2">
                <.reply_form
                  id={dom_id}
                  name="timeline_post_id"
                  value={post.id}
                  audience={reply_audience(post)}
                  draft={Map.get(@drafts, post.id, "")}
                  sending={MapSet.member?(@sending, post.id)}
                />
              </div>
            </details>
          </div>
          <.entry_menu
            :if={@handle}
            id={"#{dom_id}-menu"}
            entry_id={post.id}
            author={post.followed_account.remote_account}
          />
        </li>
      </.list>

      <.pagination pagination={@pagination} path={&timeline_path(@site, &1)} />
    </.site_shell>
    """
  end

  attr :id, :string, required: true
  attr :post, TimelinePost, required: true
  attr :site, :map, required: true

  defp post_body(assigns) do
    ~H"""
    <div class="grid gap-2">
      <div id={@id} class="wrap-anywhere [&_a[href]]:link">
        {raw(HTML.sanitize(@post.content, :remote))}
      </div>
      <div
        :if={pictures(@post) != []}
        class={["grid gap-2", length(pictures(@post)) > 1 && "grid-cols-2"]}
      >
        <img
          :for={{attachment, index} <- pictures(@post)}
          src={~p"/sites/#{@site.public_id}/timeline/#{@post.public_id}/pictures/#{index}"}
          alt={attachment["name"] || ""}
          loading="lazy"
          class="max-h-80 w-full rounded-box bg-base-200 object-contain"
        />
      </div>
      <ul :if={other_attachments(@post) != []} class="grid gap-1 text-sm">
        <li :for={attachment <- other_attachments(@post)}>
          <a
            href={attachment["url"]}
            target="_blank"
            rel="noopener noreferrer"
            class="link flex items-center gap-1 wrap-anywhere"
          >
            <.icon name="external-link" class="size-4 shrink-0" />
            {attachment["name"] || "Attachment without description"}
          </a>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    site = scope.site

    if connected?(socket) and Fediverse.account?(site), do: Fediverse.subscribe_timeline(scope)

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:handle, Fediverse.handle(site))
     |> assign(:page_title, "Timeline")
     |> assign(:following?, false)
     |> assign(:follow_dialog?, false)
     |> assign(:failures, [])
     |> assign(:follower_count, Fediverse.count_followers(scope))
     |> assign(:following_count, Fediverse.count_following(scope))
     |> assign_follow_form("")
     |> assign(:sending, MapSet.new())
     |> assign(:drafts, %{})
     |> stream_configure(:posts, dom_id: &"timeline-post-#{&1.id}")}
  end

  defp assign_follow_form(socket, text),
    do: assign(socket, :follow_form, to_form(%{"handles" => text}, as: :follow))

  @impl true
  def handle_params(params, _uri, socket), do: {:noreply, load_posts(socket, params["page"])}

  defp load_posts(socket, page) do
    pagination = Fediverse.paginate_timeline(socket.assigns.current_scope, page)

    socket
    |> assign(:pagination, pagination)
    |> assign(:empty?, pagination.entries == [])
    |> assign(:post_ids, Enum.map(pagination.entries, & &1.id))
    |> stream(:posts, pagination.entries, reset: true)
  end

  @impl true
  def handle_event("open_follow", _params, socket),
    do: {:noreply, assign(socket, :follow_dialog?, true)}

  def handle_event("close_follow", _params, socket),
    do: {:noreply, socket |> assign(:follow_dialog?, false) |> assign(:failures, [])}

  def handle_event("follow", %{"follow" => %{"handles" => text}}, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:following?, true)
     |> assign_follow_form(text)
     |> start_async(:follow, fn -> Fediverse.follow(scope, text) end)}
  end

  def handle_event("reply", %{"timeline_post_id" => id, "reply" => attrs}, socket) do
    scope = socket.assigns.current_scope
    post = Fediverse.get_timeline_post!(scope, id)

    if MapSet.member?(socket.assigns.sending, post.id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> update(:sending, &MapSet.put(&1, post.id))
       |> update(:drafts, &Map.put(&1, post.id, attrs["content"] || ""))
       |> stream_insert(:posts, post)
       |> start_async({:reply, post.id}, fn ->
         Fediverse.reply_to_timeline_post(scope, post, attrs)
       end)}
    end
  end

  def handle_event("delete_reply", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    reply = Fediverse.get_member_reply!(scope, id)
    :ok = Fediverse.delete_member_reply(scope, reply)

    {:noreply,
     socket
     |> refresh_post(reply.timeline_post_id)
     |> put_flash(:info, "Reply deleted.")}
  end

  def handle_event("block_account", %{"id" => id}, socket), do: block(socket, id, :account)
  def handle_event("block_server", %{"id" => id}, socket), do: block(socket, id, :server)

  defp block(socket, id, what) do
    scope = socket.assigns.current_scope
    post = Fediverse.get_timeline_post!(scope, id)
    {:ok, block} = Fediverse.block(scope, post.followed_account.remote_account, what)

    {:noreply,
     socket
     |> load_posts(socket.assigns.pagination.page)
     |> assign(:follower_count, Fediverse.count_followers(scope))
     |> assign(:following_count, Fediverse.count_following(scope))
     |> put_flash(:info, "Blocked #{Block.name(block)}.")}
  end

  @impl true
  def handle_async(:follow, {:ok, {:ok, results}}, socket) do
    failures = for {handle, {:error, reason}} <- results, do: {handle, reason}
    followed = length(results) - length(failures)

    socket =
      socket
      |> assign(:following?, false)
      |> assign(:follow_dialog?, failures != [])
      |> assign(:failures, failures)
      |> assign(:following_count, Fediverse.count_following(socket.assigns.current_scope))
      |> assign_follow_form(Enum.map_join(failures, "\n", &elem(&1, 0)))

    {:noreply,
     if(followed > 0, do: put_flash(socket, :info, followed_text(followed)), else: socket)}
  end

  def handle_async(:follow, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:following?, false)
     |> put_flash(:error, refusal_text(reason))}
  end

  def handle_async(:follow, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:following?, false)
     |> put_flash(:error, "Following failed. Please try again.")}
  end

  def handle_async({:reply, id}, result, socket) do
    socket = update(socket, :sending, &MapSet.delete(&1, id))

    socket =
      case result do
        {:ok, {:ok, _reply}} ->
          socket
          |> update(:drafts, &Map.delete(&1, id))
          |> put_flash(:info, "Reply sent.")

        {:ok, {:error, reason}} ->
          put_flash(socket, :error, reply_error_message(reason))

        {:exit, _reason} ->
          put_flash(socket, :error, "Sending the reply failed. Please try again.")
      end

    {:noreply, refresh_post(socket, id)}
  end

  @impl true
  def handle_info({:timeline_post, :created, id}, socket) do
    if socket.assigns.pagination.page == 1 do
      case Fediverse.get_timeline_post(socket.assigns.current_scope, id) do
        nil ->
          {:noreply, socket}

        post ->
          per_page = socket.assigns.pagination.per_page

          {:noreply,
           socket
           |> assign(:empty?, false)
           |> update(:post_ids, &Enum.take([id | List.delete(&1, id)], per_page))
           |> stream_insert(:posts, post, at: 0, limit: per_page)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:timeline_post, :updated, id}, socket),
    do: {:noreply, refresh_post(socket, id)}

  def handle_info({:timeline_post, :deleted, id}, socket) do
    post_ids = List.delete(socket.assigns.post_ids, id)

    {:noreply,
     socket
     |> assign(post_ids: post_ids, empty?: post_ids == [])
     |> stream_delete_by_dom_id(:posts, "timeline-post-#{id}")}
  end

  defp refresh_post(socket, id) do
    with true <- id in socket.assigns.post_ids,
         %TimelinePost{} = post <- Fediverse.get_timeline_post(socket.assigns.current_scope, id) do
      stream_insert(socket, :posts, post)
    else
      _not_shown -> socket
    end
  end

  defp timeline_path(site, 1), do: ~p"/sites/#{site.public_id}/timeline"
  defp timeline_path(site, page), do: ~p"/sites/#{site.public_id}/timeline?#{[page: page]}"

  defp pictures(post) do
    post.attachments
    |> Enum.with_index()
    |> Enum.filter(fn {attachment, _index} -> picture?(attachment) end)
  end

  defp other_attachments(post), do: Enum.reject(post.attachments, &picture?/1)

  defp picture?(attachment) do
    case attachment["media_type"] do
      nil -> true
      media_type -> String.starts_with?(media_type, "image/")
    end
  end

  defp reply_audience(%TimelinePost{visibility: :public} = post) do
    recipients = reply_recipients(post.followed_account.remote_account, post.named_accounts)
    "Public: goes to #{recipients} and the site's followers."
  end

  defp reply_audience(%TimelinePost{} = post) do
    named = Fediverse.remote_account_addresses(post.named_accounts)
    "Private: goes only to #{private_recipients(post.followed_account.remote_account, named)}."
  end

  defp followers(1), do: "follower"
  defp followers(_count), do: "followers"

  defp followed_text(1), do: "Followed 1 account. Its posts show up here from now on."

  defp followed_text(count),
    do: "Followed #{count} accounts. Their posts show up here from now on."

  defp failure_text(:invalid_handle), do: "not a handle like @name@example.social"
  defp failure_text(:not_found), do: "no account found"
  defp failure_text(:own_account), do: "the site's own account"
  defp failure_text(:blocked), do: "blocked in the site's settings"

  defp refusal_text(:no_handles), do: "Enter one or more handles like @name@example.social."
  defp refusal_text(:too_many_handles), do: "Follow at most 200 accounts at once."
  defp refusal_text(:not_an_account), do: "Give the site a fediverse name in its settings first."
end
