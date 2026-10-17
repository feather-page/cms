---
name: feather.page sidebar theme
description: A housing-grey panel names the person; calm type on off-white with scale-printed meta lines; one signal orange.
colors:
  ground: "#fafaf8"
  panel: "#e4e3df"
  seam: "#a3a49f"
  hair: "#cdccc7"
  rule: "#d6d6d1"
  ink: "#161616"
  anthracite: "#242424"
  quiet: "#5e5e5b"
  signal: "#cc4a12"
  on-signal: "#ffffff"
  ground-dark: "#141413"
  panel-dark: "#222220"
  seam-dark: "#5a5a56"
  hair-dark: "#393936"
  rule-dark: "#30302d"
  ink-dark: "#e6e6e2"
  anthracite-dark: "#f2f2ee"
  quiet-dark: "#a3a39e"
  signal-dark: "#cc4a12"
typography:
  display:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(1.75rem, 3.75vw, 3.375rem)"
    fontWeight: 700
    lineHeight: 0.95
    letterSpacing: "-0.035em"
  display-slim:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(1.375rem, 2.4vw, 2.125rem)"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(1.875rem, 1.4rem + 1.4vw, 2.625rem)"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.03em"
  title:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.6875rem"
    fontWeight: 700
    lineHeight: 1.16
    letterSpacing: "-0.022em"
  title-sm:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.375rem"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.09375rem"
    fontWeight: 400
    lineHeight: 1.62
  body-sm:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Schibsted Grotesk, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.6875rem"
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: "0.15em"
    fontFeature: "\"tnum\", \"lnum\""
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "0.8125rem"
    fontWeight: 400
    lineHeight: 1.55
rounded:
  none: "0"
  focus: "2px"
  label: "3px"
  slot: "4px"
spacing:
  inset: "clamp(1.5rem, 3.9vw, 3.5rem)"
  gap: "clamp(2.5rem, 7vw, 8rem)"
  meta: "0.625rem"
  entry: "3.5rem"
  entry-mobile: "2.5rem"
  section: "2.25rem"
components:
  panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    width: "clamp(15rem, 27vw, 25rem)"
    padding: "clamp(2rem, 4vw, 3.5rem) clamp(1.25rem, 2.5vw, 2.25rem) 2rem"
  nav-item:
    textColor: "{colors.anthracite}"
    height: "2.5rem"
    padding: "0.375rem 0"
  nav-mark:
    backgroundColor: "{colors.signal}"
    size: "7px"
    rounded: "{rounded.none}"
  menu-bar:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.anthracite}"
    typography: "{typography.label}"
    height: "3.25rem"
  meta-label:
    textColor: "{colors.quiet}"
    typography: "{typography.label}"
  text-link:
    textColor: "{colors.anthracite}"
    underline: "1px {colors.anthracite}; hover and focus 2px {colors.signal}"
  nav-link:
    textColor: "{colors.anthracite}"
    underline: "none; hover and focus 2px {colors.signal}"
  new-label:
    backgroundColor: "{colors.signal}"
    textColor: "{colors.on-signal}"
    rounded: "{rounded.label}"
    padding: "0.1875rem 0.5rem 0.125rem"
  emoji-slot:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.slot}"
    size: "2rem"
  entry-title:
    textColor: "{colors.anthracite}"
    typography: "{typography.title}"
  project-shot:
    backgroundColor: "{colors.panel}"
    width: "200px"
---

# Design System: feather.page sidebar theme

## Overview

**Creative North Star: "The Useful Device"**

Dieter Rams' industrial design, taken only where it does a job. A housing-grey panel carries the person's name as a bold type designation and lists the pages; the reading column is calm grotesque type on off-white; every piece of metadata is printed like the scale on a device, small tracked capitals with a hairline running out after it. One signal orange appears, and only as a function: where you are, what is new, what is under the pointer or has focus.

The theme is a reader's surface for a personal log. Density is moderate and quiet: one reading column of about 36rem, generous gaps between entries, no boxes around them. On inner pages the panel slims and the content leads. It works without JavaScript; the only interactive element is a native `<details>` menu on phones.

Rejected in the build's history and not to return: decorative device fronts (grilles, dials, keys, rails), shelving-system grids, poster planes, LCD dates.

**Key Characteristics:**
- Two planes only: housing-grey panel and off-white ground, joined by a 1px seam.
- Scale printing for every label, date and count.
- Orange as signal, never as decoration.
- Flat: no shadows, gradients or cards.
- One self-hosted variable face, Schibsted Grotesk 400 to 700.

## Colors

A near-neutral warm grey world with one hot signal; dark mode keeps the same roles, ground going to near-black and the panel one step lighter.

