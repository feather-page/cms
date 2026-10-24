# Feather-Page CMS

A CMS for managing small static websites. Content is edited in the Phoenix (LiveView) admin, rendered to static HTML,
and deployed to the site owner's own hosting.

## Language

**Site**:
A managed website with its own domain. The container for all content — posts, pages, books, projects, images.
_Avoid_: Website, Blog, Project

**Member**:
A user who may manage a site (`site_users`). Super admins may access every site without being members. Users become
members by accepting an invitation.
_Avoid_: Collaborator, Owner

**Connected App** · _de:_ Verbundene App:
An MCP client, such as Claude, that a member allowed to work on their sites. It keeps access until the member revokes
it in the user settings or it goes unused for 90 days.
_Avoid_: Integration, Connector, Token

**Post**:
A dated entry, listed chronologically.
_Avoid_: Article, Entry, Blogpost

**Page**:
An undated page at a fixed URL. Its `page_type` decides whether it shows free content, the book catalogue, or the project list.
The page with slug `/` is the homepage.
_Avoid_: Static Page, Content Page

**Navigation**:
The ordered list of pages in a site's main menu (`navigation_items`, positions kept contiguous). It belongs to the site;
there is no separate navigation record.
_Avoid_: Menu

**Mascot**:
A small transparent illustration of the site's characters that the feather.page theme shows in a fixed place: above
the footer, at the end of every post, next to the title of the projects page. A site has one optional mascot per
place; where one is missing, the theme shows the site's emoji. Other themes leave mascots out.
_Avoid_: Logo, Avatar, Illustration

**Theme**:
The look of a site's static pages: its templates, stylesheet and fonts. A site picks one in its settings from a fixed
list in code; `feather` (shown as "feather.page") is the default. Blocks, routes, meta tags, feed and sitemap are the
same in every theme.
_Avoid_: Template, Skin, Design

**Portrait**:
An optional photo of the site owner that the simple_sidebar theme shows in its panel on wide screens and, on phones,
in the home header and beside the bio in the footer; other themes leave it out. Like a mascot, it is an image slot on
the site.
_Avoid_: Avatar, Profile Picture, Logo

**Bio**:
An optional short plain text about the site owner, set in the site settings. The simple_sidebar theme shows it on every
page, in its panel on wide screens and in the footer on phones; other themes leave it out.
_Avoid_: Intro, About, Description, Tagline

**Project**:
A portfolio entry describing work by the site owner — not the software project in this repo.
_Avoid_: Work, Portfolio Item

**Book**:
An entry on the site's bookshelf, with a reading status and optionally a rating and a cover image.

**Review**:
A post attached to a book. There is no separate review model — `Book.review?/1` means a post hangs off that book (`book.post_id`).
_Avoid_: treating a review as its own object

**Block**:
A unit of content inside `content` (paragraph, header, list, quote, code, image, table, embed, book, diagram). Posts,
pages and projects are lists of blocks; see `Feather.Content.Blocks`. A diagram block holds D2 source that the export
and the preview render into an SVG image.
_Avoid_: Section, Element, Widget

**Version** · _de:_ Version:
A published state of a post, page or project: all of its fields, content included, as they were when it was
published. The newest version is the **published version**, what the site shows; the older ones are its history and
can be restored into the unpublished changes.
_Avoid_: Revision, Generation, Snapshot

**Unpublished Changes** · _de:_ unveröffentlichte Änderungen:
The edits to a post, page or project since its last publish, saved automatically while editing. The site does not
show them until they are published.
_Avoid_: Draft, Working Copy

**Publish** · _de:_ Veröffentlichen:
Turning the unpublished changes into a new version, which becomes the published version. Not a deploy: the site's
files change only with the next deploy. **Unpublish** takes a record off the site; its versions stay.
_Avoid_: Save, Release

**Scheduled Post**:
A published post whose publish date (`publish_at`) lies after the moment it was published. The static export leaves it
out until it is due; when it becomes due, the CMS deploys the site if its deployment target was deployed before that.
_Avoid_: Future Post, Planned Post

