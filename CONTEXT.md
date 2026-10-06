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
