// The ProseMirror schema of the block editor. It must match the server's
// schema in Feather.Content.ProseMirror node for node, mark for mark and
// attr for attr (see its moduledoc): the server converts the document to
// and from the stored block list.
//
// Every top-level node carries its block id in `id`. Ids are not written
// to the DOM, so pasted copies come in without one and get a fresh id
// (see block_ids.js).
//
// The parseDOM rules also read HTML pasted from other apps (browsers, Google
// Docs, Word): content the schema has no place for is dropped or flattened.
import {DOMParser, Fragment, Schema} from "prosemirror-model"
import {tableNodes} from "prosemirror-tables"
import {recognizeEmbed} from "./embed_services"

const id = {id: {default: null}}

const tables = tableNodes({tableGroup: "block", cellContent: "inline*", cellAttributes: {}})

// The inline content of `dom`, its paragraphs (and other textblocks) joined
// with line breaks: for nodes that hold one run of text, like a quote or a
// table cell, but receive several paragraphs when pasted.
function inlineContent(dom, schema) {
  const lines = []
  DOMParser.fromSchema(schema)
    .parse(dom)
    .descendants((node) => {
      if (!node.isTextblock) return true
      lines.push(node.content)
      return false
    })

  return lines.reduce(
    (inline, line, index) => (index ? inline.addToEnd(schema.nodes.hard_break.create()).append(line) : line),
    Fragment.empty
  )
}

const ownQuote = (dom) => (dom.querySelector(":scope > .pm-quote__text") ? null : false)