### Primary
- **Signal Orange** (`signal`, the same value as `signal-dark`): at rest only the current-page square, the NEW label on the newest post and the current pagination underline. On interaction: link underlines on hover and focus, focus outlines on the ground, text selection. Text on it (the NEW label, selected text) is `on-signal` white in both modes; the orange is dark enough for white small bold caps (4.6:1) and still keeps 3:1 against both grounds for underlines and focus rings.

### Neutral
- **Off-White Ground** (`ground`): the reading surface.
- **Housing Grey** (`panel`): the sidebar panel, the emoji slot, code blocks and inline code, image placeholders.
- **Seam** (`seam`): the 1px edge between panel and ground, the rule under the name on the panel, separator dots, the tag hash, unlit rating stars, scrollbars; never for readable text.
- **Hairline** (`hair`): separators between nav items on the panel. It is the rule tuned to the darker plane; one value for both would vanish on the panel or weigh on the ground.
- **Rule** (`rule`): the line after a meta label and after a year heading, table rows, book rows, `hr`, the facts, post-nav and phone footer top rules.
- **Ink** (`ink`): body text.
- **Anthracite** (`anthracite`): headings, link text and underlines, nav items, star ratings, the Menu sign, the quote bar and the table head rule, focus outlines on the panel.
- **Quiet Grey** (`quiet`): scale labels, bylines, captions, list markers, copyright.

### Named Rules
**The Orange Only As Signal Rule.** Orange marks state: current, new, hover, focus, selection. At rest a page shows it in three places only: the current-page square, the NEW label and the current page number. It never fills a heading, a background area or an ornament. Apart from post emojis, it is the only colour on the page.

**The Link Grammar Rule.** Link text is anthracite; in scale labels (meta line, social links, copyright, photo credit) it is quiet and turns anthracite on hover and focus. Running-text links (content, "Continue reading", fact values, the 404 links, copyright and photo credit) carry a 1px underline in their text colour at rest. Navigational links (site name, panel nav, entry and project titles, meta-line links, post-nav including "All posts", "All projects", pagination, book titles, social links) have no underline at rest. Both turn to a 2px signal underline on hover and focus.

**The Focus Rule.** Focus is a 2px outline, 3px out, signal on the ground. On the housing-grey panel the outline is anthracite, which reads far stronger there than signal.

## Typography

**Display Font:** Schibsted Grotesk (variable 400 to 700, self-hosted woff2, preloaded; fallback ui-sans-serif, system-ui)
**Label/Mono Font:** labels use the same face; code uses the system monospace stack

**Character:** One grotesque does everything, from the 54px bold name to the 11px tracked scale labels; hierarchy comes from weight, size and tracking, never from a second family.

### Hierarchy
- **Display** (700, up to 3.375rem, 0.95, -0.035em): the site name on the home panel; `display-slim` on inner pages.
- **Headline** (700, fluid 1.875 to 2.625rem, 1.1): page and post `h1`.
- **Title** (700, 1.6875rem, 1.16): stream entry titles, content `h2`, the "Work" heading.
- **Title Small** (700, 1.375rem, 1.2): own project titles, content `h3`, the project lead at 400.
- **Body** (400, 1.0625rem/1.6 on phones, 1.09375rem/1.62 from 52rem): reading text, column max 36rem; at 700 also content `h4`, work-list titles, project titles on phones and the name in the phone menu bar.
- **Body Small** (400, 0.9375rem): the panel intro and nav, descriptions, facts, tables, captions, quote citations, book authors, "Continue reading" and back links at 600.
- **Label** (600, 0.6875rem, 0.15em tracking, uppercase, tabular lining numerals): the scale printing.
- **Mono** (400, 0.8125rem): code blocks.

Each step is a custom property on `:root` (`--display` to `--code`); rules use the property, not a number. Content headings step at least 1.2 apart (body, `h3`, `h2`).

Kept exceptions, each deliberate: the home name on phones is a fixed 2.125rem (the display clamp is tuned to the desktop panel); stream titles drop to 1.5625rem on phones for fewer lines in the narrow column; emoji glyphs take their size from the slot or heading they sit in (inherited body size, `0.8em` beside a heading), the emoji portrait from the portrait it replaces; inline code is `0.875em` of its context.

### Named Rules
**The Scale Printing Rule.** Dates, kinds, statuses, stacks, the domain, social links, the copyright, photo credits, tags, year headings and counts, book dates, fact terms, code languages, the NEW label and the Menu toggle are all set as the label style, in quiet grey unless they carry a state. Digits are tabular; punctuation inside dates is reset to proportional so separators keep their width.

## Layout

From 52rem the frame is a two-column grid: a sticky, full-height panel of `clamp(15rem, 27vw, 25rem)` and a reading column of `36rem + inset`, separated by the fluid `gap`. The panel stacks identity, intro, nav and, pushed to the foot, social links and copyright. Main is padded `4rem inset 5rem 0`.

