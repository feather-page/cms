import {closeHistory} from "prosemirror-history"
import {Plugin, TextSelection} from "prosemirror-state"
import {Decoration, DecorationSet} from "prosemirror-view"
import {element, ignoreMutation, keepOutOfForm} from "./dom"
import {arrowIntoHiddenSource} from "./hidden_source"

const CACHE_SIZE = 100

// Editor.js's languages; a stored language outside them (an agent, paste, ``` shortcut) is kept.
export const CODE_LANGUAGES = {
  plaintext: "Plain text",
  bash: "Bash",
  csharp: "C#",
  cpp: "C++",
  css: "CSS",
  go: "Go",
  html: "HTML",
  java: "Java",
  javascript: "JavaScript",
  json: "JSON",
  kotlin: "Kotlin",
  php: "PHP",
  python: "Python",
  ruby: "Ruby",
  rust: "Rust",
  sql: "SQL",
  swift: "Swift",
  typescript: "TypeScript",
  xml: "XML",
  yaml: "YAML",
  elixir: "Elixir"
}

export const languageOptions = (current) => {
  const known = Object.entries(CODE_LANGUAGES)
  return current in CODE_LANGUAGES ? known : [[current, current], ...known]
}

export const setLanguage = (pos, language) => (state, dispatch) => {
  const node = state.doc.nodeAt(pos)
  if (node?.type.name !== "code_block") return false
  if (node.attrs.language === language) return true

  if (dispatch) dispatch(closeHistory(state.tr.setNodeAttribute(pos, "language", language)))
  return true
}

const option = ([value, label]) => {
  const el = document.createElement("option")
  el.value = value
  el.textContent = label
  return el
}

// The server highlights every language of the list but plain text (Feather.Highlighting).
const highlighted = (language) => language !== "plaintext" && language in CODE_LANGUAGES

export class CodeHighlights {
  constructor({highlightUrl, csrfToken, fetch: fetchFn} = {}) {
    this.highlightUrl = highlightUrl
    this.csrfToken = csrfToken
    this.fetch = fetchFn || ((...args) => window.fetch(...args))
    this.results = new Map()
  }

  async highlight(code, language) {
    if (!this.highlightUrl || !code.trim() || !highlighted(language)) return null

    const key = JSON.stringify([language, code])
    if (this.results.has(key)) return this.results.get(key)

    const response = await this.fetch(this.highlightUrl, {
      method: "POST",
      body: JSON.stringify({code, language}),
      credentials: "same-origin",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
        "x-csrf-token": this.csrfToken || ""
      }
    })
    if (!response.ok) throw new Error(`code highlight failed: ${response.status}`)

    const {html} = await response.json()
    return this.remember(key, typeof html === "string" ? html : null)
  }

  remember(key, html) {
    this.results.delete(key)
    this.results.set(key, html)
    if (this.results.size > CACHE_SIZE) this.results.delete(this.results.keys().next().value)
    return html
  }
}

// The offset of a click into the highlighted copy, which holds the same text as the source.
const clickOffset = (root, event) => {
  const point = document.caretPositionFromPoint?.(event.clientX, event.clientY)
  const range = point ? null : document.caretRangeFromPoint?.(event.clientX, event.clientY)
  const node = point ? point.offsetNode : range?.startContainer
  if (!node || !root.contains(node)) return null

  const before = document.createRange()
  before.setStart(root, 0)
  before.setEnd(node, point ? point.offset : range.startOffset)
  return before.toString().length
}

export class CodeBlockView {
  constructor(node, view, getPos, highlights) {
    this.node = node
    this.view = view
    this.getPos = getPos
    this.highlights = highlights
    this.requests = 0

    this.select = document.createElement("select")
    this.select.className = "select select-sm pm-code__language"
    this.select.setAttribute("aria-label", "Code language")
    this.select.addEventListener("change", () => this.choose(this.select.value))

    this.header = keepOutOfForm(document.createElement("div"))
    this.header.className = "pm-code__header"
    this.header.setAttribute("contenteditable", "false")
    this.header.append(this.select)

    this.contentDOM = element("pre", "pm-code__source")

    this.code = element("code")
    this.highlight = element("pre", "pm-code__highlight", {contenteditable: "false"}, [this.code])
    this.highlight.addEventListener("mousedown", (event) => {
      event.preventDefault()
      this.editSource(clickOffset(this.code, event))
    })

    this.dom = document.createElement("div")
    this.dom.className = "pm-code"
    this.dom.append(this.header, this.contentDOM, this.highlight)

    this.render()
    this.requestHighlight()
  }

  render() {
    const {language} = this.node.attrs
    this.select.replaceChildren(...languageOptions(language).map(option))
    this.select.value = language
    this.dom.dataset.language = language
  }

  choose(language) {
    const pos = this.getPos()
    if (pos === undefined) return
    setLanguage(pos, language)(this.view.state, this.view.dispatch)
  }

  editSource(offset) {
    const pos = this.getPos()
    if (pos === undefined) return
    const size = this.node.content.size
    const at = pos + 1 + (offset === null ? size : Math.min(offset, size))
    this.view.dispatch(this.view.state.tr.setSelection(TextSelection.create(this.view.state.doc, at)))
    this.view.focus()
  }

  async requestHighlight() {
    this.stale = false
    const request = ++this.requests
    const {textContent: code, attrs: {language}} = this.node

    let html = null
    try {
      html = await this.highlights.highlight(code, language)
    } catch (_error) {
      html = null
    }
    if (request === this.requests && !this.destroyed) this.showHighlight(html)
  }

  // chroma escapes the code, and the admin's Content-Security-Policy keeps scripts from running.
  showHighlight(html) {
    this.code.innerHTML = html || ""
    this.dom.classList.toggle("has-highlight", Boolean(html))
  }

  update(node, decorations) {
    if (node.type !== this.node.type) return false
    const languageChanged = node.attrs.language !== this.node.attrs.language
    const codeChanged = node.textContent !== this.node.textContent
    this.node = node

    if (languageChanged) this.render()
    if (codeChanged) {
      this.requests++
      this.stale = true
      this.showHighlight(null)
    }

    const editing = decorations.some((decoration) => decoration.spec.codeEditing)
    if (languageChanged || (this.stale && !editing)) this.requestHighlight()
    return true
  }

  stopEvent(event) {
    return this.header.contains(event.target) || this.highlight.contains(event.target)
  }

  ignoreMutation(mutation) {
    return ignoreMutation(mutation, this.header) || ignoreMutation(mutation, this.highlight)
  }

  destroy() {
    this.destroyed = true
  }
}

export const codeBlockView = (highlights) => (node, view, getPos) =>
  new CodeBlockView(node, view, getPos, highlights)

function editedCodeBlock({$from, $to}) {
  const node = $from.parent
  if (node.type.name !== "code_block" || !$from.sameParent($to)) return null
  return {pos: $from.before(), node}
}

// The code block holding the cursor shows its source (see .is-editing in app.css).
export const codeEditing = () =>
  new Plugin({
    props: {
      decorations(state) {
        const edited = editedCodeBlock(state.selection)
        if (!edited) return null
        const {pos, node} = edited
        const decoration = Decoration.node(pos, pos + node.nodeSize, {class: "is-editing"}, {codeEditing: true})
        return DecorationSet.create(state.doc, [decoration])
      },
      handleKeyDown: arrowIntoHiddenSource("code_block")
    }
  })
