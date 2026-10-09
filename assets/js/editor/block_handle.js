// The block handle (⋮⋮) in the gutter left of a top-level block, like in
// Notion: shown for the block under the mouse, and for the block with the
// cursor while the editor has the focus (so it is there on touch screens
// too). Dragging the handle moves the block, a line shows where it goes;
// clicking or tapping it selects the block, so Backspace deletes it and
// Mod-c / Mod-x copy or cut it.
//
// Dragging uses pointer events rather than the browser's drag and drop, so
// it works the same with a mouse, a pen and a finger (native drag and drop
// does not start from a tap on iOS and Android); the handle has
// `touch-action: none`, so a finger drags instead of scrolling. A block
// only goes between top-level blocks, never into a list or a quote.
//
// Mod-Shift-ArrowUp / ArrowDown move the blocks of the selection.
import {keydownHandler} from "prosemirror-keymap"
import {Plugin, PluginKey} from "prosemirror-state"
import {Decoration, DecorationSet} from "prosemirror-view"
import {blockStart, moveBlock, moveSelectedBlocks, selectBlock} from "./block_moves"
import {element} from "./dom"

export const blockHandleKey = new PluginKey("blockHandle")

const DRAG_THRESHOLD = 5
const SCROLL_EDGE = 48
const SCROLL_STEP = 12

// Lucide "grip-vertical" (lucide.dev, ISC licence).
const GRIP = [9, 15].flatMap((cx) => [5, 12, 19].map((cy) => `<circle cx="${cx}" cy="${cy}" r="1"/>`)).join("")

// The rectangles of the top-level blocks, in document order.
const blockRects = (view) => {
  const rects = []
  view.state.doc.forEach((_node, offset) => rects.push(view.nodeDOM(offset).getBoundingClientRect()))
  return rects
}

// The index of the top-level block nearest to `y`.
export function blockAt(view, y) {
  let best = 0
  let bestDistance = Infinity
  blockRects(view).forEach((rect, index) => {
    const distance = y < rect.top ? rect.top - y : y > rect.bottom ? y - rect.bottom : 0
    if (distance < bestDistance) [best, bestDistance] = [index, distance]
  })
  return best
}

// The gap between top-level blocks nearest to `y`: 0 before the first
// block, childCount after the last.
export function gapAt(view, y) {
  const rects = blockRects(view)
  const index = rects.findIndex((rect) => y < (rect.top + rect.bottom) / 2)
  return index === -1 ? rects.length : index
}

