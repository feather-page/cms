// Editor.js as a LiveView hook.
//
// Markup (see FeatherWeb.ContentFormComponents.editor/1):
//
//   <div id="..." phx-hook="EditorJs" phx-update="ignore"
//        data-image-endpoint="..." data-image-from-url-endpoint="..."
//        data-book-lookup-endpoint="...">
//     <div data-editor-holder></div>
//     <input type="hidden" name="post[content]" value="<editor.js json>" />
//   </div>
//
// The hidden input carries the content: its initial value is the Editor.js
// data, and every change in the editor writes the saved data back and fires
// an "input" event, so the surrounding form's phx-change and phx-submit see
// the current content. The server converts it with
// Feather.Content.Blocks.from_editor_js/1.
import EditorJS from "../../vendor/editorjs/editorjs.js"
import Header from "../../vendor/editorjs/header.js"
import NestedList from "../../vendor/editorjs/nested-list.js"
import Quote from "../../vendor/editorjs/quote.js"
import Underline from "../../vendor/editorjs/underline.js"
import Table from "../../vendor/editorjs/table.js"
import InlineCode from "../../vendor/editorjs/inline-code.js"
import ImageTool from "../../vendor/editorjs/image.js"
import Embed from "../../vendor/editorjs/embed.js"
import CodeTool from "../../vendor/editorjs/code-tool.js"
import BookTool from "../../vendor/editorjs/book-tool.js"

const CODE_LANGUAGES = {
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

const csrfToken = () =>
  document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

const tools = (dataset) => ({
  header: {class: Header, config: {levels: [2, 3, 4], defaultLevel: 2}},
  image: {
    class: ImageTool,
    config: {
      endpoints: {
        byFile: dataset.imageEndpoint,
        byUrl: dataset.imageFromUrlEndpoint
      },
      field: "image",
      additionalRequestHeaders: {"x-csrf-token": csrfToken()}
    }
  },
  quote: {class: Quote, inlineToolbar: true},
  list: {class: NestedList, inlineToolbar: true},
  underline: Underline,
  table: {class: Table, inlineToolbar: true},
  inlineCode: {class: InlineCode},
  code: {class: CodeTool, config: {languages: CODE_LANGUAGES}},
  embed: {class: Embed},
  book: {class: BookTool, config: {lookupEndpoint: dataset.bookLookupEndpoint}}
})

const parse = (json) => {
  if (!json) return {}
  try {
    return JSON.parse(json)
  } catch (_error) {
    return {}
  }
}

export default {
  mounted() {
    this.input = this.el.querySelector("input[type=hidden]")
    this.editor = new EditorJS({
      holder: this.el.querySelector("[data-editor-holder]"),
      data: parse(this.input.value),
      tools: tools(this.el.dataset),
      onChange: () => this.save()
    })
  },

  save() {
    this.editor
      .save()
      .then((data) => {
        this.input.value = JSON.stringify(data)
        this.input.dispatchEvent(new Event("input", {bubbles: true}))
      })
      .catch((error) => console.error("Saving the editor content failed:", error))
  },

  destroyed() {
    if (this.editor && typeof this.editor.destroy === "function") {
      this.editor.destroy()
    }
  }
}
