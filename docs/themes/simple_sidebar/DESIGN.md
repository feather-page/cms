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
  faint: "#a3a49f"
  star-off: "#bdbdb8"
  signal: "#e5531a"
  on-signal: "#111111"
  ground-dark: "#141413"
  panel-dark: "#222220"
  seam-dark: "#4a4a47"
  hair-dark: "#393936"
  rule-dark: "#30302d"
  ink-dark: "#e6e6e2"
  anthracite-dark: "#f2f2ee"
  quiet-dark: "#a3a39e"
  faint-dark: "#6a6a66"
  star-off-dark: "#4a4a47"
  signal-dark: "#f0642a"
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

Dieter Rams' industrial design, taken only where it does a job. A housing-grey panel carries the person's name as a bold type designation and lists the pages; the reading column is calm grotesque type on off-white; every piece of metadata is printed like the scale on a device, small tracked capitals with a hairline running out after it. One signal orange appears, and only as a function: where you are, what is new, what has focus, what is a link.

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
- **Signal Orange** (`signal`, dark `signal-dark`): the current-page square, the NEW label on the newest post, focus outlines, link underlines, text selection, the current pagination underline, the Menu plus sign. Text on it is `on-signal` near-black in both modes.

### Neutral
- **Off-White Ground** (`ground`): the reading surface.
- **Housing Grey** (`panel`): the sidebar panel, the emoji slot, code blocks and inline code, image placeholders.
- **Seam** (`seam`): the 1px edge between panel and ground, the rule under the name on the panel, footer link underlines.
- **Hairline** (`hair`): separators between nav items.
- **Rule** (`rule`): the line after a meta label, table rows, book rows, the facts and post-nav top rules.
- **Ink** (`ink`): body text.
- **Anthracite** (`anthracite`): headings, link text, nav items, star ratings.
- **Quiet Grey** (`quiet`): scale labels, bylines, captions, list markers, copyright.
- **Faint** (`faint`): separator dots and the tag hash only; never for readable text.
- **Star Off** (`star-off`): unlit rating stars.

### Named Rules
**The Orange Only As Signal Rule.** Orange marks state or function: current, new, focus, link, selection. It never fills a heading, a background area or an ornament. Apart from post emojis, it is the only colour on the page.

**The Anthracite Link Rule.** Link text stays anthracite; the orange lives in the underline (1px, 2px on hover).

## Typography

**Display Font:** Schibsted Grotesk (variable 400 to 700, self-hosted woff2, preloaded; fallback ui-sans-serif, system-ui)
**Label/Mono Font:** labels use the same face; code uses the system monospace stack

**Character:** One grotesque does everything, from the 54px bold name to the 11px tracked scale labels; hierarchy comes from weight, size and tracking, never from a second family.

### Hierarchy
- **Display** (700, up to 3.375rem, 0.95, -0.035em): the site name on the home panel; `display-slim` on inner pages.
- **Headline** (700, fluid 1.875 to 2.625rem, 1.1): page and post `h1`.
- **Title** (700, 1.6875rem; 1.5625rem on phones, 1.16): stream entry titles.
- **Title Small** (700, 1.375rem; 1.125rem in the work list and on phones): project titles; content `h2` uses 1.375rem, `h3` 1.1875rem.
- **Body** (400, 1.0625rem/1.6 on phones, 1.09375rem/1.62 from 52rem): reading text, column max 36rem.
- **Body Small** (400, 0.9375rem): descriptions, facts, tables, "Continue reading" and back links at 600.
- **Label** (600, 0.6875rem, 0.15em tracking, uppercase, tabular lining numerals): the scale printing.

### Named Rules
**The Scale Printing Rule.** Dates, kinds, statuses, stacks, the domain, social links, tags, year headings, book dates, fact terms and the Menu toggle are all set as the label style in quiet grey. Digits are tabular; punctuation inside dates is reset to proportional so separators keep their width.

## Layout

From 52rem the frame is a two-column grid: a sticky, full-height panel of `clamp(15rem, 27vw, 25rem)` and a reading column of `36rem + inset`, separated by the fluid `gap`. The panel stacks identity, intro, nav and, pushed to the foot, social links and copyright. Main is padded `4rem inset 5rem 0`.

