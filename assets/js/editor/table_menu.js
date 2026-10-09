// The table menu: a row of buttons above the table holding the cursor,
// shown while the editor has the focus. It adds and deletes rows and
// columns, switches the heading row on and off and deletes the table.
// Buttons do not take the focus, so an on-screen keyboard stays open.
import {Plugin} from "prosemirror-state"
import {addColumnAfter, addColumnBefore, addRowAfter, addRowBefore, deleteTable} from "prosemirror-tables"
import {
  deleteColumn,
  deleteRow,
  hasHeadingRow,
  keepingHeadingRow,
  menuCommand,
  selectedTable,
  toggleHeadingRow
} from "./tables"

const ACTIONS = [
  {name: "row-before", text: "+ Row ↑", label: "Add a row above", command: keepingHeadingRow(addRowBefore)},
  {name: "row-after", text: "+ Row ↓", label: "Add a row below", command: keepingHeadingRow(addRowAfter)},
  {name: "column-before", text: "+ Col ←", label: "Add a column to the left", command: keepingHeadingRow(addColumnBefore)},
  {name: "column-after", text: "+ Col →", label: "Add a column to the right", command: keepingHeadingRow(addColumnAfter)},
  {name: "delete-row", text: "− Row", label: "Delete the row", command: keepingHeadingRow(deleteRow)},
  {name: "delete-column", text: "− Col", label: "Delete the column", command: keepingHeadingRow(deleteColumn)},
  {name: "heading", text: "Heading row", label: "Heading row", command: toggleHeadingRow, toggle: true},
  {name: "delete-table", text: "Delete table", label: "Delete the table", command: deleteTable, danger: true}
].map((action) => ({...action, command: menuCommand(action.command)}))

class TableMenuView {
  constructor(view) {
    this.view = view
    this.mount = view.dom.parentNode
    this.focused = view.hasFocus()

    this.dom = document.createElement("div")
    this.dom.className = "table-menu"
    this.dom.setAttribute("role", "toolbar")
    this.dom.setAttribute("aria-label", "Table")
    this.dom.hidden = true
    this.buttons = ACTIONS.map((action) => this.button(action))
    this.dom.append(...this.buttons)

    // Keeps the focus (and an on-screen keyboard) in the editor.
    const keepFocus = (event) => event.preventDefault()
    this.dom.addEventListener("pointerdown", keepFocus)
    this.dom.addEventListener("mousedown", keepFocus)
    this.dom.addEventListener("click", (event) => this.run(event.target.closest("[data-table-action]")))
    this.onResize = () => this.place()
    window.addEventListener("resize", this.onResize)

    this.mount.appendChild(this.dom)
    this.update(view)
  }

  button({name, text, label, toggle, danger}) {
    const button = document.createElement("button")
    button.type = "button"
    button.tabIndex = -1
    button.className = `table-menu__button${danger ? " is-danger" : ""}`
    button.dataset.tableAction = name
    button.title = label
    button.setAttribute("aria-label", label)
    if (toggle) button.setAttribute("aria-pressed", "false")
    button.textContent = text
    return button
  }

  run(button) {
    const action = button && !button.disabled && ACTIONS.find(({name}) => name === button.dataset.tableAction)
    if (!action) return
    action.command(this.view.state, this.view.dispatch)
    this.view.focus()
  }

  setFocused(focused) {
    this.focused = focused
    this.update(this.view)
  }

  update(view) {
    const table = this.focused ? selectedTable(view.state) : null
    this.dom.hidden = !table
    this.table = table
    if (!table) return

    ACTIONS.forEach((action, index) => {
      const button = this.buttons[index]
      button.disabled = !action.command(view.state)
      if (action.toggle) button.setAttribute("aria-pressed", String(hasHeadingRow(table.node)))
    })
    this.place()
  }

  place() {
    if (!this.table) return
    const dom = this.view.nodeDOM(this.table.pos)
    if (!dom) return

    const rect = dom.getBoundingClientRect()
    const mountRect = this.mount.getBoundingClientRect()
    this.dom.style.top = `${rect.top - mountRect.top - this.dom.offsetHeight - 4}px`
    this.dom.style.left = `${rect.left - mountRect.left}px`
  }

  destroy() {
    window.removeEventListener("resize", this.onResize)
    this.dom.remove()
  }
}

export function tableMenu() {
  const menus = new WeakMap()
  const setFocused = (view, focused) => {
    menus.get(view)?.setFocused(focused)
    return false
  }

  return new Plugin({
    view: (view) => {
      const menu = new TableMenuView(view)
      menus.set(view, menu)
      return menu
    },
    props: {
      handleDOMEvents: {
        focus: (view) => setFocused(view, true),
        blur: (view) => setFocused(view, false)
      }
    }
  })
}
