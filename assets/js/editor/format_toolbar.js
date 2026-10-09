// The formatting toolbar: over a selection of text it offers bold, italic,
// underline, inline code and a link, each showing whether the selection
// has it. The link button (or Mod-k) opens a field for the address; an
// empty address removes the link. Not shown for an empty selection, a
// selected block (image, embed, ...) or text in a code block.
//
// On touch screens it is docked at the bottom of the visual viewport, so it
// sits right above the on-screen keyboard and clear of the browser's own
// selection menu.
//
// Pressing a button keeps the focus (and the on-screen keyboard) in the
// editor; only the link field takes it, and gives it back afterwards.
import {toggleMark} from "prosemirror-commands"
import {keydownHandler} from "prosemirror-keymap"
import {AllSelection, Plugin, TextSelection} from "prosemirror-state"
import {generateId} from "./block_ids"
import {safeHref, schema} from "./schema"
import {element} from "./dom"

const {marks} = schema

const MAC = typeof navigator !== "undefined" && /Mac|iP(hone|[oa]d)/.test(navigator.platform)
const shortcut = (key) => (MAC ? `⌘${key}` : `Ctrl+${key}`)

// Lucide icon paths (lucide.dev, ISC licence).
const BUTTONS = [
  {name: "bold", label: "Bold", key: "B", paths: ["M6 12h9a4 4 0 0 1 0 8H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h7a4 4 0 0 1 0 8"]},
  {name: "italic", label: "Italic", key: "I", paths: ["M19 4h-9", "M14 20H5", "M15 4 9 20"]},
  {name: "underline", label: "Underline", key: "U", paths: ["M6 4v6a6 6 0 0 0 12 0V4", "M4 20h16"]},
  {name: "code", label: "Inline code", key: "E", paths: ["m16 18 6-6-6-6", "m8 6-6 6 6 6"]},
  {
    name: "link",
    label: "Link",
    key: "K",
    paths: [
      "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71",
      "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"
    ]
  }
]

// Whether the selection is text the marks apply to.
export function formattable(state) {
  const {selection} = state
  const textual = selection instanceof TextSelection || selection instanceof AllSelection
  return textual && !selection.empty && toggleMark(marks.bold)(state)
}

export const markActive = (state, type) =>
  state.selection.ranges.some(({$from, $to}) => state.doc.rangeHasMark($from.pos, $to.pos, type))

// The first link mark in the selection, or null.
export function selectedLink(state) {
  let link = null
  for (const {$from, $to} of state.selection.ranges) {
    state.doc.nodesBetween($from.pos, $to.pos, (node) => {
      link ||= marks.link.isInSet(node.marks) || null
      return !link
    })
  }
  return link
}