Below 52rem the panel becomes a header. Home keeps a compact identity (name 2.125rem beside a 60px portrait), only the intro's first sentence, and the nav as wrapping running text. Inner pages collapse to one 3.25rem bar: the name small as the home link at left, a native "Menu" disclosure at right holding the nav as a hairline list with 2.75rem rows. Social links and copyright move to a footer under a rule. Main is padded `1.375rem 1rem 2.5rem`.

Below 30rem the facts list stacks term over value.

Fluid sizing: the site name, portrait (56 to 108px), panel width, panel padding, inset and gap all scale with the viewport between the breakpoints; nothing jumps at 52rem except the panel's change of form.

Rhythm: meta line to title 0.625rem, entries 3.5rem apart (2.5rem on phones), content blocks 0.75em apart, sections and rule-topped blocks 2.25rem.

## Elevation & Depth

Fully flat. No shadows, gradients or blur anywhere. Depth is two tonal planes, the housing-grey panel and the off-white ground, with a 1px seam between them; everything else is separated by hairlines or space.

**The Flat Housing Rule.** If something needs to stand apart, give it the panel grey or a 1px rule, never a shadow or a card.

## Shapes

Square by default. Radius appears only on three small things: the focus outline (2px), the NEW label (3px) and the emoji slot (4px). The current-page mark is a hard 7px square. Images are unrounded; project shots crop to 16:10.

## Components

### Panel and Identity
The name in Display beside the cut-out portrait (108px, bottom-aligned with the name) on home; under them the domain as a scale label on a seam-coloured rule, then the intro paragraph at 0.96875rem. Inner pages drop portrait and intro and use `display-slim`; they keep the domain on desktop, phones hide it. An emoji stands in when no portrait exists.

### Navigation List
A list of page titles at weight 500, 0.96875rem, separated by hairlines top and bottom, rows at least 2.5rem tall. The current page (and the ancestor of the current page) gets weight 600 and the orange 7px square, which hangs in the panel gutter 15px left of the label so the label never shifts. Hover underlines in anthracite, not orange.

### Mobile Menu Bar
On inner pages under 52rem: the name in 1.125rem bold at left, the "Menu" summary in label style at right with a 10px orange plus drawn from two bars; opening the menu collapses the vertical bar into a minus (0.2s, ease-out-expo). The same nav list with the same orange square opens below.

### Meta Line
Emoji slot, then the label (date and kind, separated by a faint dot), then a 1px rule that fills the rest of the line, then, on the newest post only, the NEW label: orange fill, near-black 700 text, 3px corners. On notes the date links to the post. The rule is the entry's only line. Project and work entries reuse the meta line with status, stack and link, or role, company and period.

### Stream Entry
Meta line, title, then the excerpt and "Continue reading" (articles), the byline with stars and full text (books), or the full text in place (notes). No separators between entries; 3.5rem of space does the separating.

### Emoji Slot
A 2rem housing-grey square with 4px corners holding the post emoji at 1rem (1.75rem on phones). On desktop it hangs in the gap left of the reading column, vertically centred on the meta line, so the labels align with the text edge.

### Work List
Own projects first: a 200px 16:10 shot (112px on phones) beside the title, meta line and description. Then a "Work" heading and the references as a text-only list, titles at 1.125rem. A project page adds a 1.1875rem lead, a 16:10 image, the content, and the facts list.

### Facts List
A two-column definition list under a rule: terms in label style, values in Body Small; stacked below 30rem.

### Books List
Year headings in label style with the count and a rule running out after them; each book a three-column row (cover or emoji 1.75rem, title over author, stars over date) separated by rules.

## Do's and Don'ts

### Do:
- **Do** keep orange to signal duties: current square, NEW, focus, link underline, selection, current page number.
- **Do** set every date, kind, status and count in the label style with tabular numerals.
- **Do** give each stream entry exactly one rule, the one after its meta label.
- **Do** put a post's emoji in the housing-grey slot of its meta line; project titles and page headings may carry their emoji inline.
- **Do** separate with the panel grey, a 1px rule or space.

### Don't:
- **Don't** add ornament without a job: no grilles, dials, keys, rails, decorative device fronts.
- **Don't** put emojis in the navigation; nav items are text plus, when current, the orange square.
- **Don't** draw separators between stream entries or box entries in cards.
- **Don't** use shadows, gradients or a second typeface.
- **Don't** colour link text orange or use faint grey for readable text.
