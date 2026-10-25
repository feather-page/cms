defmodule Feather.StaticSite.ActivityStreams do
  @moduledoc """
  The fediverse documents of a site with a fediverse name (ADR 0033), as
  maps for JSON, addressed by canonical routes:

    * the WebFinger answer, one file that answers every query for the
      domain with the site's account;
    * the account, a `Person` with the site's title as name, its bio as
      summary, its portrait as picture, its public key (a pending one
      once the key is rotated, `Feather.Fediverse.rotate_key/1`) and its
      inbox on the CMS (`Feather.Fediverse.inbox_url/1`);
    * its outbox, an `OrderedCollection` of the recent posts, each in a
      `Create`; it counts all posts;
    * its followers and the accounts it follows, each an
      `OrderedCollection` that gives their number but does not list them;
    * one document per post, at the address of its `fediverse_generation`
      (`Feather.Content.Post`): a short post is a `Note`, a post with a
      title an `Article` with the title as `name` and the stored
      description as `summary`. Both carry the page as `url`, the content
      as HTML in the site's language, its links absolute and without
      images, book covers, code highlighting and diagram images (a diagram
      shows its source; a book is one line of emoji, title, author and
      rating, as fediverse servers strip the book card's markup), and the
      images of the content as attachments with their alt texts; a post
      without images attaches the covers of its books instead, as their
      sharing images, whose size no theme changes. A post published again after its date carries
      the time of that as `updated`; an `Update` of it carries the time it
      goes out (`Feather.Fediverse.FederatedObjects`);
    * one document per public reply of a member
      (`Feather.Fediverse.MemberReply`), a `Note` in reply to what it
      answers. A reply that is not public goes out with the same `Note`
      (`member_reply/4`) but has no document.

  Pages, projects and books have no documents. The content leaves out
  images and book covers, whose markup follows the theme, so a new theme
  changes no document and sends the followers no `Update`
  (`Feather.Fediverse.FederatedObjects`), unless it gives content images
  other sizes; it leaves out code highlighting and diagram images, which
  follow the versions of chroma and d2, so upgrading them changes none
  either.
  """

  alias Feather.Books.Book
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Content.{Post, PostVersion}
  alias Feather.Fediverse
  alias Feather.Fediverse.MemberReply
  alias Feather.Media.{Image, Variants}
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Blocks, Routes, SiteData, ThemeHelpers}

  @activity_streams "https://www.w3.org/ns/activitystreams"
  @security "https://w3id.org/security/v1"
  @public "https://www.w3.org/ns/activitystreams#Public"
  @outbox_size 20

  @doc "The WebFinger answer (JRD) for the site's account."
  @spec webfinger(SiteData.t(), Routes.t()) :: map()
  def webfinger(%SiteData{site: site}, %Routes{} = routes) do
    account = Routes.activitypub_url(routes, :account)
    "@" <> acct = Fediverse.handle(site)

    %{
      "subject" => "acct:" <> acct,
      "aliases" => [account],
      "links" => [
        %{"rel" => "self", "type" => "application/activity+json", "href" => account},
        %{
          "rel" => "http://webfinger.net/rel/profile-page",
          "type" => "text/html",
          "href" => Routes.home_url(routes)
        }
      ]
    }
  end

  @doc "The site's account (its portrait preloaded)."
  @spec account(SiteData.t(), Routes.t()) :: map()
  def account(%SiteData{site: site}, %Routes{} = routes) do
    id = Routes.activitypub_url(routes, :account)

    %{
      "@context" => [@activity_streams, @security],
      "id" => id,
      "type" => "Person",
      "preferredUsername" => site.fediverse_name,
      "name" => site.title,
      "url" => Routes.home_url(routes),
      "inbox" => Fediverse.inbox_url(site),
      "outbox" => Routes.activitypub_url(routes, :outbox),
      "followers" => Routes.activitypub_url(routes, :followers),
      "following" => Routes.activitypub_url(routes, :following),
      "publicKey" => %{
        "id" => id <> "#main-key",
        "owner" => id,
        "publicKeyPem" => Fediverse.public_key(site)
      }
    }
    |> put_present("summary", if(ThemeHelpers.present?(site.bio), do: paragraphs(site.bio)))
    |> put_present("icon", picture(routes, site.portrait_image))
  end

  defp paragraphs(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.trim()
    |> String.split(~r/\n\s*\n/)
    |> Enum.map_join(&paragraph/1)
  end

  defp paragraph(text), do: "<p>" <> String.replace(escape(text), "\n", "<br>") <> "</p>"

  defp picture(_routes, nil), do: nil

  defp picture(routes, %Image{} = image) do
    variant = Variants.account_picture()

    %{
      "type" => "Image",
      "mediaType" => Variants.content_type(variant),
      "url" => Routes.image_url(routes, image, variant)
    }
  end

  @doc "The account's followers: their number, without listing them."
  @spec followers(SiteData.t(), Routes.t()) :: map()
  def followers(%SiteData{follower_count: count}, %Routes{} = routes),
    do: counted_collection(routes, :followers, count)

  @doc "The accounts the account follows: their number, without listing them."
  @spec following(SiteData.t(), Routes.t()) :: map()
  def following(%SiteData{following_count: count}, %Routes{} = routes),
    do: counted_collection(routes, :following, count)

  defp counted_collection(routes, collection, count) do
    %{
      "@context" => @activity_streams,
      "id" => Routes.activitypub_url(routes, collection),
      "type" => "OrderedCollection",
      "totalItems" => count
    }
  end

  @doc """
  The outbox: the #{@outbox_size} newest posts, each in a `Create`, out of
  all posts. `context` renders their content (see `post/4`).
  """
  @spec outbox(SiteData.t(), Routes.t(), Blocks.context()) :: map()
  def outbox(%SiteData{posts: posts} = data, %Routes{} = routes, context) do
    %{
      "@context" => @activity_streams,
      "id" => Routes.activitypub_url(routes, :outbox),
      "type" => "OrderedCollection",
      "totalItems" => length(posts),
      "orderedItems" =>
        posts
        |> Enum.take(@outbox_size)
        |> Enum.map(&(data |> post(routes, &1, context) |> Map.delete("@context") |> create()))
    }
  end

  defp create(%{"id" => id} = object) do
    activity = %{
      "id" => id <> "#create",
      "type" => "Create",
      "actor" => object["attributedTo"],
      "published" => object["published"],
      "to" => object["to"],
      "object" => object
    }

    put_present(activity, "cc", object["cc"])
  end

  @doc "The `Create` of a document as it goes out, its `@context` moved to the activity."
  @spec create_activity(map()) :: map()
  def create_activity(document) do
    {context, object} = Map.pop(document, "@context")
    object |> create() |> Map.put("@context", context)
  end

  @doc """
  The document of a post. `context` renders its content and finds its
  images; it should use the same canonical routes.
  """
  @spec post(SiteData.t(), Routes.t(), Post.t(), Blocks.context()) :: map()
  def post(%SiteData{site: site}, %Routes{} = routes, %Post{} = post, context) do
    url = Routes.post_url(routes, post)
    context = %{context | inline_images: false, base_url: url, highlights: %{}, diagrams: %{}}
    content = Blocks.to_html(post.content, context)

    %{
      "@context" => @activity_streams,
      "id" => Routes.activitypub_url(routes, post),
      "type" => "Note",
      "attributedTo" => Routes.activitypub_url(routes, :account),
      "published" => timestamp(post.publish_at),
      "url" => url,
      "to" => [@public],
      "content" => content,
      "contentMap" => %{site.language_code => content}
    }
    |> put_present("updated", updated(post))
    |> put_present("attachment", attachments(post, context))
    |> as_article(post)
  end

  @doc """
  The document of a member's reply: a `Note` of the account in reply to
  what it answers, its text as paragraphs and the accounts it goes to
  (its `recipients`) as mentions. A public reply addresses the public,
  with the followers and those accounts in copy, and points to its place
  in the thread of `post` as `url`; pass nil where no thread shows it (the
  reply it answers is not approved, or the post not on the site). Any
  other reply addresses only those accounts.
  """
  @spec member_reply(Site.t(), Routes.t(), MemberReply.t(), Post.t() | nil) :: map()
  def member_reply(%Site{} = site, %Routes{} = routes, %MemberReply{} = reply, post) do
    content = paragraphs(reply.content)

    %{
      "@context" => @activity_streams,
      "id" => Routes.activitypub_url(routes, reply),
      "type" => "Note",
      "attributedTo" => Routes.activitypub_url(routes, :account),
      "inReplyTo" => reply.in_reply_to,
      "published" => timestamp(reply.inserted_at),
      "content" => content,
      "contentMap" => %{site.language_code => content}
    }
    |> Map.merge(audience(routes, reply))
    |> put_present("tag", Enum.map(reply.recipients, &%{"type" => "Mention", "href" => &1}))
    |> put_present("url", thread_url(routes, reply, post))
  end

  defp audience(routes, %MemberReply{visibility: :public, recipients: recipients}),
    do: %{"to" => [@public], "cc" => [Routes.activitypub_url(routes, :followers) | recipients]}

  defp audience(_routes, %MemberReply{recipients: recipients}), do: %{"to" => recipients}

  defp thread_url(routes, reply, %Post{} = post),
    do: Routes.post_url(routes, post) <> "#reply-" <> reply.public_id

  defp thread_url(_routes, _reply, nil), do: nil

  defp updated(%Post{
         publish_at: publish_at,
         published_version: %PostVersion{number: number, published_at: published_at}
       })
       when number > 1 do
    if DateTime.after?(published_at, publish_at), do: timestamp(published_at)
  end

  defp updated(%Post{}), do: nil

  defp as_article(document, %Post{title: title, description: description}) do
    if ThemeHelpers.present?(title) do
      document
      |> Map.merge(%{"type" => "Article", "name" => title})
      |> put_present("summary", if(ThemeHelpers.present?(description), do: description))
    else
      document
    end
  end

  defp attachments(post, context) do
    case post.content
         |> ContentBlocks.normalize()
         |> Enum.filter(&(&1["type"] == "image"))
         |> Enum.uniq_by(& &1["image_id"])
         |> Enum.flat_map(&attachment(&1, context)) do
      [] -> cover_attachments(post, context)
      images -> images
    end
  end

  defp cover_attachments(post, context) do
    post.content
    |> ContentBlocks.book_ids()
    |> Enum.flat_map(&cover_attachment(Map.get(context.books, &1), context))
  end

  defp cover_attachment(%Book{cover_image: %Image{} = cover} = book, context) do
    variant = Variants.sharing()

    [
      %{
        "type" => "Image",
        "mediaType" => Variants.content_type(variant),
        "url" => Routes.image_url(context.routes, cover, variant),
        "name" => book.title <> " – " <> book.author
      }
    ]
  end

  defp cover_attachment(_book, _context), do: []

  defp attachment(block, context) do
    with %Image{} = image <- Map.get(context.images, block["image_id"]),
         %{} = variant <- Blocks.largest_content_variant(image, context) do
      [
        %{
          "type" => "Image",
          "mediaType" => Variants.content_type(variant),
          "url" => Routes.image_url(context.routes, image, variant),
          "name" => Blocks.image_alt(image, block["caption"])
        }
      ]
    else
      _missing -> []
    end
  end

  defp timestamp(%DateTime{} = datetime),
    do: datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp put_present(document, _key, value) when value in [nil, []], do: document
  defp put_present(document, key, value), do: Map.put(document, key, value)

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
