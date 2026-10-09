// Moving and selecting top-level blocks as a whole. A moved block is the
// same node, so it keeps its id; each move is one transaction and one undo
// step of its own.
import {closeHistory} from "prosemirror-history"
import {NodeSelection} from "prosemirror-state"

// The document position before the top-level block at `index` (or after
// the last one for `index` = childCount).
export function blockStart(doc, index) {
  let pos = 0
  for (let i = 0; i < index; i++) pos += doc.child(i).nodeSize
  return pos
}

// Selects the top-level block at `index` as a whole.
export const selectBlock = (index) => (state, dispatch) => {
  if (index < 0 || index >= state.doc.childCount) return false
  dispatch?.(state.tr.setSelection(NodeSelection.create(state.doc, blockStart(state.doc, index))))
  return true
}

// Moves the top-level block at `from` to the gap `to` (0 is before the
// first block, childCount after the last) and selects it there.
export const moveBlock = (from, to) => (state, dispatch) => {
  const {doc} = state
  if (from < 0 || from >= doc.childCount || to < 0 || to > doc.childCount) return false
  if (to === from || to === from + 1) return false

  if (dispatch) {
    const node = doc.child(from)
    const start = blockStart(doc, from)
    const tr = state.tr.delete(start, start + node.nodeSize)
    const target = tr.mapping.map(blockStart(doc, to))
    tr.insert(target, node).setSelection(NodeSelection.create(tr.doc, target))
    dispatch(closeHistory(tr).scrollIntoView())
  }
  return true
}

// The indices of the first and the last top-level block the selection
// touches.
export function selectedBlocks({selection}) {
  const {$from, $to} = selection
  const first = $from.index(0)
  const last = $to.depth === 0 ? $to.index(0) - 1 : $to.index(0)
  return {first, last: Math.max(first, last)}
}

// Moves the blocks the selection touches one place up (-1) or down (1) by
// moving their neighbour to their other side, so the selection stays as
// it is.
export const moveSelectedBlocks = (direction) => (state, dispatch) => {
  const {doc} = state
  const {first, last} = selectedBlocks(state)
  const neighbour = direction < 0 ? first - 1 : last + 1
  if (neighbour < 0 || neighbour >= doc.childCount) return false

  if (dispatch) {
    const node = doc.child(neighbour)
    const start = blockStart(doc, neighbour)
    const tr = state.tr.delete(start, start + node.nodeSize)
    const target = tr.mapping.map(blockStart(doc, direction < 0 ? last + 1 : first), -1)
    tr.insert(target, node)
    dispatch(closeHistory(tr).scrollIntoView())
  }
  return true
}
