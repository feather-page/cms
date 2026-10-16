# Product: rocu.de

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Rendered by feather.page (this repository) to static HTML and CSS through `Feather.StaticSite`.
rocu.de uses the `simple_sidebar` theme (DECISIONS.md, 0015); other sites keep the default `feather` theme. No
JavaScript framework; the page scaffold works without JavaScript.

## Users

- **Robert himself.** The site is his log: books, bike tours, travel, tech notes, short thoughts.
- **Friends and acquaintances** who drop by now and then, most often for book recommendations.
- **Potential employers or clients**, occasionally, checking who he is. They must not be put off.

## Product Purpose

Robert Curth's personal website, online since 2001. A chronological stream of posts plus a few
standing pages. Success means Robert enjoys posting there, friends find what he has been reading,
and a professional visitor leaves thinking "this person builds the web with care".

## Positioning

A web craftsman's own site: Robert has built websites since 2001 and still hand-makes his own, on
his own CMS. The site is the proof of the craft: small pages, clean HTML, good typography.

## Operating Context

- Written in the feather.page admin as blocks, exported as static files.
- Post kinds in the stream: titled articles (tech, smart home, AI, travel reports), untitled
  micro-posts (an emoji and a few paragraphs, sometimes an image), book posts (title, author,
  rating, short review), photo posts. Every post carries an emoji. The home stream is paginated.
- Standing pages: About me, Books read (finished books grouped by year, each with an emoji),
  Countries visited (58 countries by continent, with flags), Photos taken (photos with place and
  date), Imprint + Contact (German legal text), and a new Projects section.
- Language: English; some book titles are German.

## Capabilities and Constraints

- Own theme, independent of the shared theme; zipfelmaus and every other site keep the shared one.
- Untitled micro-posts are shown in full in the stream, never as an excerpt.
- **Projects** get their own page. Robert's own projects come first (feather.page, ZiWoAs,
  zipfelkasse, TRMNL plugins, ...): what it does, stack, status, links, story. Work projects
  follow as short references where they may be public. The CMS project already has title, emoji,
  short description, company, role, period, status, type (professional or personal), tags, links,
  header and thumbnail image and block content; the feature is unused so far, and its page in the
  frontend is still to be designed.
- **About me** gets a short career history and a link to LinkedIn and the CV.
- Tech posts are under-represented today; the design gives tech posts and projects more weight
  next to life, books and travel.
- Kept from the shared theme work: Gettext localisation, previous/next navigation, responsive
  images, meta tags.
- Open: richer, animated individual posts need a new content capability (for example an HTML or
  embed block). Not part of this theme; the theme must not prevent it.

## Brand Commitments

- The impression to leave: **a web craftsman since 2001.**
- Robert's binding taste: the functional discipline of Bauhaus and Dieter Rams, not the colours of
  Bauhaus posters: only what is really needed, and that done well. Clear typography, order and
  plain functionality, web craft. Playfulness is a sprinkle on top, a delight, never the scaffold.
  Digital-watch styling (LCD numerals) was tried for dates and rejected as too much.
- feather.page principles: small pages, clean HTML.
- Site emoji 👨🏻‍💻; the per-post emojis are part of the voice.
- Personal mark: a colored-pencil style portrait of Robert, generated from his photo, rights with
  Robert (source: `https://techgenossen.de/team/responsive/robert-curth-320.webp`). The original
  photo exists if the style has to change.
- Voice: first person, friendly, plain English, the occasional emoji.
- No "hire me" call to action. Professional links (GitHub `shostakovich`, LinkedIn, Techgenossen
  eG) are present but quiet.

## Evidence on Hand

- Live content at https://rocu.de: posts back to 2024 and the standing pages above.
- The portrait above; Robert's CV (`Lebenslauf_Robert_Curth_2026.pdf`, kept by Robert).
- No testimonials, client logos or metrics exist; do not invent them.

## Product Principles

1. Clean scaffold, sprinkled delight: structure is plain and orderly, joy sits on top.
2. The site is the proof of craft: small, valid, fast, readable without JavaScript.
3. Short things are read in full; nothing hides behind a click without a reason.
4. Personal in content, professional in bearing: a hiring visitor finds order and competence.
5. Tech and projects stand visibly next to books, bikes and travel.
