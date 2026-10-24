defmodule Feather.FediverseFixtures do
  @moduledoc """
  Test helpers for sites in the fediverse and remote accounts.
  """

  alias Feather.Accounts.Scope
  alias Feather.{Fediverse, Repo}

  alias Feather.Fediverse.{
    FollowedAccount,
    Follower,
    MemberReply,
    Mention,
    Pictures,
    RemoteAccount,
    SigningKey,
    TimelinePost
  }

  alias Feather.Sites.Site

  @doc """
  A site with the fediverse name `timon` (or `:fediverse_name`) whose
  account a deploy has put online, unless `online: false`.
  """
  def fediverse_site_fixture(attrs \\ %{}), do: fediverse_scope_fixture(attrs).site

  @doc "A scope with a fresh user and a site of theirs, as `fediverse_site_fixture/1`."
  def fediverse_scope_fixture(attrs \\ %{}) do
    {name, attrs} = attrs |> Map.new() |> Map.pop(:fediverse_name, "timon")
    {online?, attrs} = Map.pop(attrs, :online, true)
    scope = Feather.SitesFixtures.site_scope_fixture(attrs)
    {:ok, site} = Fediverse.update_name(scope, %{"fediverse_name" => name})
    if online?, do: :ok = Fediverse.record_online(site, DateTime.utc_now())
    Scope.put_site(scope, Repo.get!(Site, site.id))
  end

  @doc "A fresh RSA key pair of a remote account: `{private key, public key as PEM}`."
  def remote_key_pair do
    private_key = :public_key.generate_key({:rsa, 2048, 65_537})
    public_key = {:RSAPublicKey, elem(private_key, 2), elem(private_key, 3)}
    entry = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    {private_key, :public_key.pem_encode([entry])}
  end

  @doc """
  The headers of a POST of `body` to `path` on the CMS, signed as a
  remote server signs it (draft-cavage) with `private_key` under `key_id`.
  `:host`, `:date` and `:digest` replace the right values.
  """
  def signed_headers(private_key, key_id, path, body, opts \\ []) do
    public_host = URI.parse(Application.fetch_env!(:feather, :base_url))
    host = Keyword.get(opts, :host, "#{public_host.host}:#{public_host.port}")

    date =
      opts
      |> Keyword.get(:date, DateTime.utc_now())
      |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

    digest =
      Keyword.get(opts, :digest, "SHA-256=" <> Base.encode64(:crypto.hash(:sha256, body)))

    headers = [{"host", host}, {"date", date}, {"digest", digest}]

    signature =
      [{"(request-target)", "post " <> path} | headers]
      |> SigningKey.signing_string()
      |> :public_key.sign(:sha256, private_key)
      |> Base.encode64()

    [
      {"signature",
       ~s[keyId="#{key_id}",algorithm="rsa-sha256",headers="(request-target) host date digest",signature="#{signature}"]}
      | headers
    ]
  end

  def remote_account_fixture(attrs \\ %{}) do
    uri = "https://mastodon.example/users/ana#{System.unique_integer([:positive])}"

    attrs =
      Enum.into(attrs, %{
        uri: uri,
        key_id: uri <> "#main-key",
        public_key: "-----BEGIN PUBLIC KEY-----\n-----END PUBLIC KEY-----\n",
        inbox: uri <> "/inbox",
        fetched_at: DateTime.utc_now()
      })

    %RemoteAccount{}
    |> RemoteAccount.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Sends the test's requests to fediverse servers in the limiter's `pool`
  (`:general` or `:inbox`) through a limiter without a free slot, which
  turns each away at once with `{:error, :busy}`, until
  `Application.delete_env(:feather, :fediverse_limiter)` (for the inbox's
  pool `:fediverse_inbox_limiter`).
  """
  def busy_limiter(pool \\ :general) do
    {name, env} =
      case pool do
        :general -> {__MODULE__.BusyLimiter, :fediverse_limiter}
        :inbox -> {__MODULE__.BusyInboxLimiter, :fediverse_inbox_limiter}
      end

    ExUnit.Callbacks.start_supervised!({Feather.Fediverse.Limiter, name: name, max_total: 0})
    Application.put_env(:feather, env, server: name, timeout: 0)
    ExUnit.Callbacks.on_exit(fn -> Application.delete_env(:feather, env) end)
  end

  @doc "Makes `account` (a new remote account by default) a follower of the site."
  def follower_fixture(%Site{} = site, %RemoteAccount{} = account \\ remote_account_fixture()) do
    Repo.insert!(%Follower{
      site_id: site.id,
      remote_account_id: account.id,
      follow_id: account.uri <> "#follow"
    })
  end

  @doc """
  A mention of the site's account by `:remote_account` (a new remote
  account by default), public and unread unless `attrs` say otherwise.
  """
  def mention_fixture(%Site{} = site, attrs \\ %{}) do
    {account, attrs} =
      attrs |> Map.new() |> Map.pop_lazy(:remote_account, &remote_account_fixture/0)

    {post_id, attrs} = Map.pop(attrs, :post_id)

    attrs =
      Enum.into(attrs, %{
        uri: account.uri <> "/statuses/#{System.unique_integer([:positive])}",
        visibility: :public,
        content: "Hello @timon",
        published_at: DateTime.utc_now()
      })

    %Mention{site_id: site.id, remote_account_id: account.id, post_id: post_id}
    |> Mention.changeset(attrs)
    |> Feather.PublicId.put()
    |> Repo.insert!()
    |> Repo.preload([:remote_account, :post])
  end

  @doc """
  A public reply to `post` of the site, approved with a snapshot of its
  author (a new remote account by default, named Ana) and a kept picture
  unless `picture: false`. `attrs` as `mention_fixture/2`.
  """
  def approved_reply_fixture(%Site{} = site, post, attrs \\ %{}) do
    {picture?, attrs} = attrs |> Map.new() |> Map.pop(:picture, true)

    {account, attrs} =
      Map.pop_lazy(attrs, :remote_account, fn ->
        remote_account_fixture(%{name: "Ana", handle: "@ana@mastodon.example"})
      end)

    mention =
      mention_fixture(site, Map.merge(attrs, %{remote_account: account, post_id: post.id}))

    picture =
      if picture? do
        {:ok, name} = Pictures.put(Feather.MediaFixtures.test_image_binary(120, 120))
        name
      end

    mention
    |> Mention.approval_changeset(:approved, %{
      approved_at: DateTime.utc_now(),
      approved_content: mention.content,
      approved_name: account.name,
      approved_handle: account.handle,
      approved_picture: picture
    })
    |> Repo.update!()
  end

  @doc """
  A member's reply to a mention or Timeline post with `content`, as
  stored, without sending it: public when what it answers is public, then
  with the mention's post, else direct, to the author of what it answers.
  """
  def member_reply_fixture(answered, content \\ "Thank you!")

  def member_reply_fixture(%TimelinePost{} = post, content) do
    post = Repo.preload(post, followed_account: :remote_account)

    %MemberReply{
      public_id: Feather.PublicId.generate(),
      site_id: post.site_id,
      timeline_post_id: post.id,
      in_reply_to: post.uri,
      visibility: if(post.visibility == :public, do: :public, else: :direct),
      recipients: [post.followed_account.remote_account.uri]
    }
    |> MemberReply.changeset(%{content: content})
    |> Repo.insert!()
  end

  def member_reply_fixture(%Mention{} = mention, content) do
    mention = Repo.preload(mention, :remote_account)
    public? = mention.visibility == :public

    %MemberReply{
      public_id: Feather.PublicId.generate(),
      site_id: mention.site_id,
      mention_id: mention.id,
      post_id: if(public?, do: mention.post_id),
      in_reply_to: mention.uri,
      visibility: if(public?, do: :public, else: :direct),
      recipients: [mention.remote_account.uri]
    }
    |> MemberReply.changeset(%{content: content})
    |> Repo.insert!()
  end

  @doc """
  The site's follow of `:remote_account` (a new remote account by
  default), accepted unless `accepted: false`.
  """
  def followed_account_fixture(%Site{} = site, attrs \\ %{}) do
    {account, attrs} =
      attrs |> Map.new() |> Map.pop_lazy(:remote_account, &remote_account_fixture/0)

    followed =
      Repo.insert!(%FollowedAccount{
        site_id: site.id,
        remote_account_id: account.id,
        public_id: Feather.PublicId.generate(),
        follow_id: Fediverse.account_url(site) <> "#follows/" <> Feather.PublicId.generate(),
        accepted_at: if(Map.get(attrs, :accepted, true), do: DateTime.utc_now())
      })

    %{followed | remote_account: account}
  end

  @doc "A public post of `followed` (a followed account) in the site's Timeline."
  def timeline_post_fixture(%FollowedAccount{} = followed, attrs \\ %{}) do
    followed = Repo.preload(followed, :remote_account)

    attrs =
      Enum.into(attrs, %{
        uri: followed.remote_account.uri <> "/statuses/#{System.unique_integer([:positive])}",
        visibility: :public,
        content: "Hakuna matata",
        published_at: DateTime.utc_now()
      })

    %TimelinePost{
      site_id: followed.site_id,
      followed_account_id: followed.id,
      public_id: Feather.PublicId.generate()
    }
    |> TimelinePost.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Stubs the fediverse servers of the `handles` (`"ana@example.social"`):
  each answers WebFinger for its handle and serves its actor at
  `https://<domain>/users/<user>` (or at the address given with the handle
  as `{handle, uri}`), and accepts every POST. Tells `pid`
  about each request as `{:fediverse_request, method, url, body}`.
  """
  def serve_remote_accounts(handles, pid \\ self()) do
    documents =
      handles
      |> Enum.map(fn
        {handle, uri} -> {handle, uri}
        handle -> {handle, default_actor_uri(handle)}
      end)
      |> Enum.reduce(%{}, &put_remote_documents/2)

    Req.Test.stub(Feather.Fediverse, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      url = "https://#{conn.host}#{conn.request_path}"
      send(pid, {:fediverse_request, conn.method, url, body})
      respond(conn, documents, url)
    end)
  end

  defp respond(%Plug.Conn{method: "POST"} = conn, _documents, _url),
    do: Plug.Conn.send_resp(conn, 202, "")

  defp respond(conn, documents, url) do
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string

    case Map.fetch(documents, url <> query) do
      {:ok, {content_type, document}} ->
        conn
        |> Plug.Conn.put_resp_content_type(content_type)
        |> Plug.Conn.send_resp(200, Jason.encode!(document))

      :error ->
        Plug.Conn.send_resp(conn, 404, "")
    end
  end

  defp default_actor_uri(handle) do
    [user, domain] = String.split(handle, "@")
    "https://#{domain}/users/#{user}"
  end

  defp put_remote_documents({handle, uri}, documents) do
    [user, domain] = String.split(handle, "@")

    webfinger =
      "https://#{domain}/.well-known/webfinger?" <>
        URI.encode_query(%{"resource" => "acct:" <> handle})

    documents
    |> Map.put(
      webfinger,
      {"application/jrd+json",
       %{
         "subject" => "acct:" <> handle,
         "links" => [%{"rel" => "self", "type" => "application/activity+json", "href" => uri}]
       }}
    )
    |> Map.put(
      uri,
      {"application/activity+json",
       %{
         "@context" => ["https://www.w3.org/ns/activitystreams", "https://w3id.org/security/v1"],
         "id" => uri,
         "type" => "Person",
         "preferredUsername" => user,
         "name" => String.capitalize(user),
         "inbox" => uri <> "/inbox",
         "followers" => uri <> "/followers",
         "publicKey" => %{
           "id" => uri <> "#main-key",
           "owner" => uri,
           "publicKeyPem" => "-----BEGIN PUBLIC KEY-----\n-----END PUBLIC KEY-----\n"
         }
       }}
    )
  end
end