// The editor's own <pre data-language>, or the language-* class markdown
// renderers put on <pre> or <code>.
function codeLanguage(dom) {
  const own = dom.getAttribute("data-language")
  if (own) return own

  const classes = [dom, dom.querySelector("code")].map((el) => el?.getAttribute("class") || "").join(" ")
  return classes.match(/(?:^|\s)(?:language|lang)-([\w+#-]+)/)?.[1] || "plaintext"
}

// Like Feather.Content.HTML.safe_url?/1: relative, or http(s), mailto, tel.
// A pasted link with any other href is kept as plain text, and the
// formatting toolbar refuses it.
export function safeHref(href) {
  const scheme = href.replace(/[\x00-\x20\x7F-\x9F\p{Z}\p{Cf}]/gu, "").toLowerCase().match(/^([^/?#]*?):/)
  return !scheme || ["http", "https", "mailto", "tel"].includes(scheme[1])
}

// Image, embed and book blocks hold nothing until they get an image, a URL
// or a book of the bookshelf; the server drops them until then. Every other
// block is filled, even without text.
const HOLDS = {
  image: (attrs) => attrs.image_id,
  embed: (attrs) => attrs.source || attrs.embed,
  book: (attrs) => attrs.book_public_id
}

export const filled = (node) => {
  const holds = HOLDS[node.type.name]
  return holds ? Boolean(holds(node.attrs)) : true
}

const cellRules = (rules) => rules.map((rule) => ({...rule, getContent: inlineContent}))

export const schema = new Schema({
  nodes: {
    doc: {content: "block+"},

    paragraph: {
      group: "block",
      content: "inline*",
      attrs: id,
      parseDOM: [{tag: "p"}],
      toDOM: () => ["p", 0]
    },

    heading: {
      group: "block",
      content: "inline*",
      attrs: {...id, level: {default: 2}},
      defining: true,
      // The block list knows levels 2 to 4: h1 becomes 2, h5 and h6 become 4.
      parseDOM: [1, 2, 3, 4, 5, 6].map((level) => ({
        tag: `h${level}`,
        attrs: {level: Math.min(Math.max(level, 2), 4)}
      })),
      toDOM: (node) => [`h${node.attrs.level}`, 0]
    },

    bullet_list: {
      group: "block",
      content: "list_item+",
      attrs: id,
      parseDOM: [{tag: "ul"}],
      toDOM: () => ["ul", 0]
    },

    ordered_list: {
      group: "block",
      content: "list_item+",
      attrs: id,
      parseDOM: [{tag: "ol"}],
      toDOM: () => ["ol", 0]
    },

    list_item: {
      content: "paragraph (bullet_list | ordered_list)*",
      defining: true,
      parseDOM: [{tag: "li"}],
      toDOM: () => ["li", 0]
    },

    quote: {
      group: "block",
      content: "quote_text quote_caption",
      attrs: id,
      defining: true,
      // The editor's own copies keep their caption; any other quote becomes
      // the quote text.
      parseDOM: [
        {tag: "blockquote", getAttrs: ownQuote},
        {
          tag: "blockquote",
          getContent: (dom, schema) =>
            Fragment.from([
              schema.nodes.quote_text.create(null, inlineContent(dom, schema)),
              schema.nodes.quote_caption.create()
            ])
        }
      ],
      toDOM: () => ["blockquote", {class: "pm-quote"}, 0]
    },

    quote_text: {
      content: "inline*",
      parseDOM: [{tag: "div.pm-quote__text"}],
      toDOM: () => ["div", {class: "pm-quote__text"}, 0]
    },

    quote_caption: {
      content: "inline*",
      parseDOM: [{tag: "div.pm-quote__caption"}],
      toDOM: () => ["div", {class: "pm-quote__caption"}, 0]
    },

    code_block: {
      group: "block",
      content: "text*",
      marks: "",
      code: true,
      defining: true,
      attrs: {...id, language: {default: "plaintext"}},
      parseDOM: [{tag: "pre", preserveWhitespace: "full", getAttrs: (dom) => ({language: codeLanguage(dom)})}],
      toDOM: (node) => ["pre", {"data-language": node.attrs.language}, ["code", 0]]
    },

    image: {
      group: "block",
      content: "inline*",
      attrs: {...id, image_id: {default: null}, src: {default: null}},
      // Only the editor's own copies: images from other apps would need an
      // upload first, and an empty image block has nothing to copy.
      parseDOM: [
        {
          tag: "figure[data-image-id]",
          contentElement: (dom) => dom.querySelector("figcaption") || document.createElement("figcaption"),
          getAttrs: (dom) => ({
            image_id: dom.getAttribute("data-image-id"),
            src: dom.querySelector("img")?.getAttribute("src") || null
          })
        }
      ],
      toDOM: (node) => [
        "figure",
        {"data-image-id": node.attrs.image_id},
        ["img", {src: node.attrs.src}],
        ["figcaption", 0]
      ]
    },

    table: {...tables.table, attrs: id},
    table_row: tables.table_row,
    table_cell: {...tables.table_cell, parseDOM: cellRules(tables.table_cell.parseDOM)},
    table_header: {...tables.table_header, parseDOM: cellRules(tables.table_header.parseDOM)},

    embed: {
      group: "block",
      content: "inline*",
      attrs: {
        ...id,
        service: {default: null},
        source: {default: null},
        embed: {default: null},
        width: {default: null},
        height: {default: null}
      },
      // Only the editor's own copies, and their attrs only from the source
      // URL, so pasted HTML cannot bring in any other embed URL.
      parseDOM: [
        {
          tag: "figure[data-embed-source]",
          contentElement: (dom) => dom.querySelector("figcaption") || document.createElement("figcaption"),
          getAttrs: (dom) => recognizeEmbed(dom.getAttribute("data-embed-source")) || false
        }
      ],
      toDOM: (node) => [
        "figure",
        {"data-service": node.attrs.service, "data-embed-source": node.attrs.source},
        ["figcaption", 0]
      ]
    },

    book: {
      group: "block",
      atom: true,
      attrs: {
        ...id,
        book_public_id: {default: null},
        title: {default: null},
        author: {default: null},
        cover_url: {default: null},
        emoji: {default: null}
      },
      // The editor's own copies only. The server keeps a book only if it is
      // one of the site's and takes its details from the bookshelf.
      parseDOM: [
        {
          tag: "div[data-book-id]",
          priority: 60,
          getAttrs: (dom) => ({
            book_public_id: dom.getAttribute("data-book-id"),
            title: dom.getAttribute("data-title"),
            author: dom.getAttribute("data-author"),
            cover_url: dom.getAttribute("data-cover-url"),
            emoji: dom.getAttribute("data-emoji")
          })
        }
      ],
      toDOM: (node) => [
        "div",
        {
          class: "pm-book",
          "data-book-id": node.attrs.book_public_id,
          "data-title": node.attrs.title,
          "data-author": node.attrs.author,
          "data-cover-url": node.attrs.cover_url,
          "data-emoji": node.attrs.emoji
        },
        [node.attrs.title, node.attrs.author].filter(Boolean).join(", ") || "Book"
      ]
    },

    text: {group: "inline"},

    hard_break: {
      group: "inline",
      inline: true,
      selectable: false,
      parseDOM: [{tag: "br"}],
      toDOM: () => ["br"]
    }
  },

  // The order decides how marks nest; it matches the server's.
  marks: {
    link: {
      attrs: {href: {default: null}, target: {default: null}, rel: {default: null}},
      inclusive: false,
      parseDOM: [
        {
          tag: "a[href]",
          getAttrs: (dom) =>
            safeHref(dom.getAttribute("href")) && {
              href: dom.getAttribute("href"),
              target: dom.getAttribute("target"),
              rel: dom.getAttribute("rel")
            }
        }
      ],
      toDOM: (mark) => ["a", {href: mark.attrs.href, target: mark.attrs.target, rel: mark.attrs.rel}, 0]
    },

    bold: {
      parseDOM: [
        {tag: "strong"},
        // Google Docs wraps the whole clipboard in <b style="font-weight:normal">.
        {tag: "b", getAttrs: (dom) => dom.style.fontWeight != "normal" && null},
        {style: "font-weight=400", clearMark: (mark) => mark.type.name == "bold"},
        {style: "font-weight=normal", clearMark: (mark) => mark.type.name == "bold"},
        {style: "font-weight", getAttrs: (value) => /^(bold(er)?|[5-9]\d{2})$/.test(value) && null}
      ],
      toDOM: () => ["b", 0]
    },

    italic: {
      parseDOM: [
        {tag: "i"},
        {tag: "em"},
        {style: "font-style=italic"},
        {style: "font-style=normal", clearMark: (mark) => mark.type.name == "italic"}
      ],
      toDOM: () => ["i", 0]
    },

    underline: {
      parseDOM: [
        {tag: "u"},
        {style: "text-decoration", getAttrs: (value) => value.includes("underline") && null},
        {style: "text-decoration-line", getAttrs: (value) => value.includes("underline") && null}
      ],
      toDOM: () => ["u", 0]
    },

    code: {
      code: true,
      parseDOM: [{tag: "code"}, {tag: "kbd"}, {tag: "samp"}, {tag: "tt"}],
      toDOM: () => ["code", 0]
    }
  }
})
