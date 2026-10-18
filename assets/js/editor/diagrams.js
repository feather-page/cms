import {Plugin, TextSelection} from "prosemirror-state"
import {Decoration, DecorationSet} from "prosemirror-view"
import {schema} from "./schema"
import {element, ignoreMutation} from "./dom"
import {registerSlashItem} from "./slash_items"
import {arrowIntoHiddenSource} from "./hidden_source"

const DEBOUNCE_MS = 500
const CACHE_SIZE = 50
const NETWORK_ERROR = "The diagram could not be rendered. Check the connection and try again."

registerSlashItem({
  name: "diagram",
  label: "Diagram",
  icon: "◇",
  keywords: ["d2", "flowchart", "graph", "```d2"],
  create: () => schema.nodes.diagram.createAndFill()
})

export class DiagramPreviews {
  constructor({previewUrl, csrfToken, fetch: fetchFn} = {}) {
    this.previewUrl = previewUrl
    this.csrfToken = csrfToken
    this.fetch = fetchFn || ((...args) => window.fetch(...args))
    this.results = new Map()
  }

  cached(code) {
    return this.results.get(code)
  }

  async render(code) {
    const cached = this.cached(code)
    if (cached) return cached
    if (!this.previewUrl) throw new Error("no diagram preview")

    const response = await this.fetch(this.previewUrl, {
      method: "POST",
      body: JSON.stringify({code}),
      credentials: "same-origin",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
        "x-csrf-token": this.csrfToken || ""
      }
    })
    const data = await response.json().catch(() => ({}))

    if (response.ok && typeof data.svg === "string") return this.remember(code, {svg: data.svg})
    if (response.status === 422 && typeof data.error === "string") return {error: data.error}
    throw new Error(`diagram preview failed: ${response.status}`)
  }

  remember(code, result) {
    this.results.delete(code)
    this.results.set(code, result)
    if (this.results.size > CACHE_SIZE) this.results.delete(this.results.keys().next().value)
    return result
  }
}

// An <img> keeps the SVG from running scripts in the admin's origin.
const svgSource = (svg) => `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`

export class DiagramCodeView {
  constructor(node, view, getPos, previews) {
    this.node = node
    this.view = view
    this.getPos = getPos
    this.previews = previews
    this.requests = 0

    const sourceAttrs = {"data-language": "d2", "data-placeholder": "D2 source, e.g. a -> b"}
    this.contentDOM = element("pre", "pm-diagram__code", sourceAttrs)

    this.img = element("img", "pm-diagram__img", {alt: "Diagram"})
    this.message = element("p", "pm-diagram__message", {role: "status"})
    this.preview = element("div", "pm-diagram__preview", {contenteditable: "false"}, [this.img, this.message])
    this.preview.addEventListener("mousedown", (event) => {
      event.preventDefault()
      this.editSource()
    })

    this.dom = element("div", "pm-diagram__body", {}, [this.contentDOM, this.preview])

    this.contentDOM.classList.toggle("is-empty", node.content.size === 0)
    this.renderNow()
  }

  editSource() {
    const pos = this.getPos()
    if (pos === undefined) return
    const end = pos + this.node.nodeSize - 1
    this.view.dispatch(this.view.state.tr.setSelection(TextSelection.create(this.view.state.doc, end)))
    this.view.focus()
  }

  renderSoon() {
    clearTimeout(this.timer)
    const code = this.node.textContent
    if (!code.trim() || this.previews.cached(code)) return this.renderNow()

    this.dom.classList.add("is-rendering")
    this.timer = setTimeout(() => this.renderNow(), DEBOUNCE_MS)
  }

  async renderNow() {
    clearTimeout(this.timer)
    const code = this.node.textContent
    const request = ++this.requests
    if (!code.trim()) return this.show({message: "Empty diagram"})

    if (!this.previews.cached(code)) {
      this.dom.classList.add("is-rendering")
      if (this.img.hidden || !this.img.getAttribute("src")) this.show({message: "Rendering…", rendering: true})
    }

    let result
    try {
      result = await this.previews.render(code)
    } catch (_error) {
      result = {error: NETWORK_ERROR}
    }
    if (request === this.requests && !this.destroyed) this.show(result)
  }

  show({svg, error, message, rendering = false}) {
    this.dom.classList.toggle("is-rendering", rendering)
    this.img.hidden = !svg
    if (svg) this.img.src = svgSource(svg)
    else this.img.removeAttribute("src")

    const text = error || message || ""
    this.message.textContent = text
    this.message.hidden = !text
    this.message.classList.toggle("is-error", Boolean(error))
  }

  update(node) {
    if (node.type !== this.node.type) return false
    const changed = node.textContent !== this.node.textContent
    this.node = node
    this.contentDOM.classList.toggle("is-empty", node.content.size === 0)
    if (changed) this.renderSoon()
    return true
  }

  stopEvent(event) {
    return this.preview.contains(event.target)
  }

  ignoreMutation(mutation) {
    return ignoreMutation(mutation, this.preview)
  }

  destroy() {
    this.destroyed = true
    clearTimeout(this.timer)
  }
}

export const diagramCodeView = (previews) => (node, view, getPos) => new DiagramCodeView(node, view, getPos, previews)

export function editedDiagram({$from, $to}) {
  if ($from.depth < 2 || $to.depth < 2 || $from.before(1) !== $to.before(1)) return null
  const node = $from.node(1)
  return node.type === schema.nodes.diagram ? {pos: $from.before(1), node} : null
}

// The diagram holding the cursor shows its source (see .is-editing in app.css).
export const diagramEditing = () =>
  new Plugin({
    props: {
      decorations(state) {
        const edited = editedDiagram(state.selection)
        if (!edited) return null
        const {pos, node} = edited
        return DecorationSet.create(state.doc, [Decoration.node(pos, pos + node.nodeSize, {class: "is-editing"})])
      },
      handleKeyDown: arrowIntoHiddenSource("diagram_code")
    }
  })