**Due**:
A post is due once its publish date has passed. Only then does a deploy show it.

**Draft**:
A post, page or project without a published version, because it was never published or was unpublished.
_Avoid_: using it for unpublished changes of a published record

**Deployment Target**:
The FTPS account a site is deployed to, through an rclone provider (`ftps`). A site has at most one; its address is
the site's domain.
_Avoid_: Host, Server, Environment, Staging

**Deploy**:
A static export synced to the site's deployment target. What changed since the last deploy (published versions, the
site's own changes, books, deleting or unpublishing a published record) counts as not deployed until the next one.
After a deploy the CMS tells IndexNow and, with the site's archive.org keys, archive.org which URLs changed.

**Static Export**:
Rendering a site to static files through a sink. Syncing them to a deployment target is a separate step; both
together are a deploy.
_Avoid_: Build, Generate

**Sink**:
Where a static export puts the files it produces. Receives generated content and copies of existing
files; knows nothing about sites, posts or deployment.
_Avoid_: Output, Target (a target is a deployment target)

**Preview**:
Live rendering of the same templates inside the CMS (`/preview/<site>/`), with no export and no deployment. Shows the
records as they are, unpublished changes and drafts included.
_Avoid_: Draft View, Staging

**Alt Text** · _de:_ Alternativtext:
The text that stands in for an image for screen readers and image search, stored on the image and shown wherever it
appears as content or as a cover. The self-hosted model suggests it in the site's language after an upload; members
can overwrite it in the image block and the image picker, and a connected app can set it too. A caption is shown under
the image; the alt text describes it.
_Avoid_: Caption, Description, Title

**Description** · _de:_ Beschreibung:
The sentence about a post or page that search results and link previews show, stored on the record and its versions.
The self-hosted model writes it in the site's language when the record is published without one, and writes it anew
while it is still the model's and the title or content changed; "Suggest" in the form's details asks for one at any
time. A description a member typed stays. Without one the export takes the start of the text. Projects have their
short description instead; the Bio is about the site owner, not a page.
_Avoid_: Summary, Excerpt, Teaser, Bio

**Short Post** · _de:_ Kurzbeitrag:
A post without a title. The site and the CMS's post list show it untitled; its meta title names it in the page title, in
link previews, in the feeds and in its Markdown alternate. At its first publish, when it has no slug, the self-hosted
model writes a slug and, unless a member typed one, the meta title in the site's language; afterwards the slug stays.
While its text is shorter than 300 characters the form hides the title field. A review without a title is a short post
too.
_Avoid_: Note, Untitled Post, Micropost

**Markdown Alternate** · _de:_ Markdown-Fassung:
The home page, a post, page or project as Markdown, without the theme's markup: front matter with its title (a short
post's meta title, as in the page title), canonical URL, publish date (posts) and tags, then the title and the content;
the home page's holds all posts, a books or projects page's its list. The static export writes it as `index.md` next
to the page's `index.html`; the `.htaccess` serves it at the page's URL to clients that ask for `text/markdown`, the
page links it in its head, `llms.txt` lists them with the description of each page, and the preview shows it too.
_Avoid_: Markdown version (a version is a published state), Markdown variant (variants are image sizes)

**Redirect** · _de:_ Weiterleitung:
An old path of a site that sends visitors on to a post, page or project, or to a path the export generates (`/`,
`/feed.xml`), permanently (301) or temporarily (302); never to the Markdown alternate of a record, which moves with
it. An old path without an extension also catches its `index.html` and its `index.md`; the latter leads to the
target's Markdown alternate where the target has one. Old paths share the site's URL space with the slugs, so a URL
belongs to content or to one redirect. Publishing a record under a new URL redirects its old URL to it permanently. A
redirect is active while its target record is published or its target path still resolves; the static export writes
the active ones into the `.htaccess`, and the preview follows them.
_Avoid_: Alias, Forward

