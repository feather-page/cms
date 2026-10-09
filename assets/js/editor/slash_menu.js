// The slash menu: a "/" typed at the start of a text block or after a space
// opens a menu of the block types in slash_items.js, filtered by what is
// typed after the slash. Arrow keys move through it, Enter or Tab (or a
// click or tap) chooses, Escape closes it. It closes as well when nothing
// matches, the cursor leaves the slash's text or the editor loses focus.
// Code blocks and table cells never open it (a cell is no place for a
// block, and an empty table must not be replaced by one).
import {closeHistory} from "prosemirror-history"
import {NodeSelection, Plugin, PluginKey, Selection} from "prosemirror-state"
import {generateId} from "./block_ids"
import {filled} from "./schema"
import {slashItems} from "./slash_items"

export const slashMenuKey = new PluginKey("slashMenu")

const opensAfter = (text) => text === "" || /\s$/.test(text)

const opensIn = (textblock) => textblock.inlineContent && !textblock.type.spec.code && !textblock.type.spec.tableRole

// The open menu: the slash at `from`, the query up to the cursor at `to`,
// the matching items and the active one. Null when closed.
function menuAt(state, from, index) {
  const {$from, empty} = state.selection
  if (!empty || !opensIn($from.parent) || from < $from.start() || from >= $from.pos) return null

  const text = state.doc.textBetween(from, $from.pos, null, "\ufffc")
  if (!text.startsWith("/")) return null

  const items = slashItems(text.slice(1))
  if (!items.length) return null

  return {from, to: $from.pos, items, index: Math.min(index, items.length - 1)}
}

function applyMenu(tr, menu, _oldState, state) {
  const meta = tr.getMeta(slashMenuKey)

  if (meta?.close) return null
  if (meta?.open != null) return menuAt(state, meta.open, 0)
  if (!menu) return null

  return menuAt(state, tr.mapping.map(menu.from), meta?.index ?? menu.index)
}

// Opens the menu when a "/" is typed where it may open. Text typed in one
// go (a composition, for example) counts by its last character.
function openOnSlash(view, from, to, text, insertText) {
  const $from = view.state.doc.resolve(from)
  if (!text.endsWith("/") || !opensIn($from.parent)) return false

  const before = $from.parent.textBetween(0, $from.parentOffset, null, "\ufffc") + text.slice(0, -1)
  if (!opensAfter(before)) return false

  view.dispatch(insertText().setMeta(slashMenuKey, {open: from + text.length - 1}))
  return true
}

const moveActive = (view, menu, step) => {
  const index = (menu.index + step + menu.items.length) % menu.items.length
  view.dispatch(view.state.tr.setMeta(slashMenuKey, {index}))
}

const closeMenu = (view) => view.dispatch(view.state.tr.setMeta(slashMenuKey, {close: true}))

// A filled image or embed (a block holding something besides its text) is
// never empty, even without a caption.
const isEmptyBlock = (block) => {
  if (["image", "embed"].includes(block.type.name) && filled(block)) return false
  let empty = true
  block.descendants((node) => {
    if (node.isInline || node.isAtom) empty = false
    return empty
  })
  return empty && !block.isAtom
}

function selectionIn(doc, pos) {
  const node = doc.nodeAt(pos)
  if (node.isAtom && NodeSelection.isSelectable(node)) return NodeSelection.create(doc, pos)

  return Selection.findFrom(doc.resolve(pos + 1), 1, true) || Selection.near(doc.resolve(pos))
}

// Removes the slash and the query, then puts the item's block in place of
// the slash's block if that is empty now, else after it. Undo then brings
// back the typed slash and query.
export function chooseItem(view, item) {
  const menu = slashMenuKey.getState(view.state)
  if (!menu) return false

  const tr = closeHistory(view.state.tr).delete(menu.from, menu.to)
  const $slash = tr.doc.resolve(menu.from)
  const block = $slash.node(1)
  const created = item.create(view.state.schema)
  let pos

  if (isEmptyBlock(block)) {
    pos = $slash.before(1)
    const node = created.type.create({...created.attrs, id: block.attrs.id}, created.content, created.marks)
    tr.replaceWith(pos, pos + block.nodeSize, node)
  } else {
    pos = $slash.after(1)
    tr.insert(pos, created)
  }

  view.dispatch(tr.setSelection(selectionIn(tr.doc, pos)).setMeta(slashMenuKey, {close: true}).scrollIntoView())
  view.focus()
  return true
}

function handleKeyDown(view, event) {
  const menu = slashMenuKey.getState(view.state)
  if (!menu || event.isComposing) return false

  switch (event.key) {
    case "ArrowDown":
      moveActive(view, menu, 1)
      return true
    case "ArrowUp":
      moveActive(view, menu, -1)
      return true
    case "Enter":
    case "Tab":
      return chooseItem(view, menu.items[menu.index])
    case "Escape":
      closeMenu(view)
      return true
    default:
      return false
  }
}

