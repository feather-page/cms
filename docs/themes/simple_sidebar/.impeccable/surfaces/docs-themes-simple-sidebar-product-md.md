---
version: 1
slug: "docs-themes-simple-sidebar-product-md"
primary_target: "docs/themes/simple_sidebar/PRODUCT.md"
related_targets: []
---

# Simple sidebar theme (rocu.de)

Scope: every page a site renders with the `simple_sidebar` theme, first rocu.de (home stream, post, page, books list, projects list, project, tags, 404). Visitor mode: Read.

Audience and job: Robert's own log, read by friends (often for books) and now and then by potential employers; they should find out at once who Robert is and read comfortably. Content: titled articles, untitled micro-posts in full, book posts, photo posts, standing pages, a Projects section (own projects first as a work list, then work references).

Constraints: static HTML and CSS, works without JavaScript, small pages; one self-hosted text face; zipfelmaus and every other site keep the `feather` theme.

History: round 1 (Bauhaus poster planes, LCD dates) rejected as too loud; round 2 picked the quiet sidebar (green signal); round 3 moved to Dieter Rams' industrial design, bolder: the decorative device front and the 606 shelving were rejected as useless or too much; the approved sketch is "C2", desktop and mobile (kept locally, not in the repo), with two corrections: the same orange square marks the current page everywhere, and stream entries carry one rule (after the meta line), no separators between posts.

Unresolved: the career block on About me (content).

## Direction contract

THESIS: Dieter Rams' industrial design, only where it works: a housing-grey panel names the person in a bold type designation and lists the pages; the reading column is calm type on off-white with scale-printed meta lines; one signal orange. It refuses decoration that has no job (grilles, dials, keys, rails) and the empty one-column template.

OWN-WORLD: Off-white page ground, housing-grey panel with a crisp 1px seam, anthracite ink, darker-grey hairlines, quiet grey for secondary text, one signal orange used only for function (current-page square, the NEW label on the newest post, focus, link underline colour, selection, current pagination). Link text anthracite. Schibsted Grotesk 400 to 700, self-hosted; meta and labels as scale printing (tiny tracked uppercase, tabular numerals, a thin rule after). No shadows, gradients, boxes or ornament; post emojis in colour in a small fixed housing-grey slot; no emojis in the navigation.

STORY: A visitor sees a person at once (bold name, portrait, a short bio) and six clearly listed pages, then reads the newest posts directly; notes are complete in place, articles invite "Continue reading". On any other page the content leads and the frame steps back. They leave thinking: careful web craftsman.

FIRST VIEWPORT: Desktop home: left panel ~400px, name ~54px/700 beside the cut-out portrait, the domain as a scale label on a rule, the bio, the hairline nav list, GitHub and LinkedIn as scale labels at the foot; right a ~36rem reading column, each entry an emoji slot, a scale-printed meta line with a rule (orange NEW on the newest), title ~27px/700, text 17-18px. Desktop inner pages: the same panel, portrait and bio included, with the name capped below the page h1. Mobile home: compact identity (name + portrait) without the bio, nav as running text; first post on the first screen. Mobile inner pages: one bar with the name small (home link) and a native "Menu" disclosure holding the nav; the content starts right below. On every phone page the bio sits in the footer beside the portrait.

FORM: approved sketch C2 from the round-3 safer/bolder iteration requested by Robert; seed: c6f4e1e84e0d58e0

Signature: the orange NEW label and current-page square, the only colour on the page besides the post emojis.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