**Fediverse Name** · _de:_ Fediverse-Name:
The first part of the site's handle `@name@domain`, set in the site settings. With it the site is an account in the
fediverse that people on Mastodon, micro.blog and other servers find by its handle: the static export writes the
account and a document per post on the site's domain, only its inbox runs on the CMS. The name is fixed after the
first deploy with it; a site without one is not in the fediverse. A new domain starts the account over: it loses its
followers and the accounts it follows, and goes online at its new address with the next deploy. The protocol types `Note` and `Article` are not the
site's terms: a short post goes out as `Note`, a post with a title as `Article`.
_Avoid_: Username, Account Name

**Follower** · _de:_ Follower:
An account in the fediverse that follows the site's account. Its server sends the follow to the site's inbox on the
CMS, which accepts it unless the account or its server is blocked, or 100 accounts of its server became followers
within the hour; the settings show how many followers there are, and the export publishes their number, not who they
are. Each deploy sends the followers the posts it puts on the site,
changes or takes off, and a changed profile; posts that were on the site before its account went online are not sent.
A site that comes from micro.blog gets its followers back on their own: their servers follow again once they notice
the account's new key.
_Avoid_: Subscriber

**Followed Account** · _de:_ gefolgtes Konto:
An account in the fediverse that the site follows. Members follow accounts by their handles in the CMS, several at
once; the site's account sends each a follow once it is online, and the account's server accepts or refuses it. Its
posts make up the site's Timeline; unfollowing takes them out again. The export publishes how many accounts the site
follows, not which.
_Avoid_: Subscription, Friend

**Timeline** · _de:_ Timeline:
The posts of the site's followed accounts in the CMS, newest first, as they arrive: their public posts, and those to
their followers once the follow was accepted; no boosts or likes. Their pictures load through the CMS, so the
accounts' servers do not see the members' addresses. Members reply to them as to mentions. Timeline posts are kept 30
days, and what they say is stored encrypted.
_Avoid_: Feed, Home, Stream

**Mention** · _de:_ Erwähnung:
Something addressed to the site's fediverse account: a reply to one of its posts, a mention of its handle or a private
message. The site's inbox files it into the site's Mentions in the CMS, only for the site it addresses; its author's
edits change it and their deletion removes it, and it is kept for good otherwise. Every member sees the Mentions,
private messages included, and the navigation shows how many no member has seen yet. What it says is stored encrypted;
private messages are still not end-to-end encrypted, the operators of both servers can read them.
_Avoid_: Notification

**Reply** · _de:_ Antwort:
A message in answer to a post of the site or to another reply, received from the fediverse or written by a member in
the CMS. A received reply to one of the site's posts, or to a member's reply, lands in Mentions; one addressed to the
public waits there until a member approves or hides it. The site shows the approved replies in a thread below the post
as they were approved: the text and its author's name, handle and picture, which the member saw before approving. Its
author's edit puts it back to waiting, their deletion takes it off the site for good. Every post of a site with a
fediverse name tells readers how to reply, also before the first reply.
A member answers a mention or a Timeline post from the CMS, and the reply goes out at once as the site's account. A
reply to something public is public: it also reaches the site's followers, and the deploy it starts shows it in the
post's thread, below the reply it answers and marked as by the author, without approval. Any other reply goes only to
the accounts named in what it answers and never reaches the site. Deleting a public reply takes it off the site with a
deploy before the servers it went to are asked to delete it. Mentions lists every reply of the members, also those
whose mention or Timeline post is gone, so that each can still be deleted.
_Avoid_: Comment

**Blocked Account** · _de:_ blockiertes Konto:
An account in the fediverse that a member blocked from the menu of a mention or a Timeline post, alone or with every
account on its server and the server's subdomains. It can neither follow the site nor reach its Mentions: the follows between it and the site end,
its mentions are deleted, its replies leave the site, and what it sends afterwards is dropped; a follow is refused. A
blocked account's server is told about the block, and about its end when a member unblocks it in the site settings.
Not to be confused with a content Block.
_Avoid_: Ban, Mute
