// Placeholders in empty text blocks: always for headings, quotes and their
// captions, for a top-level paragraph when it is the only block or holds
// the cursor (CSS hides the latter while the editor is not focused).
import {Plugin} from "prosemirror-state"
import {Decoration, DecorationSet} from "prosemirror-view"

const PROMPT = "Start writing, or type / for blocks…"

const text = (node, parent, state, pos) => {
  switch (node.type.name) {
    case "heading":
      return `Heading ${node.attrs.level}`
    case "quote_text":
      return "Quote"
    case "quote_caption":
      return "Caption"
    case "paragraph": {
      if (parent !== state.doc) return null
      if (state.doc.childCount === 1) return PROMPT
      const {$from, empty} = state.selection
      return empty && $from.parent === node && $from.before() === pos ? PROMPT : null
    }
    default:
      return null
  }
}

const decorations = (state) => {
  const found = []

  state.doc.descendants((node, pos, parent) => {
    if (!node.isTextblock) return true
    if (node.content.size > 0) return false

    const placeholder = text(node, parent, state, pos)
    if (placeholder) {
      found.push(Decoration.node(pos, pos + node.nodeSize, {class: "is-empty", "data-placeholder": placeholder}))
    }
    return false
  })

  return DecorationSet.create(state.doc, found)
}

export const placeholder = () => new Plugin({props: {decorations}})
