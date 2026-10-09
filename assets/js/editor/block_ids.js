// Gives every top-level node a block id of its own: new and pasted blocks
// come without one, and splitting a block copies its id to the second half.
// The first node with an id keeps it, later duplicates get a fresh one.
import {Plugin} from "prosemirror-state"

const ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

// Same shape as the ids the server generates (Feather.Content.Blocks).
export const generateId = () =>
  Array.from(crypto.getRandomValues(new Uint8Array(10)), (byte) => ALPHABET[byte % ALPHABET.length]).join("")

// A transaction that fixes missing and duplicate ids, or null if all are fine.
export function assignBlockIds(state) {
  const seen = new Set()
  let tr = null

  state.doc.forEach((node, offset) => {
    let id = node.attrs.id

    if (!id || seen.has(id)) {
      do id = generateId()
      while (seen.has(id))
      tr = (tr || state.tr).setNodeMarkup(offset, null, {...node.attrs, id})
    }

    seen.add(id)
  })

  return tr
}

export const blockIds = () =>
  new Plugin({
    appendTransaction: (transactions, _oldState, newState) =>
      transactions.some((tr) => tr.docChanged) ? assignBlockIds(newState) : null
  })
