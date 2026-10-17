import {closeHistory} from "prosemirror-history"
import {ignoreMutation, keepOutOfForm} from "./dom"

// Editor.js's languages; a stored language outside them (API, paste, ``` shortcut) is kept.
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
  yaml: "YAML"
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

export class CodeBlockView {
  constructor(node, view, getPos) {
    this.node = node
    this.view = view
    this.getPos = getPos

    this.select = document.createElement("select")
    this.select.className = "select select-sm pm-code__language"
    this.select.setAttribute("aria-label", "Code language")
    this.select.addEventListener("change", () => this.choose(this.select.value))

    this.header = keepOutOfForm(document.createElement("div"))
    this.header.className = "pm-code__header"
    this.header.setAttribute("contenteditable", "false")
    this.header.append(this.select)

    this.contentDOM = document.createElement("pre")

    this.dom = document.createElement("div")
    this.dom.className = "pm-code"
    this.dom.append(this.header, this.contentDOM)

    this.render()
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

  update(node) {
    if (node.type !== this.node.type) return false
    const changed = node.attrs.language !== this.node.attrs.language
    this.node = node
    if (changed) this.render()
    return true
  }

  stopEvent(event) {
    return this.header.contains(event.target)
  }

  ignoreMutation(mutation) {
    return ignoreMutation(mutation, this.header)
  }
}

export const codeBlockView = (node, view, getPos) => new CodeBlockView(node, view, getPos)