// What was typed into the link field as an href: a bare domain gets
// https://, a bare email address mailto:. Everything else as typed.
export function normalizeHref(text) {
  const href = text.trim()
  if (/^[^\s@/:?#]+@[^\s@/:?#]+\.[^\s@/:?#]+$/.test(href)) return `mailto:${href}`
  if (/^[^\s./:?#@][^\s/:?#@]*\.[a-z]{2,}(?:[/?#:]|$)/i.test(href)) return `https://${href}`
  return href
}

// Links the selection to `href` (keeping target and rel of a link it
// replaces). False for an unsafe href.
export const setLink = (href) => (state, dispatch) => {
  if (!formattable(state) || !safeHref(href)) return false

  if (dispatch) {
    const {from, to} = state.selection
    const link = marks.link.create({...selectedLink(state)?.attrs, href})
    dispatch(state.tr.removeMark(from, to, marks.link).addMark(from, to, link).scrollIntoView())
  }
  return true
}

export const removeLink = (state, dispatch) => {
  if (!formattable(state)) return false

  const {from, to} = state.selection
  dispatch?.(state.tr.removeMark(from, to, marks.link).scrollIntoView())
  return true
}

const svgIcon = (paths) => {
  const ns = "http://www.w3.org/2000/svg"
  const svg = document.createElementNS(ns, "svg")
  for (const [name, value] of Object.entries({
    viewBox: "0 0 24 24",
    width: "18",
    height: "18",
    fill: "none",
    stroke: "currentColor",
    "stroke-width": "2",
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
    "aria-hidden": "true"
  })) {
    svg.setAttribute(name, value)
  }
  for (const d of paths) {
    const path = document.createElementNS(ns, "path")
    path.setAttribute("d", d)
    svg.append(path)
  }
  return svg
}

const docked = () => Boolean(window.matchMedia?.("(pointer: coarse)").matches)

function visibleArea() {
  const viewport = window.visualViewport
  if (!viewport) return {top: 0, left: 0, width: window.innerWidth, height: window.innerHeight}
  return {top: viewport.offsetTop, left: viewport.offsetLeft, width: viewport.width, height: viewport.height}
}

class ToolbarView {
  constructor(view) {
    this.view = view
    this.focused = view.hasFocus()
    this.linkOpen = false
    const id = `format-toolbar-${generateId()}`

    this.buttons = element("div", "format-toolbar__buttons", {}, BUTTONS.map((button) => this.button(button)))
    this.input = element("input", "form-control", {
      id: `${id}-href`,
      type: "url",
      inputmode: "url",
      autocomplete: "off",
      placeholder: "Paste or type a link",
      "aria-label": "Link address"
    })
    this.remove = element("button", "btn btn-sm btn-outline-danger", {type: "button", "data-link-remove": ""}, [
      "Remove"
    ])
    this.error = element("p", "format-toolbar__error", {role: "alert", hidden: ""}, [
      "Use a web address, a path, mailto: or tel:."
    ])
    this.form = element("form", "format-toolbar__link", {novalidate: "", hidden: ""}, [
      this.input,
      element("button", "btn btn-sm btn-primary", {type: "submit"}, ["Apply"]),
      this.remove,
      this.error
    ])
    this.dom = element("div", "format-toolbar", {id, role: "toolbar", "aria-label": "Format", hidden: ""}, [
      this.buttons,
      this.form
    ])

    this.listen()
    view.dom.parentNode.appendChild(this.dom)
    this.update(view)
  }

  button({name, label, key, paths}) {
    return element(
      "button",
      "format-toolbar__button",
      {
        type: "button",
        tabindex: "-1",
        "data-format": name,
        "aria-label": label,
        "aria-pressed": "false",
        title: `${label} (${shortcut(key)})`
      },
      [svgIcon(paths)]
    )
  }

  listen() {
    // Keeps the focus in the editor, except for the link field.
    const keepFocus = (event) => {
      if (event.target !== this.input) event.preventDefault()
    }
    this.dom.addEventListener("pointerdown", keepFocus)
    this.dom.addEventListener("mousedown", keepFocus)
    this.buttons.addEventListener("click", (event) => this.format(event.target.closest("[data-format]")?.dataset.format))
    this.form.addEventListener("submit", (event) => {
      event.preventDefault()
      this.applyLink()
    })
    this.remove.addEventListener("click", () => this.applyLink(""))
    this.input.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") return
      event.preventDefault()
      this.closeLink({refocus: true})
    })
    this.dom.addEventListener("focusout", (event) => {
      if (!this.linkOpen || this.dom.contains(event.relatedTarget)) return
      this.focused = this.view.dom.contains(event.relatedTarget)
      this.closeLink({refocus: false})
    })

    this.reposition = () => this.place()
    window.addEventListener("scroll", this.reposition, true)
    window.addEventListener("resize", this.reposition)
    window.visualViewport?.addEventListener("resize", this.reposition)
    window.visualViewport?.addEventListener("scroll", this.reposition)
  }

  update(view) {
    const {state} = view
    if (this.linkOpen && !formattable(state)) this.closeLink({refocus: false})

    this.dom.hidden = !(formattable(state) && (this.focused || this.linkOpen))
    if (this.dom.hidden) return

    for (const button of this.buttons.children) {
      const active = markActive(state, marks[button.dataset.format])
      button.setAttribute("aria-pressed", String(active))
      button.classList.toggle("is-active", active)
    }
    this.place()
  }

  // Called by the plugin when the editor gains or loses the focus. Moving
  // into the link field does not count as leaving.
  setFocused(focused, next = null) {
    if (!focused && this.dom.contains(next)) return
    this.focused = focused
    this.update(this.view)
  }

  format(name) {
    if (name === "link") return this.openLink()
    if (marks[name]) toggleMark(marks[name])(this.view.state, this.view.dispatch)
  }

  openLink() {
    if (!formattable(this.view.state)) return false

    const link = selectedLink(this.view.state)
    this.linkOpen = true
    this.buttons.hidden = true
    this.form.hidden = false
    this.error.hidden = true
    this.remove.hidden = !link
    this.input.value = link?.attrs.href || ""
    this.input.removeAttribute("aria-invalid")
    this.update(this.view)
    this.input.focus()
    this.input.select()
    return true
  }

  applyLink(text = this.input.value) {
    const href = normalizeHref(text)
    const {state, dispatch} = this.view

    if (href && !setLink(href)(state, dispatch)) {
      this.error.hidden = false
      this.input.setAttribute("aria-invalid", "true")
      this.place()
      return
    }

    if (!href) removeLink(state, dispatch)
    this.closeLink({refocus: true})
  }

  closeLink({refocus}) {
    if (!this.linkOpen) return
    this.linkOpen = false
    this.form.hidden = true
    this.buttons.hidden = false

    // The editor's selection is still in its state; focusing puts it back.
    if (refocus) {
      this.focused = true
      this.view.focus()
    }
    this.update(this.view)
  }

  place() {
    if (this.dom.hidden) return

    const area = visibleArea()
    const isDocked = docked()
    this.dom.classList.toggle("is-docked", isDocked)

    if (isDocked) {
      this.dom.style.left = `${area.left + 8}px`
      this.dom.style.width = `${area.width - 16}px`
      this.dom.style.top = `${area.top + area.height - this.dom.offsetHeight - 8}px`
      return
    }

    this.dom.style.width = ""
    const {from, to} = this.view.state.selection
    const start = this.view.coordsAtPos(from)
    const end = this.view.coordsAtPos(to)
    const {offsetWidth: width, offsetHeight: height} = this.dom
    const center = Math.abs(start.top - end.top) < 4 ? (start.left + end.left) / 2 : start.left + width / 2
    const above = start.top - height - 8
    const top = above < area.top + 8 ? end.bottom + 8 : above
    const left = Math.max(area.left + 8, Math.min(center - width / 2, area.left + area.width - width - 8))

    this.dom.style.top = `${top}px`
    this.dom.style.left = `${left}px`
  }

  destroy() {
    window.removeEventListener("scroll", this.reposition, true)
    window.removeEventListener("resize", this.reposition)
    window.visualViewport?.removeEventListener("resize", this.reposition)
    window.visualViewport?.removeEventListener("scroll", this.reposition)
    this.dom.remove()
  }
}

export function formatToolbar() {
  const toolbars = new WeakMap()
  const openLink = (_state, _dispatch, view) => toolbars.get(view)?.openLink() || false

  return new Plugin({
    view: (view) => {
      const toolbar = new ToolbarView(view)
      toolbars.set(view, toolbar)
      return toolbar
    },
    props: {
      handleKeyDown: keydownHandler({"Mod-k": openLink}),
      handleDOMEvents: {
        focus: (view) => {
          toolbars.get(view)?.setFocused(true)
          return false
        },
        blur: (view, event) => {
          toolbars.get(view)?.setFocused(false, event.relatedTarget)
          return false
        }
      }
    }
  })
}
