import { Controller } from '@hotwired/stimulus'

import EditorJS from '@editorjs/editorjs'
import NestedList from '@editorjs/nested-list'
import Quote from '@editorjs/quote'
import Underline from '@editorjs/underline'
import Table from '@editorjs/table'
import InlineCode from '@editorjs/inline-code'
import ImageTool from '@editorjs/image'
import Header from '@editorjs/header'
// @ts-ignore
import CodeTool from '@editorjs/code'
// @ts-ignore
import BookTool from '@editorjs/book'

export default class extends Controller {
  static values = {
    editorId: String,
    imageEndpoint: String,
    imageFromUrlEndpoint: String,
    bookLookupEndpoint: String
  }

  static targets = ['jsonOutput']
  static editor = null

  connect () {
    const data = this.loadData()
    this.editor = new EditorJS({
      holder: this.editorIdValue,
      data,
      tools: this.toolsConfig(),
      onChange: (api, _event) => { this.saveData(api) }
    })
    this.dispatch('change', { detail: { data } })
  }

  toolsConfig () {
    return {
      header: { class: Header, config: { levels: [2, 3, 4], defaultLevel: 2 } },
      image: {
        class: ImageTool,
        config: {
          endpoints: {
            byFile: this.imageEndpointValue,
            byUrl: this.imageFromUrlEndpointValue
          }
        }
      },
      quote: { class: Quote, inlineToolbar: true },
      list: { class: NestedList, inlineToolbar: true },
      underline: Underline,
      table: { class: Table, inlineToolbar: true },
      inlineCode: { class: InlineCode },
      code: {
        class: CodeTool,
        config: {
          languages: {
            plaintext: 'Plain text',
            bash: 'Bash',
            csharp: 'C#',
            cpp: 'C++',
            css: 'CSS',
            go: 'Go',
            html: 'HTML',
            java: 'Java',
            javascript: 'JavaScript',
            json: 'JSON',
            kotlin: 'Kotlin',
            php: 'PHP',
            python: 'Python',
            ruby: 'Ruby',
            rust: 'Rust',
            sql: 'SQL',
            swift: 'Swift',
            typescript: 'TypeScript',
            xml: 'XML',
            yaml: 'YAML'
          }
        }
      },
      book: {
        class: BookTool,
        config: {
          lookupEndpoint: this.bookLookupEndpointValue
        }
      }
    }
  }

  loadData () {
    if (this.jsonOutputTarget.value === '') { return {} }

    return JSON.parse(this.jsonOutputTarget.value)
  }

  saveData (api) {
    api.saver.save().then((data) => {
      this.dispatch('change', { detail: { data } })
      this.jsonOutputTarget.value = JSON.stringify(data)
    })
  }
}