Below 52rem the panel becomes a header. Home keeps a compact identity (name 2.125rem beside a 60px portrait), only the intro's first sentence, and the nav as wrapping running text. Inner pages collapse to one 3.25rem bar: the name small as the home link at left, a native "Menu" disclosure at right holding the nav as a hairline list with 2.75rem rows. Social links and copyright move to a footer under a rule. Main is padded `1.375rem 1rem 2.5rem`.

Below 30rem the facts list stacks term over value.

Fluid sizing: the site name, portrait (56 to 108px), panel width, panel padding, inset and gap all scale with the viewport between the breakpoints; nothing jumps at 52rem except the panel's change of form.

Rhythm: meta line to title 0.625rem (title to byline too), entries 3.5rem apart (2.5rem on phones), content blocks 0.75em apart. One section value, `--section` 2.25rem, for every section and rule-topped block: content headings, `hr`, books years, tags, post-nav, facts, back links, the space under a header image, lead or project image, and the projects list after content. No negative margins patch spacing.

## Elevation & Depth

Fully flat. No shadows, gradients or blur anywhere. Depth is two tonal planes, the housing-grey panel and the off-white ground, with a 1px seam between them; everything else is separated by hairlines or space.

**The Flat Housing Rule.** If something needs to stand apart, give it the panel grey or a 1px rule, never a shadow or a card.

## Shapes

Square by default. Radius appears only on three small things: the focus outline (2px), the NEW label (3px) and the emoji slot (4px). The current-page mark is a hard 7px square. Images are unrounded; project shots crop to 16:10.

## Components

### Panel and Identity
The name in Display beside the cut-out portrait (108px, bottom-aligned with the name) on home; under them the domain as a scale label on a seam-coloured rule, then the intro paragraph in Body Small. Inner pages drop portrait and intro and use `display-slim`; they keep the domain on desktop, phones hide it. An emoji stands in when no portrait exists.

### Navigation List
A list of page titles in Body Small at weight 500, separated by hairlines top and bottom, rows at least 2.5rem tall. The current page (and the ancestor of the current page) gets weight 600 and the orange 7px square, which hangs in the panel gutter 15px left of the label so the label never shifts. Hover follows the link grammar.

### Mobile Menu Bar
On inner pages under 52rem: the name in bold body size at left, the "Menu" summary in label style at right with a 10px anthracite plus drawn from two bars; opening the menu collapses the vertical bar into a minus (0.2s, ease-out-expo). The same nav list with the same orange square opens below.

### Meta Line
Emoji slot, then the label (date and kind, separated by a seam dot), then a 1px rule that fills the rest of the line, then, on the newest post only and while it is at most 30 days old, the NEW label: orange fill, white 700 text, 3px corners. On notes the date links to the post. The rule is the entry's only line. Project and work entries reuse the meta line with status, stack and link, or role, company and period.

### Stream Entry
Meta line, title, then the excerpt and "Continue reading" (articles), the byline with stars and full text (books), or the full text in place (notes). No separators between entries; 3.5rem of space does the separating.

### Emoji Slot
A 2rem housing-grey square (1.75rem on phones) with 4px corners holding the post emoji at body size. On desktop it hangs in the gap left of the reading column, vertically centred on the meta line, so the labels align with the text edge.

### Work List
Own projects first: a 200px 16:10 shot (112px on phones) beside the title, meta line and description. Then a "Work" heading in Title and the references as a text-only list, titles in bold body size. A project page adds a lead in Title Small at 400, a 16:10 image, the content, and the facts list.

### Facts List
A two-column definition list under a rule: terms in label style, values in Body Small; stacked below 30rem.

### Books List
Year headings in label style: the year, a seam dot, the count, then a rule running out; screen readers hear "2026, 28 books". Each book a three-column row (cover or emoji 1.75rem, title over author, stars over date) separated by rules; the date drops the year its heading already gives ("OCT 15").

### Book Card
A book block inside a post is a quiet row in the books-list grammar: the 1.75rem cover or emoji column beside title over author. No lines, so a stream entry keeps its one rule.

## Do's and Don'ts

### Do:
- **Do** keep orange to signal duties: at rest the current square, NEW and the current page number; on interaction hover underlines, focus and selection.
- **Do** set every date, kind, status and count in the label style with tabular numerals.
- **Do** give each stream entry exactly one rule, the one after its meta label.
- **Do** put a post's emoji in the housing-grey slot of its meta line; project titles and page headings may carry their emoji inline.
- **Do** separate with the panel grey, a 1px rule or space.

### Don't:
- **Don't** add ornament without a job: no grilles, dials, keys, rails, decorative device fronts.
- **Don't** put emojis in the navigation; nav items are text plus, when current, the orange square.
- **Don't** draw separators between stream entries or box entries in cards.
- **Don't** use shadows, gradients or a second typeface.
- **Don't** colour link text orange or use seam grey for readable text.
