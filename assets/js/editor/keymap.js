// Keyboard behaviour on top of ProseMirror's base keymap: undo and redo,
// lists (Enter splits an item, Tab and Shift-Tab nest and unnest, Backspace
// at the start of an item unnests it), quotes with their caption, images,
// embeds and books (their captions, Backspace and Delete next to them),
// code blocks, table cells, marks and block types, and the keys of the
// markdown shortcuts.
import {keymap} from "prosemirror-keymap"
import {baseKeymap, chainCommands, newlineInCode, toggleMark} from "prosemirror-commands"
import {redo, undo} from "prosemirror-history"
import {liftListItem, sinkListItem, splitListItem, wrapInList} from "prosemirror-schema-list"
import {NodeSelection, TextSelection} from "prosemirror-state"
import {schema} from "./schema"
import {codeFenceOnEnter, convertibleBlock, undoInputRule} from "./markdown_shortcuts"
import {enterInCell, nextCell, previousCell} from "./tables"

const {nodes, marks} = schema

const insertHardBreak = (state, dispatch) => {
  dispatch?.(state.tr.replaceSelectionWith(nodes.hard_break.create()).scrollIntoView())
  return true
}

const cursorIn = (state, type) => {
  const {$from, empty} = state.selection
  return empty && $from.parent.type === type ? $from : null
}

// Enter in a quote's text goes on to its caption, Enter in the caption
// starts a paragraph after the quote.
const enterInQuote = (state, dispatch) => {
  const {$from} = state.selection

  if ($from.parent.type === nodes.quote_text) {
    if (dispatch) {
      const tr = state.tr.deleteSelection()
      const $text = tr.selection.$from
      tr.setSelection(TextSelection.create(tr.doc, $text.after() + 1))
      dispatch(tr.scrollIntoView())
    }
    return true
  }

  if ($from.parent.type === nodes.quote_caption) {
    if (dispatch) {
      const after = $from.after(-1)
      const tr = state.tr.insert(after, nodes.paragraph.create())
      dispatch(tr.setSelection(TextSelection.create(tr.doc, after + 1)).scrollIntoView())
    }
    return true
  }

  return false
}

const atStart = ($pos) => $pos && $pos.parentOffset === 0

// Backspace at the start of a quote: from the caption back to the text; in
// the text it turns a quote without caption into a paragraph.
const backspaceInQuote = (state, dispatch) => {
  const $caption = cursorIn(state, nodes.quote_caption)

  if (atStart($caption)) {
    dispatch?.(state.tr.setSelection(TextSelection.create(state.doc, $caption.before() - 1)))
    return true
  }

  const $text = cursorIn(state, nodes.quote_text)
  const quote = $text && $text.node(-1)

  if (atStart($text) && quote.child(1).content.size === 0) {
    if (dispatch) {
      const start = $text.before(-1)
      const paragraph = nodes.paragraph.create({id: quote.attrs.id}, quote.child(0).content)
      const tr = state.tr.replaceWith(start, start + quote.nodeSize, paragraph)
      dispatch(tr.setSelection(TextSelection.create(tr.doc, start + 1)).scrollIntoView())
    }
    return true
  }

  return false
}

// Images and embeds: a block with a caption as its text.
const captioned = (node) => node.type === nodes.image || node.type === nodes.embed

// Enter in an image or embed caption deletes the selection and starts a
// paragraph after the block (splitting would copy the image or embed).
const enterInCaption = (state, dispatch) => {
  if (!captioned(state.selection.$from.parent)) return false

  if (dispatch) {
    const tr = state.tr.deleteSelection()
    const after = tr.selection.$from.after(1)
    tr.insert(after, nodes.paragraph.create())
    dispatch(tr.setSelection(TextSelection.create(tr.doc, after + 1)).scrollIntoView())
  }
  return true
}

// Images, embeds and books are selected by Backspace before Backspace
// deletes them.
const selectedBeforeDeleting = (node) => captioned(node) || node.type === nodes.book

// Backspace at the start of an image or embed caption, or of a block right
// after an image, embed or book, selects that block instead of joining text
// into or out of the caption (or deleting the book at once); an empty block
// after it goes away. Backspace again deletes it.
const backspaceAtCaptioned = (state, dispatch) => {
  const {$from, empty} = state.selection
  if (!empty || $from.parentOffset !== 0 || $from.depth !== 1) return false

  if (captioned($from.parent)) {
    dispatch?.(state.tr.setSelection(NodeSelection.create(state.doc, $from.before())))
    return true
  }

  const index = $from.index(0)
  const before = index > 0 && state.doc.child(index - 1)
  if (!before || !selectedBeforeDeleting(before) || !$from.parent.isTextblock) return false

  if (dispatch) {
    const blockPos = $from.before() - before.nodeSize
    const tr = $from.parent.content.size ? state.tr : state.tr.delete($from.before(), $from.after())
    dispatch(tr.setSelection(NodeSelection.create(tr.doc, blockPos)).scrollIntoView())
  }
  return true
}

