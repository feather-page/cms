import {Selection} from "prosemirror-state"

const DIRECTIONS = {ArrowUp: "up", ArrowLeft: "left", ArrowDown: "down", ArrowRight: "right"}

const hidden = (view, pos) => {
  const {node} = view.domAtPos(pos)
  const el = node.nodeType === Node.TEXT_NODE ? node.parentNode : node
  return el.getClientRects().length === 0
}

// Browsers skip a source hidden behind its rendered copy (display: none), so the arrow keys
// that would leave a textblock towards it put the cursor into it instead.
export const arrowIntoHiddenSource = (typeName) => (view, event) => {
  const dir = DIRECTIONS[event.key]
  if (!dir || event.shiftKey || event.altKey || event.ctrlKey || event.metaKey) return false

  const {empty, $head} = view.state.selection
  if (!empty || !$head.parent.isTextblock || !view.endOfTextblock(dir)) return false

  const forward = dir === "down" || dir === "right"
  const $from = view.state.doc.resolve(forward ? $head.after() : $head.before())
  const target = Selection.findFrom($from, forward ? 1 : -1, true)
  if (!target || target.$head.parent.type.name !== typeName || !hidden(view, target.head)) return false

  view.dispatch(view.state.tr.setSelection(target).scrollIntoView())
  return true
}
