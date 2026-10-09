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

**Project**:
A portfolio entry describing work by the site owner — not the software project in this repo.
_Avoid_: Work, Portfolio Item

**Book**:
An entry on the site's bookshelf, with a reading status and optionally a rating and a cover image.

**Review**:
A post attached to a book. There is no separate review model — `Book.review?/1` means a post hangs off that book (`book.post_id`).
_Avoid_: treating a review as its own object

**Block**:
A unit of content inside `content` (paragraph, header, list, quote, code, image, table, embed, book). Posts, pages and
projects are lists of blocks; see `Feather.Content.Blocks`.
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

**Draft**:
A post, page or project without a published version, because it was never published or was unpublished.
_Avoid_: using it for unpublished changes of a published record

**Deployment Target**:
A destination a site is published to, typed `staging`, `production` or `backup`, backed by an rclone provider
(`internal`, `fastmail`, `hetzner_ftps`).
_Avoid_: Host, Server, Environment

**Static Export**:
Rendering a site to static files through a sink. Syncing them to a deployment target is a separate step; both
together are a deploy.
_Avoid_: Build, Generate

**Sink**:
Where a static export puts the files it produces. Receives generated content and copies of existing
files; knows nothing about sites, posts or deployment.
_Avoid_: Output, Target (a target is a deployment target)

**Preview**:
Live rendering of the same templates inside the CMS (`/preview/<deployment target>/`), with no export and no
deployment.
_Avoid_: Draft View, Staging
