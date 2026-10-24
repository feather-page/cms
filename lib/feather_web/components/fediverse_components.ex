defmodule FeatherWeb.FediverseComponents do
  @moduledoc """
  Components of the site's Fediverse pages (Timeline, Mentions,
  Following): the members' replies below what they answer, the form for a
  new one, the menu that blocks an author, and how remote accounts are
  named.
  """
  use FeatherWeb, :html

  alias Feather.Fediverse.{FollowedAccount, MemberReply, RemoteAccount}

  @doc """
  The picture of an account the site follows, loaded through the CMS
  (`FeatherWeb.FediversePictureController`), or its initials without one.
  """
  attr :site, :map, required: true
  attr :followed, FollowedAccount, required: true

  def followed_picture(assigns) do
    ~H"""
    <img
      :if={@followed.remote_account.picture_url}
      src={~p"/sites/#{@site.public_id}/following/#{@followed.public_id}/picture"}
      alt=""
      loading="lazy"
      class="size-8 shrink-0 rounded-full bg-base-300 object-cover"
    />
    <.avatar
      :if={!@followed.remote_account.picture_url}
      initials={initials(author_name(@followed.remote_account))}
      shape={:round}
      size={:sm}
      tone={:base}
    />
    """
  end

  @doc """
  The menu of a mention or Timeline post, which blocks its author or its
  author's server: it sends the event `"block_account"` or
  `"block_server"` with the entry's `id`, once the member confirmed.
  """
  attr :id, :string, required: true
  attr :entry_id, :string, required: true
  attr :author, RemoteAccount, required: true

  def entry_menu(assigns) do
    assigns = assign(assigns, :server, RemoteAccount.host(assigns.author.uri))

    ~H"""
    <.dropdown
      id={@id}
      label="More actions"
      align={:end}
      variant={:ghost}
      chevron={false}
      trigger_class="btn-sm btn-square"
    >
      <:trigger><.icon name="ellipsis-vertical" /></:trigger>
      <:item
        id={"#{@id}-block-account"}
        icon="ban"
        on_click={JS.push("block_account", value: %{id: @entry_id})}
        confirm={"Block #{author_address(@author)}?"}
        confirm_text="It can no longer follow the site or reach its Mentions. The follows between it and the site end, its mentions are deleted and its replies leave the site. Its server is told about the block."
        confirm_label="Block"
        danger
      >
        Block account
      </:item>
      <:item
        id={"#{@id}-block-server"}
        icon="ban"
        on_click={JS.push("block_server", value: %{id: @entry_id})}
        confirm={"Block #{@server}?"}
        confirm_text="No account on it can follow the site or reach its Mentions any more. The follows between them and the site end, their mentions are deleted and their replies leave the site."
        confirm_label="Block"
        danger
      >
        Block server
      </:item>
    </.dropdown>
    """
  end

  @doc """
  The members' replies to a mention or Timeline post, each with its
  `delete_reply_button/1`.
  """
  attr :id, :string, required: true
  attr :replies, :list, required: true
  attr :site_title, :string, required: true

  def member_replies(assigns) do
    ~H"""
    <ul :if={@replies != []} id={@id} class="grid gap-3 border-l-2 border-base-300 pl-4">
      <li :for={reply <- @replies} id={"member-reply-#{reply.id}"} class="grid gap-1">
        <p class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
          <span class="font-medium wrap-anywhere">{@site_title}</span>
          <.badge :if={reply.visibility == :public} style={:plain} icon="globe">Public</.badge>
          <.badge :if={reply.visibility == :direct} style={:plain} icon="mail">Private</.badge>
          <time datetime={DateTime.to_iso8601(reply.inserted_at)} class="text-base-content/70">
            {time_ago(reply.inserted_at)}
          </time>
          <.delete_reply_button id={"member-reply-#{reply.id}-delete"} reply={reply} />
        </p>
        <p class="whitespace-pre-line wrap-anywhere">{reply.content}</p>
      </li>
    </ul>
    """
  end

  @doc """
  The button that deletes a member's reply, once the member confirmed: it
  sends the event `"delete_reply"` with the reply's id.
  """
  attr :id, :string, required: true
  attr :reply, MemberReply, required: true

  def delete_reply_button(assigns) do
    ~H"""
    <.button
      id={@id}
      size={:sm}
      variant={:ghost}
      icon="trash-2"
      icon_only
      label="Delete reply"
      phx-click="delete_reply"
      phx-value-id={@reply.id}
      confirm="Delete this reply?"
      confirm_text={delete_reply_text(@reply)}
    />
    """
  end

  defp delete_reply_text(%MemberReply{visibility: :public}),
    do:
      "It leaves the site with the next deploy; then the servers it went to are asked to delete it."

  defp delete_reply_text(%MemberReply{}), do: "The servers it went to are asked to delete it."

  @doc """
  The form for a member's reply, which sends the event `"reply"` with the
  hidden field `name` set to `value` and says where the reply goes. It
  holds `draft`, the text of a reply not sent yet; while `sending`, its
  button is busy.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :audience, :string, required: true
  attr :draft, :string, default: ""
  attr :sending, :boolean, default: false

  def reply_form(assigns) do
    assigns = assign(assigns, :form, to_form(%{"content" => assigns.draft}, as: :reply))

    ~H"""
    <.form for={@form} id={"#{@id}-reply-form"} phx-submit="reply" class="grid gap-2">
      <input type="hidden" name={@name} value={@value} />
      <.input
        field={@form[:content]}
        id={"#{@id}-reply-content"}
        type="textarea"
        label="Reply"
        hide_label
        rows="2"
        placeholder="Write a reply…"
        required
      />
      <div class="flex flex-wrap items-center justify-between gap-2">
        <p id={"#{@id}-reply-audience"} class="text-sm text-base-content/70">{@audience}</p>
        <.button
          type="submit"
          size={:sm}
          icon="send"
          loading={@sending}
          phx-disable-with="Sending…"
        >
          Reply
        </.button>
      </div>
    </.form>
    """
  end

  @doc "What to tell a member whose reply could not be sent."
  @spec reply_error_message(Ecto.Changeset.t() | :not_an_account) :: String.t()
  def reply_error_message(:not_an_account), do: "Only a site with a fediverse name can reply."

  def reply_error_message(%Ecto.Changeset{errors: errors}) do
    {_message, opts} = Keyword.fetch!(errors, :content)

    case opts[:validation] do
      :required -> "Write a reply first."
      :length -> "A reply can have at most #{opts[:count]} characters."
    end
  end

  @doc "Who a reply goes to besides the site's followers: the author and the others named."
  @spec reply_recipients(RemoteAccount.t(), [String.t()]) :: String.t()
  def reply_recipients(%RemoteAccount{} = author, []), do: author_address(author)

  def reply_recipients(%RemoteAccount{} = author, named),
    do: "#{author_address(author)} and #{length(named)} more"

  @doc "Everyone a private reply goes to: the author and the others named, by handle or address."
  @spec private_recipients(RemoteAccount.t(), [String.t()]) :: String.t()
  def private_recipients(%RemoteAccount{} = author, named_addresses) do
    case Enum.split([author_address(author) | named_addresses], -1) do
      {[], [only]} -> only
      {others, [last]} -> Enum.join(others, ", ") <> " and " <> last
    end
  end

  @doc "The name of a remote account, or its host without one."
  @spec author_name(RemoteAccount.t()) :: String.t()
  def author_name(%RemoteAccount{name: name, uri: uri}), do: name || URI.parse(uri).host

  @doc "The verified handle of a remote account, or its address without one."
  @spec author_address(RemoteAccount.t()) :: String.t()
  def author_address(%RemoteAccount{handle: nil, uri: uri}), do: uri
  def author_address(%RemoteAccount{handle: handle}), do: handle
end
