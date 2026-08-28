# Feather-Page CMS

A CMS for managing small static websites. Content is edited in Rails, rendered to static HTML with ERB,
and deployed to the site owner's own hosting.

## Language

**Site**:
A managed website with its own domain. The container for all content — posts, pages, books, projects, images.
_Avoid_: Website, Blog, Project

**Post**:
A dated entry, listed chronologically.
_Avoid_: Article, Entry, Blogpost

**Page**:
An undated page at a fixed URL. Its `page_type` decides whether it shows free content, the book catalogue, or the project list.
_Avoid_: Static Page, Content Page

**Project**:
A portfolio entry describing work by the site owner — not the software project in this repo.
_Avoid_: Work, Portfolio Item

**Review**:
A post attached to a book. There is no separate review model — `book.review?` means a post hangs off that book.
_Avoid_: treating a review as its own object

**Block**:
A unit of content inside `content` (text, image, code, book, embed). Posts, pages and projects are lists of blocks.
_Avoid_: Section, Element, Widget

**Deployment Target**:
A destination a site is published to, typed `staging`, `production` or `backup`, backed by an rclone provider.
_Avoid_: Host, Server, Environment

**Static Export**:
Rendering a site to static files and syncing them to a deployment target.
_Avoid_: Build, Generate

**Preview**:
Live rendering of the same templates inside the CMS, with no export and no deployment.
_Avoid_: Draft View, Staging