class HandleView {
  constructor(view) {
    this.view = view
    this.mount = view.dom.parentNode
    this.focused = view.hasFocus()
    this.hover = null

    this.handle = element("button", "block-handle", {
      type: "button",
      tabindex: "-1",
      "aria-label": "Move or select the block",
      title: "Drag to move, click to select"
    })
    this.handle.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${GRIP}</svg>`
    this.handle.hidden = true
    this.line = element("div", "block-handle__drop", {"aria-hidden": "true"})
    this.line.hidden = true
    this.mount.append(this.handle, this.line)
    this.listen()
  }

  listen() {
    // Touch has no hover: there the handle follows the cursor.
    this.onPointerMove = (event) => {
      if (this.drag || event.pointerType !== "mouse") return
      this.hover = blockAt(this.view, event.clientY)
      this.place()
    }
    this.onPointerLeave = () => {
      this.hover = null
      this.place()
    }
    this.mount.addEventListener("pointermove", this.onPointerMove)
    this.mount.addEventListener("pointerleave", this.onPointerLeave)

    // The focus (and an on-screen keyboard) stays in the editor.
    this.handle.addEventListener("mousedown", (event) => event.preventDefault())
    this.handle.addEventListener("pointerdown", (event) => this.pointerDown(event))
    this.handle.addEventListener("pointermove", (event) => this.pointerMove(event))
    this.handle.addEventListener("pointerup", (event) => this.pointerUp(event))
    this.handle.addEventListener("pointercancel", () => this.endDrag())

    this.onResize = () => this.place()
    window.addEventListener("resize", this.onResize)
  }

  // The block the handle belongs to.
  target() {
    if (this.drag) return this.drag.index
    if (this.hover != null) return this.hover
    if (!this.focused) return null
    return this.view.state.selection.$from.index(0)
  }

  update() {
    if (this.hover != null && this.hover >= this.view.state.doc.childCount) this.hover = null
    this.place()
  }

  setFocused(focused) {
    this.focused = focused
    this.place()
  }

  place() {
    const index = this.target()
    this.handle.hidden = index == null
    if (index == null) return

    this.index = index
    const dom = this.view.nodeDOM(blockStart(this.view.state.doc, index))
    const rect = dom.getBoundingClientRect()
    const mountRect = this.mount.getBoundingClientRect()
    const style = getComputedStyle(dom)
    const lineHeight = parseFloat(style.lineHeight) || 24
    const firstLine = rect.top + (parseFloat(style.paddingTop) || 0) + lineHeight / 2

    this.handle.style.top = `${firstLine - mountRect.top - this.handle.offsetHeight / 2}px`
    this.handle.style.left = `${rect.left - mountRect.left - this.handle.offsetWidth - 4}px`
  }

  pointerDown(event) {
    if (event.button !== 0 || this.index == null) return
    event.preventDefault()
    this.handle.setPointerCapture?.(event.pointerId)
    this.press = {index: this.index, x: event.clientX, y: event.clientY}
  }

  pointerMove(event) {
    if (!this.press) return
    this.lastY = event.clientY

    if (!this.drag) {
      const distance = Math.hypot(event.clientX - this.press.x, event.clientY - this.press.y)
      if (distance < DRAG_THRESHOLD) return
      this.startDrag()
    }
    this.showGap()
  }

  pointerUp(event) {
    if (!this.press) return
    event.preventDefault()

    if (this.drag) {
      const {index, gap} = this.drag
      this.endDrag()
      moveBlock(index, gap)(this.view.state, this.view.dispatch)
    } else {
      const {index} = this.press
      this.press = null
      selectBlock(index)(this.view.state, this.view.dispatch)
    }
    this.view.focus()
  }

  startDrag() {
    this.drag = {index: this.press.index, gap: this.press.index}
    this.mount.classList.add("is-dragging-block")
    this.view.dispatch(this.view.state.tr.setMeta(blockHandleKey, {dragging: this.drag.index}))
    this.scrollFrame = requestAnimationFrame(() => this.autoScroll())
  }

  // Scrolls the page while the pointer is near the top or bottom edge.
  autoScroll() {
    if (!this.drag) return
    const height = window.visualViewport?.height ?? window.innerHeight
    const step = this.lastY < SCROLL_EDGE ? -SCROLL_STEP : this.lastY > height - SCROLL_EDGE ? SCROLL_STEP : 0
    if (step) {
      window.scrollBy(0, step)
      this.showGap()
    }
    this.scrollFrame = requestAnimationFrame(() => this.autoScroll())
  }

  showGap() {
    const gap = gapAt(this.view, this.lastY)
    this.drag.gap = gap

    const rects = blockRects(this.view)
    const mountRect = this.mount.getBoundingClientRect()
    const above = rects[gap - 1]
    const below = rects[gap]
    const y = above && below ? (above.bottom + below.top) / 2 : above ? above.bottom + 4 : below.top - 4
    const left = (below || above).left

    this.line.hidden = false
    this.line.style.top = `${y - mountRect.top - 1}px`
    this.line.style.left = `${left - mountRect.left}px`
    this.line.style.width = `${(below || above).width}px`
  }

  endDrag() {
    const dragging = this.drag
    this.press = this.drag = null
    cancelAnimationFrame(this.scrollFrame)
    this.line.hidden = true
    this.mount.classList.remove("is-dragging-block")
    if (dragging) this.view.dispatch(this.view.state.tr.setMeta(blockHandleKey, {dragging: null}))
  }

  destroy() {
    this.endDrag()
    this.mount.removeEventListener("pointermove", this.onPointerMove)
    this.mount.removeEventListener("pointerleave", this.onPointerLeave)
    window.removeEventListener("resize", this.onResize)
    this.handle.remove()
    this.line.remove()
  }
}

export function blockHandle() {
  const handles = new WeakMap()
  const setFocused = (view, focused) => {
    handles.get(view)?.setFocused(focused)
    return false
  }

  return new Plugin({
    key: blockHandleKey,
    state: {
      init: () => null,
      // The index of the block being dragged, or null.
      apply: (tr, dragging) => {
        const meta = tr.getMeta(blockHandleKey)
        return meta ? meta.dragging : dragging
      }
    },
    view: (view) => {
      const handle = new HandleView(view)
      handles.set(view, handle)
      return handle
    },
    props: {
      decorations(state) {
        const index = blockHandleKey.getState(state)
        if (index == null || index >= state.doc.childCount) return null
        const from = blockStart(state.doc, index)
        const to = from + state.doc.child(index).nodeSize
        return DecorationSet.create(state.doc, [Decoration.node(from, to, {class: "is-dragging"})])
      },
      // Handled at the first and last block too, where nothing moves.
      handleKeyDown: keydownHandler({
        "Mod-Shift-ArrowUp": (state, dispatch) => moveSelectedBlocks(-1)(state, dispatch) || true,
        "Mod-Shift-ArrowDown": (state, dispatch) => moveSelectedBlocks(1)(state, dispatch) || true
      }),
      handleDOMEvents: {
        focus: (view) => setFocused(view, true),
        blur: (view) => setFocused(view, false)
      }
    }
  })
}
