// The block editor: a ProseMirror view over the schema in schema.js.
import {Node} from "prosemirror-model"
import {EditorState} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {history} from "prosemirror-history"
import {dropCursor} from "prosemirror-dropcursor"
import {gapCursor} from "prosemirror-gapcursor"
import {fixTables, tableEditing} from "prosemirror-tables"
import {schema} from "./schema"
import {assignBlockIds, blockIds} from "./block_ids"
import {baseKeys, editorKeymap} from "./keymap"
import {codeBlockView} from "./code_block"
import {ImageUploads, imageDrops, imageView} from "./images"
import {embedPaste, embedView} from "./embeds"
import {BookLookup, bookView} from "./books"
import {placeholder} from "./placeholder"
import {slashMenu} from "./slash_menu"
import {markdownShortcuts} from "./markdown_shortcuts"
import {formatToolbar} from "./format_toolbar"
import {blockHandle} from "./block_handle"
import {formatTables, tableFormat, tableView} from "./tables"
import {tableMenu} from "./table_menu"

// A document from its JSON (string or object). Without blocks it gets one
// empty paragraph, since a document needs at least one. Throws when the
// JSON does not fit the schema.
export function parseDoc(json) {
  const data = typeof json === "string" ? JSON.parse(json) : json
  if (!data?.content?.length) return schema.topNodeType.createAndFill()

  const doc = Node.fromJSON(schema, data)
  doc.check()
  return doc
}

export function createState(json, {uploads = new ImageUploads()} = {}) {
  const state = EditorState.create({
    schema,
    doc: parseDoc(json),
    plugins: [
      imageDrops(uploads),
      embedPaste(),
      slashMenu(),
      markdownShortcuts(),
      formatToolbar(),
      blockHandle(),
      tableMenu(),
      editorKeymap(),
      baseKeys(),
      history(),
      dropCursor(),
      gapCursor(),
      // A selected table stays a selected block (block handle, Backspace).
      tableEditing({allowTableNodeSelection: true}),
      tableFormat(),
      blockIds(),
      placeholder()
    ]
  })

  return [fixTables, formatTables, assignBlockIds].reduce((current, fix) => {
    const tr = fix(current)
    return tr ? current.apply(tr.setMeta("addToHistory", false)) : current
  }, state)
}

// Mounts the editor in `mount`. `onChange(doc)` is called after every
// change of the document. `images` names the image endpoints and the CSRF
// token (see ImageUploads in images.js), `books` the book lookup (see
// BookLookup in books.js).
export function createEditor(mount, json, {label, onChange, images = {}, books = {}}) {
  const uploads = new ImageUploads(images)
  const view = new EditorView(mount, {
    state: createState(json, {uploads}),
    nodeViews: {
      code_block: codeBlockView,
      image: imageView(uploads),
      embed: embedView,
      table: tableView,
      book: bookView(new BookLookup(books))
    },
    attributes: {
      class: "block-editor__document",
      role: "textbox",
      "aria-multiline": "true",
      "aria-label": label
    },
    dispatchTransaction(tr) {
      view.updateState(view.state.apply(tr))
      if (tr.docChanged) onChange(view.state.doc)
    }
  })

  return view
}