// The menu's DOM, placed under the cursor (above it when there is no room
// below, e.g. over an on-screen keyboard).
class MenuView {
  constructor(view, id) {
    this.view = view
    this.id = id
    this.shown = null

    this.dom = document.createElement("div")
    this.dom.className = "slash-menu"
    this.dom.id = id
    this.dom.setAttribute("role", "listbox")
    this.dom.setAttribute("aria-label", "Blocks")
    this.dom.hidden = true
    // Keeps the focus (and an on-screen keyboard) in the editor.
    this.dom.addEventListener("mousedown", (event) => event.preventDefault())
    this.dom.addEventListener("click", (event) => this.onClick(event))
    this.dom.addEventListener("mousemove", (event) => this.onHover(event))
    view.dom.parentNode.appendChild(this.dom)

    this.reposition = () => this.place()
    window.addEventListener("scroll", this.reposition, true)
    window.visualViewport?.addEventListener("resize", this.reposition)
    window.visualViewport?.addEventListener("scroll", this.reposition)
    this.update(view)
  }

  update(view) {
    const menu = slashMenuKey.getState(view.state)
    this.dom.hidden = !menu
    if (!menu) {
      this.shown = null
      return
    }

    const names = menu.items.map(({name}) => name).join(" ")
    if (names !== this.shown) this.render(menu.items)
    this.shown = names

    for (const [index, option] of [...this.dom.children].entries()) {
      option.classList.toggle("is-active", index === menu.index)
      option.setAttribute("aria-selected", String(index === menu.index))
    }
    this.place()
    this.scrollToActive(menu.index)
  }

  render(items) {
    this.dom.replaceChildren(
      ...items.map((item) => {
        const option = document.createElement("button")
        option.type = "button"
        option.className = "slash-menu__item"
        option.id = optionId(this.id, item)
        option.dataset.name = item.name
        option.setAttribute("role", "option")
        option.tabIndex = -1

        const icon = document.createElement("span")
        icon.className = "slash-menu__icon"
        icon.setAttribute("aria-hidden", "true")
        icon.textContent = item.icon
        option.append(icon, item.label)
        return option
      })
    )
  }

  place() {
    const menu = slashMenuKey.getState(this.view.state)
    if (!menu) return

    const caret = this.view.coordsAtPos(menu.from)
    const viewport = window.visualViewport
    const bottom = viewport ? viewport.offsetTop + viewport.height : window.innerHeight
    const right = viewport ? viewport.offsetLeft + viewport.width : window.innerWidth
    const height = this.dom.offsetHeight
    const below = caret.bottom + 6
    const top = below + height > bottom && caret.top - height - 6 > 0 ? caret.top - height - 6 : below

    this.dom.style.top = `${top}px`
    this.dom.style.left = `${Math.max(8, Math.min(caret.left, right - this.dom.offsetWidth - 8))}px`
  }

  scrollToActive(index) {
    const option = this.dom.children[index]
    const {scrollTop, clientHeight} = this.dom

    if (option.offsetTop < scrollTop) this.dom.scrollTop = option.offsetTop
    else if (option.offsetTop + option.offsetHeight > scrollTop + clientHeight) {
      this.dom.scrollTop = option.offsetTop + option.offsetHeight - clientHeight
    }
  }

  onClick(event) {
    const menu = slashMenuKey.getState(this.view.state)
    const name = event.target.closest("[data-name]")?.dataset.name
    const item = menu?.items.find((candidate) => candidate.name === name)
    if (item) chooseItem(this.view, item)
  }

  onHover(event) {
    const menu = slashMenuKey.getState(this.view.state)
    const name = event.target.closest("[data-name]")?.dataset.name
    const index = menu ? menu.items.findIndex((item) => item.name === name) : -1
    if (index >= 0 && index !== menu.index) {
      this.view.dispatch(this.view.state.tr.setMeta(slashMenuKey, {index}))
    }
  }

  destroy() {
    window.removeEventListener("scroll", this.reposition, true)
    window.visualViewport?.removeEventListener("resize", this.reposition)
    window.visualViewport?.removeEventListener("scroll", this.reposition)
    this.dom.remove()
  }
}

const optionId = (menuId, item) => `${menuId}-${item.name}`

export function slashMenu() {
  const id = `slash-menu-${generateId()}`

  return new Plugin({
    key: slashMenuKey,
    state: {init: () => null, apply: applyMenu},
    view: (view) => new MenuView(view, id),
    props: {
      handleTextInput: openOnSlash,
      handleKeyDown,
      handleDOMEvents: {
        blur: (view) => {
          if (slashMenuKey.getState(view.state)) closeMenu(view)
          return false
        }
      },
      attributes: (state) => {
        const menu = slashMenuKey.getState(state)
        if (!menu) return {}
        return {"aria-controls": id, "aria-activedescendant": optionId(id, menu.items[menu.index])}
      }
    }
  })
}
