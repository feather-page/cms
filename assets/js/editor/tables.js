// Table blocks, edited with prosemirror-tables. The block list stores a
// table as rows of cells plus `with_headings`, so the editor keeps every
// table in that shape: no merged cells (colspan/rowspan), no column widths,
// and header cells only as the whole first row, which is the heading row.
// tableFormat() restores that shape after anything that breaks it, e.g.
// pasting a table with merged cells from another app.
import {Plugin, TextSelection} from "prosemirror-state"
import {closeHistory} from "prosemirror-history"
import {
  CellSelection,
  TableMap,
  addRow,
  deleteColumn as deleteTableColumn,
  deleteRow as deleteTableRow,
  goToNextCell,
  isInTable,
  selectedRect
} from "prosemirror-tables"
import {schema} from "./schema"
import {registerSlashItem} from "./slash_items"

const {table: tableType, table_row: rowType, table_cell: cellType, table_header: headerType} = schema.nodes

// A new table of empty cells, without a heading row.
export function createTable(rows = 3, columns = 3) {
  const row = () => rowType.create(null, Array.from({length: columns}, () => cellType.create()))
  return tableType.create(null, Array.from({length: rows}, row))
}

registerSlashItem({
  name: "table",
  label: "Table",
  icon: "▦",
  keywords: ["grid", "rows", "columns"],
  create: () => createTable()
})

const isCell = (node) => node.type === cellType || node.type === headerType

// The top-level table holding the selection, as {node, pos}, or null.
export function selectedTable(state) {
  const {$from} = state.selection instanceof CellSelection ? {$from: state.selection.$anchorCell} : state.selection
  if ($from.depth === 0) return null
  const node = $from.node(1)
  return node.type === tableType ? {node, pos: $from.before(1)} : null
}

// True when the first row is the heading row: all its cells are headers.
export function hasHeadingRow(table) {
  const first = table.firstChild
  return Boolean(first?.childCount) && first.content.content.every((cell) => cell.type === headerType)
}

// Makes the table at `pos` in `tr` fit the block list: merged cells are
// split into single ones, column widths dropped, and the first row is the
// heading row when `heading` is true, else there are no header cells.
function formatTable(tr, pos, heading) {
  const table = tr.doc.nodeAt(pos)
  const map = TableMap.get(table)
  if (map.problems) return
  const tableStart = pos + 1
  // Positions below are in tr.doc as it is now, before these steps.
  const steps = tr.steps.length
  const mapped = (offset) => tr.mapping.slice(steps).map(tableStart + offset, 1)
  const typeIn = (row) => (heading && row === 0 ? headerType : cellType)

  const cells = []
  table.forEach((row, rowOffset) =>
    row.forEach((cell, cellOffset) => cells.push({cell, offset: rowOffset + 1 + cellOffset}))
  )

  // The pieces of merged cells, row by row, like splitCell does.
  for (const {cell, offset} of cells) {
    if (cell.attrs.colspan === 1 && cell.attrs.rowspan === 1) continue
    const rect = map.findCell(offset)
    for (let row = rect.top; row < rect.bottom; row++) {
      let at = map.positionAt(row, rect.left, table)
      if (row === rect.top) at += cell.nodeSize
      for (let col = rect.left; col < rect.right; col++) {
        if (row === rect.top && col === rect.left) continue
        tr.insert(mapped(at), typeIn(row).create())
      }
    }
  }

  for (const {cell, offset} of cells) {
    const type = typeIn(map.findCell(offset).top)
    const {colspan, rowspan, colwidth} = cell.attrs
    if (cell.type === type && colspan === 1 && rowspan === 1 && !colwidth) continue
    tr.setNodeMarkup(mapped(offset), type, {colspan: 1, rowspan: 1, colwidth: null})
  }
}

const fitsBlockList = (table) => {
  let fits = true
  table.forEach((row, _offset, index) =>
    row.forEach((cell) => {
      const {colspan, rowspan, colwidth} = cell.attrs
      if (colspan !== 1 || rowspan !== 1 || colwidth) fits = false
      if (cell.type === headerType && (index > 0 || !hasHeadingRow(table))) fits = false
    })
  )
  return fits
}

// Whether a table that has to be fixed keeps a heading row: its first row
// decides when it is all headers or all cells; when mixed (e.g. cells
// pasted into a part of it), the table's state before the change.
function headingAfterChange(table, oldTables) {
  const first = table.firstChild.content.content
  if (first.every((cell) => cell.type === headerType)) return true
  if (first.every((cell) => cell.type === cellType)) return false
  const old = oldTables.get(table.attrs.id)
  return old ? hasHeadingRow(old) : false
}

