// Embed blocks: an empty one takes the URL of a supported service (see
// embed_services.js), a filled one shows a preview with an editable caption
// (the node's content). A supported URL pasted on its own into an empty
// paragraph turns it into an embed block.
import {Plugin, TextSelection} from "prosemirror-state"
import {closeHistory} from "prosemirror-history"
import {filled, schema} from "./schema"
import {element, keepOutOfForm} from "./dom"
import {previewUrl, recognizeEmbed, serviceNames, EMBED_SERVICES} from "./embed_services"
import {registerSlashItem} from "./slash_items"

registerSlashItem({
  name: "embed",
  label: "Embed",
  icon: "▶",
  keywords: ["video", "youtube", "vimeo", "media", "iframe"],
  create: () => schema.nodes.embed.create()
})

// The embed block at `pos` gets the attrs of `url`, the cursor goes to the
// end of its caption. False (nothing changes) for an unsupported URL.
export function setEmbedUrl(view, pos, url) {
  const attrs = recognizeEmbed(url)
  const node = view.state.doc.nodeAt(pos)
  if (!attrs || node?.type !== schema.nodes.embed) return false

  const tr = closeHistory(view.state.tr.setNodeMarkup(pos, null, {...node.attrs, ...attrs}))
  tr.setSelection(TextSelection.create(tr.doc, pos + node.nodeSize - 1))
  view.dispatch(tr.scrollIntoView())
  view.focus()
  return true
}

export class EmbedView {
  constructor(node, view, getPos) {
    this.node = node
    this.view = view
    this.getPos = getPos

    this.preview = element("div", "pm-embed__preview", {contenteditable: "false"})

    this.url = element("input", "form-control form-control-sm pm-embed__url", {
      type: "url",
      inputmode: "url",
      placeholder: "Paste a link to a video, post or song",
      "aria-label": "Embed URL"
    })
    this.url.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" || event.isComposing) return
      event.preventDefault()
      this.submit()
    })
    this.button = element("button", "btn btn-sm btn-primary pm-embed__add", {type: "button"}, ["Embed"])
    this.button.addEventListener("click", () => this.submit())
    this.message = element("p", "pm-embed__message", {role: "status"})
    this.message.hidden = true
    this.picker = keepOutOfForm(
      element("div", "pm-embed__picker", {contenteditable: "false"}, [
        element("div", "pm-embed__controls", {}, [this.url, this.button]),
        this.message
      ])
    )

    this.contentDOM = element("figcaption", "pm-embed__caption", {"data-placeholder": "Caption"})
    this.dom = element("figure", "pm-block pm-embed", {}, [this.preview, this.picker, this.contentDOM])

    this.render()
    this.focusPickerWhenChosen()
  }

  // Chosen from the slash menu, the cursor lands in the new block: the URL
  // field is what to fill in first.
  focusPickerWhenChosen() {
    if (filled(this.node)) return

    setTimeout(() => {
      const pos = this.getPos()
      const {$from} = this.view.state.selection
      if (this.view.isDestroyed || !this.view.hasFocus() || pos === undefined || $from.before(1) !== pos) return
      this.url.focus()
    })
  }

  submit() {
    const url = this.url.value
    if (!url.trim()) return this.showError(`Paste a link to ${serviceNames}.`)
    if (!setEmbedUrl(this.view, this.getPos(), url)) {
      this.showError(`This link cannot be embedded. Paste a link to ${serviceNames}.`)
    }
  }

  showError(text) {
    this.message.textContent = text
    this.message.hidden = false
    this.message.classList.add("is-error")
    this.url.setAttribute("aria-invalid", "true")
  }

  clearError() {
    this.message.textContent = ""
    this.message.hidden = true
    this.message.classList.remove("is-error")
    this.url.removeAttribute("aria-invalid")
  }

  render() {
    const full = filled(this.node)
    this.dom.classList.toggle("is-placeholder", !full)
    this.picker.hidden = full
    this.preview.hidden = !full
    if (full) this.clearError()
    this.renderPreview()
    this.contentDOM.classList.toggle("is-empty", this.node.content.size === 0)
  }

  // An iframe for the services' own embed hosts, else a card naming the
  // service and the source (no link, so a click never leaves the editor).
  renderPreview() {
    const {service, source, embed, height} = this.node.attrs
    const src = previewUrl(embed)
    const key = JSON.stringify([src, source, service, height])
    if (key === this.previewKey) return
    this.previewKey = key

    if (src) {
      const iframe = element("iframe", "pm-embed__frame", {
        src,
        title: `Embedded ${EMBED_SERVICES[service]?.label || "content"}`,
        height: Number.isFinite(height) && height > 0 ? height : 320,
        loading: "lazy",
        allowfullscreen: "",
        referrerpolicy: "strict-origin-when-cross-origin",
        sandbox: "allow-scripts allow-same-origin allow-popups allow-presentation"
      })
      this.preview.replaceChildren(iframe)
    } else {
      const name = service && (EMBED_SERVICES[service]?.label || service)
      this.preview.replaceChildren(
        element("div", "pm-embed__card", {}, [
          element("div", "pm-block__label", {}, [name ? `Embed: ${name}` : "Embed"]),
          element("div", "pm-embed__source", {}, [source || embed || ""])
        ])
      )
    }
  }

  update(node) {
    if (node.type !== this.node.type) return false
    this.node = node
    this.render()
    return true
  }

  // The URL field handles its own events; ProseMirror must not treat a
  // click or key there as editing.
  stopEvent(event) {
    return this.picker.contains(event.target)
  }

  ignoreMutation(mutation) {
    return mutation.type !== "selection" && !this.contentDOM.contains(mutation.target)
  }
}

export const embedView = (node, view, getPos) => new EmbedView(node, view, getPos)

// Copied rich text whose text is more than the URL is text, not a URL.
function onlyUrl(data, url) {
  const html = data.getData("text/html")
  if (!html) return true
  const text = new window.DOMParser().parseFromString(html, "text/html").body.textContent.trim()
  return text === "" || text === url
}

// A supported URL pasted on its own into an empty top-level paragraph
// replaces the paragraph (keeping its id) with an embed of it.
export const embedPaste = () =>
  new Plugin({
    props: {
      handlePaste(view, event) {
        const {$from, empty} = view.state.selection
        const paragraph = $from.parent
        if (!empty || $from.depth !== 1 || paragraph.type !== schema.nodes.paragraph || paragraph.content.size) {
          return false
        }

        const url = event.clipboardData?.getData("text/plain").trim()
        const attrs = url && onlyUrl(event.clipboardData, url) && recognizeEmbed(url)
        if (!attrs) return false

        const pos = $from.before()
        const node = schema.nodes.embed.create({...attrs, id: paragraph.attrs.id})
        const tr = closeHistory(view.state.tr).replaceWith(pos, pos + paragraph.nodeSize, node)
        view.dispatch(tr.setSelection(TextSelection.create(tr.doc, pos + 1)).scrollIntoView())
        return true
      }
    }
  })
