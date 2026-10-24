defmodule FeatherWeb.MentionLive.Index do
  @moduledoc """
  The Mentions of the site's account (`Feather.Fediverse.Mentions`):
  replies to its posts, mentions and private messages, newest first, 20
  per page (`?page=`), all, only the replies waiting for approval
  (`?filter=waiting`), which leave the list once approved or hidden, or
  only the private messages (`?filter=private`). "My replies"
  (`?filter=replies`) lists the members' replies instead, newest first,
  also those whose mention or Timeline post is gone: each with its
  audience, what it answers while that is still in the CMS, the post in
  whose thread it is and a button to delete it, so that no reply is out
  of reach.

  Each shows its author's name and verified handle, when it came, the post
  it answers, its content warning, its content (sanitized again), its
  attachments as links and a link to it on its server. Showing a page
  marks its mentions read; until then they are marked as new. A public
  reply to a post shows whether it waits for approval, is approved or
  hidden, with buttons to approve it, so that the site shows it below the
  post, or to hide it; both start a deploy where the site changes. Until
  it is approved, it shows its author's picture beside the name: what
  approving it puts on the site. That picture loads through the CMS
  (`FeatherWeb.FediversePictureController`), so the author's server does
  not learn the member's address; no other remote picture is loaded. A
  reply that changed since the page showed it, its author's name, handle
  or picture included, is not approved: the page shows it again for the
  member to review. An approved reply whose post was deleted can still be
  hidden, so that its author's picture goes with the next deploy.

  Members answer each mention in its reply field, which says where the
  reply goes: in public, or only to the accounts named in the mention
  (`Feather.Fediverse.MemberReplies`). Approving and sending a reply run
  in the background, their buttons busy meanwhile; a reply that could not
  be sent stays in its field. The members' replies to a mention
  show below it, each with a button to delete it. The menu of a mention
  blocks its author or its author's server (`Feather.Fediverse.Blocks`),
  whose mentions then leave the page.
  """
  use FeatherWeb, :live_view

  import FeatherWeb.FediverseComponents

  alias Feather.Content.HTML
  alias Feather.Fediverse
  alias Feather.Fediverse.{Block, MemberReply, Mention, TimelinePost}
  alias FeatherWeb.SiteAuth

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      unread_mentions={@site_unread_mentions}
      active={:mentions}
    >
      <.header>
        Mentions
        <:subtitle :if={@handle}>
          Replies to the site's posts, mentions of {@handle} and private messages.
        </:subtitle>
        <:actions>
          <.segmented
            id="mention-filter"
            mode={:patch}
            label="Show"
            size={:sm}
            value={@filter}
            options={[
              {"All", "all", mentions_path(@site, :all)},
              {"Waiting", "waiting", mentions_path(@site, :waiting)},
              {"Private messages", "private", mentions_path(@site, :private)},
              {"My replies", "replies", mentions_path(@site, :replies)}
            ]}
          />
        </:actions>
      </.header>

      <.my_replies
        :if={@filter == :replies}
        site={@site}
        replies={@streams.replies}
        empty?={@pagination.total_entries == 0}
      />

      <.empty_state
        :if={@filter != :replies and @pagination.total_entries == 0}
        id="no-mentions"
        icon="at-sign"
        title={empty_title(@filter)}
      >
        What people in the fediverse address to {@handle || "the site's account"} shows up here.
      </.empty_state>

      <.list
        :if={@filter != :replies}
        id="mentions"
        phx-update="stream"
        class={@pagination.total_entries == 0 && "hidden"}
      >
        <li
          :for={{dom_id, mention} <- @streams.mentions}
          id={dom_id}
          class="list-row items-start"
        >
          <.author_picture id={"#{dom_id}-picture"} site={@site} mention={mention} />
          <div class="list-col-grow grid min-w-0 gap-2">
            <p
              id={"#{dom_id}-author"}
              class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm"
            >
              <span class="font-medium wrap-anywhere">{author_name(mention.remote_account)}</span>
              <span class="text-base-content/70 wrap-anywhere">
                {author_address(mention.remote_account)}
              </span>
              <time
                datetime={DateTime.to_iso8601(mention.published_at)}
                class="text-base-content/70"
              >
                {time_ago(mention.published_at)}
              </time>
              <.badge :if={is_nil(mention.read_at)} tone={:info}>New</.badge>
              <.badge :if={mention.visibility == :direct} style={:plain} icon="mail">
                Private message
              </.badge>
              <.badge :if={mention.visibility == :followers} style={:plain}>Followers only</.badge>
            </p>
            <p :if={mention.post} id={"#{dom_id}-post"} class="text-sm text-base-content/70">
              Reply to
              <.link
                navigate={~p"/sites/#{@site.public_id}/posts/#{mention.post.public_id}/edit"}
                class="link"
              >
                {FeatherWeb.ContentForm.heading(mention.post, "(empty post)")}
              </.link>
            </p>
            <details :if={mention.summary} id={"#{dom_id}-summary"}>
              <summary class="cursor-pointer text-sm font-medium wrap-anywhere">
                {mention.summary}
              </summary>
              <.mention_body id={"#{dom_id}-content"} mention={mention} />
            </details>
            <.mention_body :if={!mention.summary} id={"#{dom_id}-content"} mention={mention} />
            <a
              href={mention.url || mention.uri}
              target="_blank"
              rel="noopener noreferrer"
              class="link link-hover flex items-center gap-1 text-sm text-base-content/70"
            >
              <.icon name="external-link" class="size-4" /> Open on its server
            </a>
            <div
              :if={Mention.approvable?(mention) or mention.approval == :approved}
              id={"#{dom_id}-approval"}
              class="flex flex-wrap items-center gap-2"
            >
              <.badge tone={approval_tone(mention.approval)}>
                {approval_label(mention.approval)}
              </.badge>
              <.button
                :if={mention.approval != :approved}
                id={"#{dom_id}-approve"}
                size={:sm}
                variant={:primary}
                icon="circle-check"
                phx-click="approve"
                phx-value-id={mention.id}
                phx-value-version={Mention.version(mention)}
                loading={MapSet.member?(@approving, mention.id)}
                phx-disable-with="Approving…"
              >
                Approve
              </.button>
              <.button
                :if={mention.approval != :hidden}
                id={"#{dom_id}-hide"}
                size={:sm}
                icon="eye-off"
                phx-click="hide"
                phx-value-id={mention.id}
              >
                Hide
              </.button>
            </div>
            <.member_replies
              id={"#{dom_id}-member-replies"}
              replies={mention.member_replies}
              site_title={@site.title}
            />
            <.reply_form
              id={dom_id}
              name="mention_id"
              value={mention.id}
              audience={reply_audience(mention)}
              draft={Map.get(@drafts, mention.id, "")}
              sending={MapSet.member?(@sending, mention.id)}
            />
          </div>
          <.entry_menu
            :if={@handle}
            id={"#{dom_id}-menu"}
            entry_id={mention.id}
            author={mention.remote_account}
          />
        </li>
      </.list>

      <.pagination pagination={@pagination} path={&mentions_path(@site, @filter, &1)} />
    </.site_shell>
    """
  end

  attr :site, :map, required: true
  attr :replies, :any, required: true
  attr :empty?, :boolean, required: true

  defp my_replies(assigns) do
    ~H"""
    <.empty_state :if={@empty?} id="no-replies" icon="reply" title="No replies yet">
      The replies members send from Mentions and the Timeline show up here.
    </.empty_state>

    <.list id="my-replies" phx-update="stream" class={@empty? && "hidden"}>
      <li :for={{dom_id, reply} <- @replies} id={dom_id} class="list-row items-start">
        <div class="list-col-grow grid min-w-0 gap-2">
          <p id={"#{dom_id}-meta"} class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
            <.badge :if={reply.visibility == :public} style={:plain} icon="globe">Public</.badge>
            <.badge :if={reply.visibility == :direct} style={:plain} icon="mail">Private</.badge>
            <time datetime={DateTime.to_iso8601(reply.inserted_at)} class="text-base-content/70">
              {time_ago(reply.inserted_at)}
            </time>
          </p>
          <p id={"#{dom_id}-answered"} class="text-sm text-base-content/70">{answered(reply)}</p>
          <p :if={reply.post} id={"#{dom_id}-post"} class="text-sm text-base-content/70">
            In the thread of
            <.link
              navigate={~p"/sites/#{@site.public_id}/posts/#{reply.post.public_id}/edit"}
              class="link"
            >
              {FeatherWeb.ContentForm.heading(reply.post, "(empty post)")}
            </.link>
          </p>
          <p id={"#{dom_id}-content"} class="whitespace-pre-line wrap-anywhere">{reply.content}</p>
          <a
            href={reply.in_reply_to}
            target="_blank"
            rel="noopener noreferrer"
            class="link link-hover flex items-center gap-1 text-sm text-base-content/70"
          >
            <.icon name="external-link" class="size-4" /> Open what it answers
          </a>
        </div>
        <.delete_reply_button id={"#{dom_id}-delete"} reply={reply} />
      </li>
    </.list>
    """
  end

  defp answered(%MemberReply{mention: %Mention{remote_account: author}}),
    do: "Reply to #{author_address(author)} in Mentions"

  defp answered(%MemberReply{timeline_post: %TimelinePost{followed_account: followed}}),
    do: "Reply to #{author_address(followed.remote_account)} in the Timeline"

  defp answered(%MemberReply{}), do: "Reply to a mention or Timeline post no longer in the CMS"

  attr :id, :string, required: true
  attr :site, :map, required: true
  attr :mention, Mention, required: true

  defp author_picture(assigns) do
    mention = assigns.mention

    assigns =
      assign(
        assigns,
        :picture?,
        awaits_approval?(mention) and is_binary(mention.remote_account.picture_url)
      )

    ~H"""
    <img
      :if={@picture?}
      id={@id}
      src={
        ~p"/sites/#{@site.public_id}/mentions/#{@mention.public_id}/picture?#{[v: Mention.version(@mention)]}"
      }
      alt=""
      class="size-8 shrink-0 rounded-full bg-base-300 object-cover"
    />
    <.avatar
      :if={!@picture?}
      initials={initials(author_name(@mention.remote_account))}
      shape={:round}
      size={:sm}
      tone={:base}
    />
    """
  end

  defp awaits_approval?(mention),
    do: Mention.approvable?(mention) and mention.approval != :approved

  attr :id, :string, required: true
  attr :mention, Mention, required: true

  defp mention_body(assigns) do
    ~H"""
    <div class="grid gap-2">
      <div id={@id} class="wrap-anywhere [&_a[href]]:link">
        {raw(HTML.sanitize(@mention.content, :remote))}
      </div>
      <ul :if={@mention.attachments != []} class="grid gap-1 text-sm">
        <li :for={attachment <- @mention.attachments}>
          <a
            href={attachment["url"]}
            target="_blank"
            rel="noopener noreferrer"
            class="link flex items-center gap-1 wrap-anywhere"
          >
            <.icon name="image" class="size-4 shrink-0" />
            {attachment["name"] || "Attachment without description"}
          </a>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    site = socket.assigns.current_scope.site

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:handle, Fediverse.handle(site))
     |> assign(:page_title, "Mentions")
     |> assign(:approving, MapSet.new())
     |> assign(:sending, MapSet.new())
     |> assign(:drafts, %{})
     |> stream_configure(:mentions, dom_id: &"mention-#{&1.id}")
     |> stream_configure(:replies, dom_id: &"my-reply-#{&1.id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter =
      case params["filter"] do
        "waiting" -> :waiting
        "private" -> :private
        "replies" -> :replies
        _all -> :all
      end

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_page(params["page"])}
  end

  @impl true
  def handle_event("approve", %{"id" => id, "version" => version}, socket) do
    scope = socket.assigns.current_scope
    mention = Fediverse.get_mention!(scope, id)

    if MapSet.member?(socket.assigns.approving, mention.id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> update(:approving, &MapSet.put(&1, mention.id))
       |> put_mention(mention)
       |> start_async({:approve, mention.id}, fn ->
         Fediverse.approve_reply(scope, mention, version)
       end)}
    end
  end

  def handle_event("hide", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    {:ok, mention} = Fediverse.hide_reply(scope, Fediverse.get_mention!(scope, id))

    {:noreply,
     socket
     |> put_mention(mention)
     |> put_flash(:info, "Reply hidden.")}
  end

  def handle_event("reply", %{"mention_id" => id, "reply" => attrs}, socket) do
    scope = socket.assigns.current_scope
    mention = Fediverse.get_mention!(scope, id)

    if MapSet.member?(socket.assigns.sending, mention.id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> update(:sending, &MapSet.put(&1, mention.id))
       |> update(:drafts, &Map.put(&1, mention.id, attrs["content"] || ""))
       |> put_mention(mention)
       |> start_async({:reply, mention.id}, fn ->
         Fediverse.reply_to_mention(scope, mention, attrs)
       end)}
    end
  end

  def handle_event("delete_reply", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    reply = Fediverse.get_member_reply!(scope, id)
    :ok = Fediverse.delete_member_reply(scope, reply)

    socket =
      cond do
        socket.assigns.filter == :replies -> load_replies(socket, socket.assigns.pagination.page)
        reply.mention_id -> refresh_mention(socket, reply.mention_id)
        true -> socket
      end

    {:noreply, put_flash(socket, :info, "Reply deleted.")}
  end

  def handle_event("block_account", %{"id" => id}, socket), do: block(socket, id, :account)
  def handle_event("block_server", %{"id" => id}, socket), do: block(socket, id, :server)

  defp block(socket, id, what) do
    scope = socket.assigns.current_scope
    mention = Fediverse.get_mention!(scope, id)
    {:ok, block} = Fediverse.block(scope, mention.remote_account, what)

    {:noreply,
     socket
     |> load_mentions(socket.assigns.pagination.page)
     |> put_flash(:info, "Blocked #{Block.name(block)}.")}
  end

  @impl true
  def handle_async({:approve, id}, result, socket) do
    socket = update(socket, :approving, &MapSet.delete(&1, id))

    case result do
      {:ok, {:ok, mention}} ->
        {:noreply,
         socket
         |> put_mention(mention)
         |> put_flash(:info, "Reply approved. The site shows it after the deploy.")}

      {:ok, {:error, :not_approvable}} ->
        {:noreply,
         socket
         |> refresh_mention(id)
         |> put_flash(:error, "Only public replies to a post can be approved.")}

      {:ok, {:error, :changed}} ->
        {:noreply,
         socket
         |> load_page(socket.assigns.pagination.page)
         |> put_flash(:error, "This reply has changed since you saw it. Please review it again.")}

      {:exit, _reason} ->
        {:noreply,
         socket
         |> refresh_mention(id)
         |> put_flash(:error, "Approving failed. Please try again.")}
    end
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

    {:noreply, refresh_mention(socket, id)}
  end

  defp refresh_mention(socket, id),
    do: put_mention(socket, Fediverse.get_mention!(socket.assigns.current_scope, id))

  defp put_mention(socket, %Mention{} = mention) do
    if socket.assigns.filter == :waiting and mention.approval != :waiting,
      do: stream_delete(socket, :mentions, mention),
      else: stream_insert(socket, :mentions, mention)
  end

  defp load_page(%{assigns: %{filter: :replies}} = socket, page), do: load_replies(socket, page)
  defp load_page(socket, page), do: load_mentions(socket, page)

  defp load_mentions(socket, page) do
    scope = socket.assigns.current_scope
    pagination = Fediverse.paginate_mentions(scope, page, socket.assigns.filter)

    socket =
      socket
      |> assign(:pagination, pagination)
      |> stream(:mentions, pagination.entries, reset: true)

    if connected?(socket) do
      :ok = Fediverse.mark_mentions_read(scope, pagination.entries)
      SiteAuth.refresh_unread_mentions(socket)
    else
      socket
    end
  end

  defp load_replies(socket, page) do
    pagination = Fediverse.paginate_member_replies(socket.assigns.current_scope, page)

    socket
    |> assign(:pagination, pagination)
    |> stream(:replies, pagination.entries, reset: true)
  end

  defp mentions_path(site, filter, page \\ 1) do
    params = [filter: if(filter != :all, do: filter), page: if(page > 1, do: page)]

    case Enum.reject(params, fn {_key, value} -> is_nil(value) end) do
      [] -> ~p"/sites/#{site.public_id}/mentions"
      query -> ~p"/sites/#{site.public_id}/mentions?#{query}"
    end
  end

  defp empty_title(:all), do: "No mentions yet"
  defp empty_title(:waiting), do: "No replies waiting for approval"
  defp empty_title(:private), do: "No private messages"

  defp reply_audience(%Mention{visibility: visibility} = mention) when visibility != :public do
    named = Fediverse.remote_account_addresses(mention.named_accounts)
    "Private: goes only to #{private_recipients(mention.remote_account, named)}."
  end

  defp reply_audience(mention) do
    recipients = reply_recipients(mention.remote_account, mention.named_accounts)

    cond do
      Mention.approvable?(mention) and mention.approval == :approved ->
        "Public: goes to #{recipients} and the site's followers, and shows in the post's thread."

      Mention.approvable?(mention) ->
        "Public: goes to #{recipients} and the site's followers, and shows in the post's " <>
          "thread once this reply is approved."

      true ->
        "Public: goes to #{recipients} and the site's followers."
    end
  end

  defp approval_label(:waiting), do: "Waiting for approval"
  defp approval_label(:approved), do: "Approved"
  defp approval_label(:hidden), do: "Hidden"

  defp approval_tone(:waiting), do: :warning
  defp approval_tone(:approved), do: :success
  defp approval_tone(:hidden), do: :neutral
end