// A transaction putting every table of `state` that does not fit the
// block list into shape, or null. With `oldState`, unchanged tables are
// skipped.
export function formatTables(state, oldState) {
  const oldTables = new Map()
  const unchanged = new Set()
  oldState?.doc.forEach((node) => {
    if (node.type !== tableType) return
    unchanged.add(node)
    oldTables.set(node.attrs.id, node)
  })

  let tr = null
  state.doc.forEach((node, pos) => {
    if (node.type !== tableType || unchanged.has(node) || fitsBlockList(node)) return
    tr ||= state.tr
    formatTable(tr, tr.mapping.map(pos), headingAfterChange(node, oldTables))
  })
  return tr?.docChanged ? tr : null
}

export const tableFormat = () =>
  new Plugin({
    appendTransaction: (transactions, oldState, state) =>
      transactions.some((tr) => tr.docChanged) ? formatTables(state, oldState) : null
  })

// Runs `command` and keeps the heading row of the selected table as it
// was: adding a row above the heading row makes the new row the heading
// row, deleting it makes the next row the heading row.
export const keepingHeadingRow = (command) => (state, dispatch) => {
  const table = selectedTable(state)
  if (!table) return false
  if (!dispatch) return command(state)

  const heading = hasHeadingRow(table.node)
  return command(state, (tr) => {
    const pos = tr.mapping.map(table.pos, 1)
    if (tr.doc.nodeAt(pos)?.type === tableType) formatTable(tr, pos, heading)
    dispatch(tr)
  })
}

// prosemirror-tables' deleteRow/deleteColumn only find out on dispatch
// that they cannot delete every row or column.
const leavesSome = (command, side) => (state, dispatch) => {
  if (!isInTable(state)) return false
  const rect = selectedRect(state)
  const all = side === "row" ? rect.top === 0 && rect.bottom === rect.map.height : rect.left === 0 && rect.right === rect.map.width
  return !all && command(state, dispatch)
}

export const deleteRow = leavesSome(deleteTableRow, "row")
export const deleteColumn = leavesSome(deleteTableColumn, "column")

export const toggleHeadingRow = (state, dispatch) => {
  const table = selectedTable(state)
  if (!table) return false
  if (dispatch) {
    const tr = state.tr
    formatTable(tr, table.pos, !hasHeadingRow(table.node))
    dispatch(tr)
  }
  return true
}

// A command from the table menu: its own undo step.
export const menuCommand = (command) => (state, dispatch) =>
  command(state, dispatch && ((tr) => dispatch(closeHistory(tr).scrollIntoView())))

const cellPosAt = (rect, row, col) => rect.tableStart + rect.map.map[row * rect.map.width + col]

// Tab: to the next cell, from the last cell into a new row.
export const nextCell = (state, dispatch) => {
  if (!isInTable(state)) return false
  if (goToNextCell(1)(state, dispatch)) return true

  return keepingHeadingRow((state, dispatch) => {
    const rect = selectedRect(state)
    if (dispatch) {
      const tr = addRow(state.tr, rect, rect.map.height)
      const newRow = tr.mapping.map(rect.tableStart + rect.table.content.size, -1)
      dispatch(tr.setSelection(TextSelection.create(tr.doc, newRow + 2)).scrollIntoView())
    }
    return true
  })(state, dispatch)
}

// Shift-Tab: to the previous cell; nothing happens in the first one.
export const previousCell = (state, dispatch) => {
  if (!isInTable(state)) return false
  goToNextCell(-1)(state, dispatch)
  return true
}

// Enter: to the end of the cell below; in the last row to a new paragraph
// after the table, so a table never traps the cursor. Splitting a cell
// would break the table, so Enter never does that; Shift-Enter starts a
// new line in the cell.
export const enterInCell = (state, dispatch) => {
  if (!isInTable(state)) return false
  // Selected cells: nothing to split or move.
  if (!(state.selection instanceof TextSelection) || !isCell(state.selection.$from.parent)) return true

  if (dispatch) {
    const rect = selectedRect(state)
    if (rect.bottom < rect.map.height) {
      const pos = cellPosAt(rect, rect.bottom, rect.left)
      const end = pos + state.doc.nodeAt(pos).nodeSize - 1
      dispatch(state.tr.setSelection(TextSelection.create(state.doc, end)).scrollIntoView())
    } else {
      const after = rect.tableStart - 1 + rect.table.nodeSize
      const tr = state.tr.insert(after, schema.nodes.paragraph.create())
      dispatch(tr.setSelection(TextSelection.create(tr.doc, after + 1)).scrollIntoView())
    }
  }
  return true
}

// The editable table: a scroll box around the table, so a wide table
// scrolls sideways instead of widening the page.
export class TableView {
  constructor(node) {
    this.node = node
    this.dom = document.createElement("div")
    this.dom.className = "pm-table"
    this.table = this.dom.appendChild(document.createElement("table"))
    this.contentDOM = this.table.appendChild(document.createElement("tbody"))
  }

  update(node) {
    if (node.type !== this.node.type) return false
    this.node = node
    return true
  }

  ignoreMutation(mutation) {
    return mutation.type === "attributes" && (mutation.target === this.dom || mutation.target === this.table)
  }
}

export const tableView = (node) => new TableView(node)