// Whether the cursor is at the very end of its top-level block (e.g. in the
// last list item, or in a quote's caption).
const atBlockEnd = ($pos) => {
  if ($pos.parentOffset !== $pos.parent.content.size) return false
  for (let depth = 1; depth < $pos.depth; depth++) {
    if ($pos.indexAfter(depth) !== $pos.node(depth).childCount) return false
  }
  return true
}

// Delete at the end of a block right before an image, embed or book
// selects that block (an empty paragraph or heading before it goes away),
// like Backspace after it; Delete again deletes it. At the end of a
// caption it never joins the next block into the caption.
const deleteBeforeCaptioned = (state, dispatch) => {
  const {$from, empty} = state.selection
  if (!empty || !$from.parent.isTextblock || !atBlockEnd($from)) return false

  const index = $from.index(0)
  const next = index + 1 < state.doc.childCount && state.doc.child(index + 1)
  const inCaption = captioned($from.parent)
  if (!next || !selectedBeforeDeleting(next)) return inCaption

  if (dispatch) {
    const removeEmpty = $from.depth === 1 && !inCaption && $from.parent.content.size === 0
    const tr = removeEmpty ? state.tr.delete($from.before(1), $from.after(1)) : state.tr
    const blockPos = removeEmpty ? $from.before(1) : $from.after(1)
    dispatch(tr.setSelection(NodeSelection.create(tr.doc, blockPos)).scrollIntoView())
  }
  return true
}

// Backspace at the start of a list item's first paragraph unnests the item,
// so the first item of a top-level list becomes a paragraph.
const backspaceInListItem = (state, dispatch) => {
  const $from = cursorIn(state, nodes.paragraph)
  const inItem = $from && $from.depth >= 2 && $from.node(-1).type === nodes.list_item

  if (atStart($from) && inItem && $from.index(-1) === 0) {
    return liftListItem(nodes.list_item)(state, dispatch)
  }

  return false
}

// Turns the selected blocks that a markdown shortcut could change (top-level
// paragraphs and headings) into `type`; each keeps its id.
const setBlock =
  (type, attrs = {}) =>
  (state, dispatch) => {
    const {from, to} = state.selection
    const tr = state.tr

    state.doc.nodesBetween(from, to, (_node, pos) => {
      const block = convertibleBlock(state, pos + 1)?.block
      const blockAttrs = block && {...attrs, id: block.attrs.id}
      if (block && !block.hasMarkup(type, blockAttrs)) tr.setNodeMarkup(pos, type, blockAttrs)
      return false
    })

    if (!tr.docChanged) return false
    dispatch?.(tr.scrollIntoView())
    return true
  }

// Enter on the empty last line of a code block (after a trailing newline)
// removes that newline and starts a paragraph after the block: the way out
// on keyboards without Mod-Enter or arrows.
const exitCodeOnEmptyLine = (state, dispatch) => {
  const {$from, empty} = state.selection
  const code = $from.parent
  if (!empty || code.type !== nodes.code_block || $from.parentOffset !== code.content.size) return false
  if (!code.textContent.endsWith("\n")) return false

  if (dispatch) {
    const after = $from.after() - 1
    const tr = state.tr.delete($from.pos - 1, $from.pos).insert(after, nodes.paragraph.create())
    dispatch(tr.setSelection(TextSelection.create(tr.doc, after + 1)).scrollIntoView())
  }
  return true
}

const indentCode = (state, dispatch) => {
  if (state.selection.$from.parent.type !== nodes.code_block) return false
  dispatch?.(state.tr.insertText("  ").scrollIntoView())
  return true
}

export const editorKeymap = () =>
  keymap({
    "Mod-z": undo,
    "Shift-Mod-z": redo,
    "Mod-y": redo,

    Enter: chainCommands(
      codeFenceOnEnter,
      exitCodeOnEmptyLine,
      enterInCell,
      splitListItem(nodes.list_item),
      enterInQuote,
      enterInCaption
    ),
    "Shift-Enter": chainCommands(newlineInCode, insertHardBreak),
    Backspace: chainCommands(undoInputRule, backspaceInListItem, backspaceInQuote, backspaceAtCaptioned),
    Delete: deleteBeforeCaptioned,
    "Mod-Delete": deleteBeforeCaptioned,
    Tab: chainCommands(indentCode, nextCell, sinkListItem(nodes.list_item)),
    "Shift-Tab": chainCommands(previousCell, liftListItem(nodes.list_item)),

    "Mod-b": toggleMark(marks.bold),
    "Mod-i": toggleMark(marks.italic),
    "Mod-u": toggleMark(marks.underline),
    "Mod-e": toggleMark(marks.code),

    "Mod-Alt-0": setBlock(nodes.paragraph),
    "Mod-Alt-2": setBlock(nodes.heading, {level: 2}),
    "Mod-Alt-3": setBlock(nodes.heading, {level: 3}),
    "Mod-Alt-4": setBlock(nodes.heading, {level: 4}),
    "Shift-Mod-7": wrapInList(nodes.ordered_list),
    "Shift-Mod-8": wrapInList(nodes.bullet_list)
  })

export const baseKeys = () => keymap(baseKeymap)
