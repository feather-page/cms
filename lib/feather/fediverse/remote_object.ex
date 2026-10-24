defmodule Feather.Fediverse.RemoteObject do
  @moduledoc """
  Reads a `Note` or `Article` that another server sent, for Mentions
  (`Feather.Fediverse.Mentions`) and the Timeline
  (`Feather.Fediverse.Timeline`).

    * **Visibility.** An object addressed to the public is `:public`, one
      addressed to its author's followers `:followers`, anything else a
      private message (`:direct`).
    * **Content.** Its HTML is sanitized (`Feather.Content.HTML.sanitize/2`
      in `:remote` mode, which drops relative links); the title, content
      warning and alt texts are text. Only https links count.
    * **Named accounts.** The accounts it mentions, at most 20.
    * **Size.** An object whose text (its title, sanitized content,
      content warning and attachments together) takes more than 100 KB is
      refused (`validate_size/1`): it is not filed, and an `Update` that
      makes it that large is not applied.
  """

  import Ecto.Changeset, only: [add_error: 3, get_field: 2]

  alias Feather.Content.HTML
  alias Feather.Fediverse
  alias Feather.Fediverse.RemoteAccount
  alias Feather.Sites.Site

  @types ~w(Note Article)
  @public ~w(https://www.w3.org/ns/activitystreams#Public as:Public Public)
  @named_cap 20
  @max_bytes 100_000

  @doc "Returns true for a note or an article."
  @spec post?(term()) :: boolean()
  def post?(%{"type" => type}), do: type in @types
  def post?(_object), do: false

  @doc """
  What the object by `account` says, as attributes of a mention or a
  Timeline post of the site, whose own account does not count among those
  it names.
  """
  @spec attrs(Site.t(), map(), RemoteAccount.t()) :: map()
  def attrs(%Site{} = site, %{} = object, %RemoteAccount{} = account) do
    %{
      uri: object["id"],
      url: link_href(object["url"]),
      in_reply_to: id_of(object["inReplyTo"]),
      visibility: visibility(object, account),
      name: text(object["name"]),
      content: HTML.sanitize(content(object), :remote),
      summary: text(object["summary"]),
      attachments: attachments(object["attachment"]),
      named_accounts: named_accounts(object, account, site),
      published_at: published_at(object["published"])
    }
  end

  @doc "Refuses a mention or Timeline post whose text takes more than 100 KB (see the module doc)."
  @spec validate_size(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_size(%Ecto.Changeset{} = changeset) do
    attachments =
      for attachment <- get_field(changeset, :attachments) || [],
          value <- Map.values(attachment),
          is_binary(value),
          do: value

    texts = for field <- [:name, :content, :summary], do: get_field(changeset, field) || ""

    if Enum.sum_by(texts ++ attachments, &byte_size/1) > @max_bytes,
      do: add_error(changeset, :content, "is too large"),
      else: changeset
  end

  @doc "The addresses the object is sent to (`to` and `cc`)."
  @spec recipients(map()) :: [String.t()]
  def recipients(%{} = object),
    do: Enum.flat_map(["to", "cc"], fn field -> object[field] |> List.wrap() |> ids() end)

  @doc "The accounts the object mentions in its tags."
  @spec mentioned(map()) :: [String.t()]
  def mentioned(%{} = object) do
    for %{"type" => "Mention", "href" => href} <- List.wrap(object["tag"]), do: href
  end

  @doc "`:public`, `:followers` (of the author's `account`) or `:direct`."
  @spec visibility(map(), RemoteAccount.t()) :: :public | :followers | :direct
  def visibility(%{} = object, %RemoteAccount{} = account) do
    recipients = recipients(object)

    cond do
      Enum.any?(recipients, &(&1 in @public)) -> :public
      account.followers_url && account.followers_url in recipients -> :followers
      true -> :direct
    end
  end

  @doc "The id of an object or link, or nil."
  @spec id_of(term()) :: String.t() | nil
  def id_of(%{"id" => id}) when is_binary(id), do: id
  def id_of(id) when is_binary(id), do: id
  def id_of(_object), do: nil

  defp ids(values), do: values |> Enum.map(&id_of/1) |> Enum.reject(&is_nil/1)

  defp named_accounts(object, account, site) do
    excluded = [account.uri, Fediverse.account_url(site)]

    object
    |> mentioned()
    |> Enum.filter(&(RemoteAccount.https_url?(&1) and &1 not in excluded))
    |> Enum.uniq()
    |> Enum.take(@named_cap)
  end

  defp content(%{"content" => content}) when is_binary(content), do: content

  defp content(%{"contentMap" => %{} = content_map}),
    do: content_map |> Map.values() |> Enum.find("", &is_binary/1)

  defp content(_object), do: ""

  defp text(text) when is_binary(text), do: text
  defp text(_text), do: nil

  defp attachments(attachments) do
    attachments
    |> List.wrap()
    |> Enum.flat_map(fn
      %{} = attachment ->
        case link_href(attachment["url"]) do
          nil ->
            []

          url ->
            [
              %{
                "url" => url,
                "media_type" => text(attachment["mediaType"]),
                "name" => text(attachment["name"])
              }
            ]
        end

      _other ->
        []
    end)
  end

  @doc "The https address of a link, of the first of several or of a bare URL, or nil."
  @spec link_href(term()) :: String.t() | nil
  def link_href([link | _]), do: link_href(link)
  def link_href(%{"href" => href}), do: link_href(href)
  def link_href(url) when is_binary(url), do: if(RemoteAccount.https_url?(url), do: url)
  def link_href(_link), do: nil

  # A time to come would keep an object on top.
  defp published_at(published) do
    now = DateTime.utc_now()

    with true <- is_binary(published),
         {:ok, at, _offset} <- DateTime.from_iso8601(published),
         false <- DateTime.after?(at, now) do
      at
    else
      _other -> now
    end
  end
end
