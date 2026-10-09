// Markdown shortcuts, like in Notion. Typed at the start of a block they
// turn it into another block type, which keeps the block's id: "## ", "### "
// and "#### " (and "# ") a heading, "- ", "* " or "+ " a bulleted list,
// "1. " a numbered list, "> " a quote and "``` " (or "```js ", or "```js"
// and Enter) a code block. Inline, **bold**, *italic*, _italic_ and `code`
// become marks. Backspace right after a shortcut takes it back.
import {InputRule, inputRules, undoInputRule} from "prosemirror-inputrules"
import {TextSelection} from "prosemirror-state"
import {schema} from "./schema"

const {nodes, marks} = schema

// How many characters at the end of the match were just typed: the rest is
// in the document from `start` to `end`. Null when that range holds more
// than the match (text typed over a selection).
const typedPart = (match, start, end) => (end - start <= match[0].length ? match[0].length - (end - start) : null)

// A block shortcut applies in a top-level paragraph or heading, the only
// text blocks a list, quote or code block may take the place of (and the
// block type keys only change these, see keymap.js).
export function convertibleBlock(state, start) {
  const $start = state.doc.resolve(start)
  const block = $start.parent
  if ($start.depth !== 1 || ![nodes.paragraph, nodes.heading].includes(block.type)) return null
  return {pos: $start.before(), block}
}

function blockRule(regexp, convert) {
  return new InputRule(regexp, (state, match, start, end) => {
    const target = typedPart(match, start, end) != null && convertibleBlock(state, start)
    if (!target) return null

    const tr = state.tr.delete(start, end)
    const block = tr.doc.nodeAt(target.pos)
    return convert(tr, target.pos, block, match)
  })
}

// Replaces the block at `pos` by `node` and puts the cursor at the start of
// its text, `depth` levels down.
function replaceBlock(tr, pos, block, node, depth) {
  tr.replaceWith(pos, pos + block.nodeSize, node)
  return tr.setSelection(TextSelection.create(tr.doc, pos + depth)).scrollIntoView()
}

const toHeading = (tr, pos, block, match) => {
  const level = Math.max(match[1].length, 2)
  if (block.type === nodes.heading && block.attrs.level === level) return null
  return tr.setNodeMarkup(pos, nodes.heading, {id: block.attrs.id, level}).scrollIntoView()
}

const toList = (type) => (tr, pos, block) => {
  const item = nodes.list_item.create(null, nodes.paragraph.create(null, block.content))
  return replaceBlock(tr, pos, block, type.create({id: block.attrs.id}, item), 3)
}

const toQuote = (tr, pos, block) => {
  const quote = nodes.quote.create({id: block.attrs.id}, [
    nodes.quote_text.create(null, block.content),
    nodes.quote_caption.create()
  ])
  return replaceBlock(tr, pos, block, quote, 2)
}

const codeLanguage = (typed) => typed.toLowerCase() || "plaintext"

// The block's text as code: marks are dropped, line breaks become newlines.
function toCodeBlock(tr, pos, block, language) {
  const code = block.textBetween(0, block.content.size, null, (leaf) => (leaf.type === nodes.hard_break ? "\n" : ""))
  const node = nodes.code_block.create({id: block.attrs.id, language}, code ? schema.text(code) : null)
  return replaceBlock(tr, pos, block, node, 1)
}

const FENCE = /^```([\w+#-]*)$/

// Enter at the end of a block holding only "```" or "```js" turns it into
// a code block, as in a markdown file.
export function codeFenceOnEnter(state, dispatch) {
  const {$from, empty} = state.selection
  if (!empty || $from.parentOffset !== $from.parent.content.size) return false

  const target = convertibleBlock(state, $from.pos)
  const text = target?.block.textContent
  const fence = target && target.block.content.size === text.length && FENCE.exec(text)
  if (!fence) return false

  if (dispatch) {
    const tr = state.tr.delete($from.start(), $from.pos)
    dispatch(toCodeBlock(tr, target.pos, tr.doc.nodeAt(target.pos), codeLanguage(fence[1])))
  }
  return true
}

// Text between two delimiters gets the mark. The opening delimiter does not
// follow a letter or digit (so snake_case and 2*3*4 stay as they are), and
// the text does not start or end with a space, except in `code`.
function markRule(regexp, delimiter, markType) {
  return new InputRule(
    regexp,
    (state, match, start, end) => {
      const typed = typedPart(match, start, end)
      if (typed == null) return null

      const [full, lead, text] = match
      const tr = state.tr.insertText(full.slice(full.length - typed), end)
      const open = start + lead.length
      const close = open + delimiter.length + text.length

      tr.delete(close, close + delimiter.length).delete(open, open + delimiter.length)
      return tr.addMark(open, open + text.length, markType.create()).removeStoredMark(markType)
    },
    {inCodeMark: false}
  )
}

const BOLD = /(^|[^\p{L}\p{N}_*])\*\*([^*\s\ufffc](?:[^*\ufffc]*[^*\s\ufffc])?)\*\*$/u
const ITALIC = /(^|[^\p{L}\p{N}_*])\*([^*\s\ufffc](?:[^*\ufffc]*[^*\s\ufffc])?)\*$/u
const UNDERSCORE_ITALIC = /(^|[^\p{L}\p{N}_])_([^_\s\ufffc](?:[^_\ufffc]*[^_\s\ufffc])?)_$/u
const CODE = /(^|[^`])`([^`\ufffc]+)`$/u

export const markdownShortcuts = () =>
  inputRules({
    rules: [
      blockRule(/^(#{1,4})\s$/, toHeading),
      blockRule(/^[-*+]\s$/, toList(nodes.bullet_list)),
      blockRule(/^1[.)]\s$/, toList(nodes.ordered_list)),
      blockRule(/^>\s$/, toQuote),
      blockRule(/^```([\w+#-]*)\s$/, (tr, pos, block, match) => toCodeBlock(tr, pos, block, codeLanguage(match[1]))),
      markRule(BOLD, "**", marks.bold),
      markRule(ITALIC, "*", marks.italic),
      markRule(UNDERSCORE_ITALIC, "_", marks.italic),
      markRule(CODE, "`", marks.code)
    ]
  })

export {undoInputRule}
