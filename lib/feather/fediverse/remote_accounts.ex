defmodule Feather.Fediverse.RemoteAccounts do
  @moduledoc """
  The cache of accounts on other fediverse servers. Their actors are
  fetched through `Feather.Fediverse.Client`, signed with the key of the
  site that asks, and kept with their key, name, handle, picture and
  inboxes and the address of its followers collection
  (`Feather.Fediverse.RemoteAccount`); `get/2` fetches an actor
  again once its copy is a day old.

  An actor document counts only if it is the actor at its address: its
  `id` is the address it was fetched by, on the origin it came from after
  redirects, its type is an actor's, its inbox and shared inbox are on its
  origin, and its key belongs to it. The
  handle is `@<preferredUsername>@<host>` only when WebFinger on that host
  leads back to the actor; when WebFinger names another domain (a server
  whose accounts carry the domain of its owner), WebFinger on that domain
  must lead back to it too. Otherwise the account has no handle.

  `resolve/2` finds the account of a handle through WebFinger;
  `addresses/1` names cached accounts by their handles.
  """

  import Ecto.Query, warn: false

  alias Feather.Fediverse.{Client, RemoteAccount, RemoteObject, SigningKey}
  alias Feather.Repo
  alias Feather.Sites.Site

  require Logger

  @max_age_seconds 24 * 3600
  @actor_types ~w(Person Service Application Group Organization)
  @name_max_length 200
  @user_format ~r/\A[a-z0-9_.-]+\z/i
  @domain_format ~r/\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/i
  @activity_streams_links [
    "application/activity+json",
    ~s(application/ld+json; profile="https://www.w3.org/ns/activitystreams")
  ]

  @doc """
  The account of the actor at `uri`: the cached one while it is less than
  a day old, else fetched again (see `fetch/2`). When fetching it again
  fails, the cached one.
  """
  @spec get(Site.t(), String.t()) :: {:ok, RemoteAccount.t()} | {:error, term()}
  def get(%Site{} = site, uri) when is_binary(uri) do
    case Repo.get_by(RemoteAccount, uri: uri) do
      nil ->
        fetch(site, uri)

      %RemoteAccount{} = account ->
        if fresh?(account), do: {:ok, account}, else: refetch(site, account)
    end
  end

  defp fresh?(account),
    do: DateTime.diff(DateTime.utc_now(), account.fetched_at) < @max_age_seconds

  defp refetch(site, account) do
    case fetch(site, account.uri) do
      {:ok, account} -> {:ok, account}
      {:error, _reason} -> {:ok, account}
    end
  end

  @doc """
  Fetches the actor at `uri` with the site's key and stores its account,
  replacing a cached one. `:pool` names the limiter's pool of its requests
  (`Feather.Fediverse.Client`).
  """
  @spec fetch(Site.t(), String.t(), keyword()) :: {:ok, RemoteAccount.t()} | {:error, term()}
  def fetch(%Site{} = site, uri, opts \\ []) when is_binary(uri) do
    key = SigningKey.for_site(site)

    with {:ok, document, url} <- Client.get_object(uri, key, opts),
         {:ok, attrs} <- actor_attrs(document, uri, url),
         {:ok, account} <-
           upsert(Map.put(attrs, :handle, verified_handle(key, document, opts))) do
      {:ok, account}
    else
      {:error, reason} ->
        Logger.info("Fediverse actor #{inspect(uri)} could not be fetched: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp actor_attrs(%{"id" => uri, "type" => type} = document, uri, %URI{} = url)
       when type in @actor_types do
    with true <- RemoteAccount.same_origin?(uri, url),
         true <- inboxes_on_origin?(document, uri),
         {:ok, key_id, public_key} <- public_key(document["publicKey"], uri) do
      {:ok,
       document
       |> profile()
       |> Map.merge(%{
         uri: uri,
         key_id: key_id,
         public_key: public_key,
         fetched_at: DateTime.utc_now()
       })}
    else
      _invalid -> {:error, :invalid_actor}
    end
  end

  defp actor_attrs(_document, _uri, _url), do: {:error, :invalid_actor}

  defp profile(document) do
    %{
      name: name(document["name"]),
      picture_url: picture_url(document["icon"]),
      inbox: document["inbox"],
      shared_inbox: shared_inbox(document["endpoints"]),
      followers_url: RemoteObject.link_href(document["followers"])
    }
  end

  # Another server's inbox would get the actor's deliveries, and its Delete would purge that inbox's.
  defp inboxes_on_origin?(document, uri) do
    inboxes = [document["inbox"] | List.wrap(shared_inbox(document["endpoints"]))]
    Enum.all?(inboxes, &(is_binary(&1) and RemoteAccount.same_origin?(&1, uri)))
  end

  defp public_key(keys, owner) when is_list(keys) do
    Enum.find_value(keys, :error, fn key ->
      case public_key(key, owner) do
        {:ok, _id, _pem} = found -> found
        :error -> nil
      end
    end)
  end

  defp public_key(%{"id" => id, "owner" => owner, "publicKeyPem" => pem}, owner)
       when is_binary(id) and is_binary(pem),
       do: {:ok, id, pem}

  defp public_key(_key, _owner), do: :error

  defp name(name) when is_binary(name) and name != "", do: String.slice(name, 0, @name_max_length)
  defp name(_name), do: nil

  defp picture_url([icon | _]), do: picture_url(icon)
  defp picture_url(%{"url" => url}), do: RemoteObject.link_href(url)
  defp picture_url(_icon), do: nil

  defp shared_inbox(%{"sharedInbox" => url}) when is_binary(url), do: url
  defp shared_inbox(_endpoints), do: nil

  defp verified_handle(key, %{"id" => uri, "preferredUsername" => username}, opts)
       when is_binary(username) do
    host = URI.parse(uri).host

    with {:ok, subject} <- webfinger(key, username <> "@" <> host, uri, opts),
         {:ok, subject} <- confirm_domain(key, subject, host, uri, opts) do
      "@" <> subject
    else
      _unverified -> nil
    end
  end

  defp verified_handle(_key, _document, _opts), do: nil

  defp confirm_domain(key, subject, host, uri, opts) do
    [_user, domain] = String.split(subject, "@")

    cond do
      String.downcase(domain) == String.downcase(host) -> {:ok, subject}
      webfinger(key, subject, uri, opts) == {:ok, subject} -> {:ok, subject}
      true -> :error
    end
  end

  defp webfinger(key, acct, uri, opts) do
    with [_user, domain] <- String.split(acct, "@"),
         true <- Regex.match?(@domain_format, domain),
         {:ok, %{"subject" => "acct:" <> subject, "links" => links}} when is_list(links) <-
           Client.get_webfinger(webfinger_url(acct, domain), key, opts),
         [_user, _domain] <- String.split(subject, "@"),
         true <- Enum.any?(links, &(actor_link(&1) == uri)) do
      {:ok, subject}
    else
      _unverified -> :error
    end
  end

  defp webfinger_url(acct, domain),
    do:
      "https://#{domain}/.well-known/webfinger?" <>
        URI.encode_query(%{"resource" => "acct:" <> acct})

  defp actor_link(%{"rel" => "self", "type" => type, "href" => uri}) when is_binary(uri),
    do: if(type in @activity_streams_links, do: uri)

  defp actor_link(_link), do: nil

  @doc """
  The verified handles of the accounts at `uris`, in their order; the
  address itself for an account without one or not in the cache.
  """
  @spec addresses([String.t()]) :: [String.t()]
  def addresses(uris) when is_list(uris) do
    handles =
      from(a in RemoteAccount,
        where: a.uri in ^uris and not is_nil(a.handle),
        select: {a.uri, a.handle}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(uris, &Map.get(handles, &1, &1))
  end

  @doc """
  The account of a handle (`@ana@example.social` or `ana@example.social`):
  WebFinger on its domain names the actor, which is then fetched like
  `get/2`.
  """
  @spec resolve(Site.t(), String.t()) ::
          {:ok, RemoteAccount.t()} | {:error, :invalid_handle | :not_found}
  def resolve(%Site{} = site, handle) when is_binary(handle) do
    with {:ok, acct, domain} <- parse_handle(handle) do
      case actor_of(site, acct, domain) do
        uri when is_binary(uri) -> found(get(site, uri))
        nil -> {:error, :not_found}
      end
    end
  end

  defp actor_of(site, acct, domain) do
    case Client.get_webfinger(webfinger_url(acct, domain), SigningKey.for_site(site)) do
      {:ok, %{"links" => links}} when is_list(links) -> Enum.find_value(links, &actor_link/1)
      _not_found -> nil
    end
  end

  defp found({:ok, account}), do: {:ok, account}
  defp found({:error, _reason}), do: {:error, :not_found}

  defp parse_handle(handle) do
    acct = String.trim_leading(handle, "@")

    with [user, domain] <- String.split(acct, "@"),
         true <- Regex.match?(@user_format, user) and Regex.match?(@domain_format, domain) do
      {:ok, acct, domain}
    else
      _invalid -> {:error, :invalid_handle}
    end
  end

  defp upsert(attrs) do
    changeset = RemoteAccount.changeset(%RemoteAccount{}, attrs)

    case Repo.insert(changeset,
           on_conflict: {:replace_all_except, [:id, :uri, :inserted_at]},
           conflict_target: :uri,
           returning: true
         ) do
      {:ok, account} -> {:ok, account}
      {:error, %Ecto.Changeset{}} -> {:error, :invalid_actor}
    end
  end
end
