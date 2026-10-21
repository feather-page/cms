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
can overwrite it in the image block and the image picker. A caption is shown under the image; the alt text describes it.
_Avoid_: Caption, Description, Title

**Description** · _de:_ Beschreibung:
The sentence about a post or page that search results and link previews show, stored on the record and its versions.
The self-hosted model writes it in the site's language when the record is published without one, and writes it anew
while it is still the model's and the title or content changed; "Suggest" in the form's details asks for one at any
time. A description a member typed stays. Without one the export takes the start of the text. Projects have their
short description instead; the Bio is about the site owner, not a page.
_Avoid_: Summary, Excerpt, Teaser, Bio

**Redirect** · _de:_ Weiterleitung:
An old path of a site that sends visitors on to a post, page or project, or to a path the export generates (`/`,
`/feed.xml`), permanently (301) or temporarily (302). Old paths share the site's URL space with the slugs, so a URL
belongs to content or to one redirect. Publishing a record under a new URL redirects its old URL to it permanently. A
redirect is active while its target record is published or its target path still resolves; the static export writes
the active ones into the `.htaccess`, and the preview follows them.
_Avoid_: Alias, Forward
