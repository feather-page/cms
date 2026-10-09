// Image blocks: an empty one offers an upload (file picker, camera on
// phones) and a URL field; once the server has the image, the block shows
// it with an editable caption (the node's content). Image files pasted or
// dropped into the editor become image blocks and upload at once.
//
// Uploads go to the site's image endpoints (FeatherWeb.ImageController),
// which answer {id, url} or {error}. On success the block gets `image_id`
// and `src`; on failure the block stays and shows the error. The state of
// an upload lives in ImageUploads by block id, so it survives the node view
// being recreated (e.g. when the block is moved).
import {Plugin, TextSelection} from "prosemirror-state"
import {closeHistory} from "prosemirror-history"
import {filled, schema} from "./schema"
import {element, keepOutOfForm} from "./dom"
import {generateId} from "./block_ids"
import {blockStart} from "./block_moves"
import {gapAt} from "./block_handle"
import {registerSlashItem} from "./slash_items"

const MAX_BYTES = 25 * 1024 * 1024
const NETWORK_ERROR = "The image could not be uploaded. Check the connection and try again."

registerSlashItem({
  name: "image",
  label: "Image",
  icon: "▣",
  keywords: ["picture", "photo", "upload"],
  create: () => schema.nodes.image.create()
})

export const isImage = (file) => /^image\//.test(file.type)

export class ImageUploads {
  constructor({uploadUrl, fromUrlUrl, csrfToken, fetch: fetchFn} = {}) {
    this.uploadUrl = uploadUrl
    this.fromUrlUrl = fromUrlUrl
    this.csrfToken = csrfToken
    this.fetch = fetchFn || ((...args) => window.fetch(...args))
    this.states = new Map()
    this.listeners = new Map()
  }

  // {status: "uploading" | "error", message} for the block, or undefined.
  state(blockId) {
    return this.states.get(blockId)
  }

  subscribe(blockId, listener) {
    if (!this.listeners.has(blockId)) this.listeners.set(blockId, new Set())
    this.listeners.get(blockId).add(listener)
    return () => this.listeners.get(blockId)?.delete(listener)
  }

  upload(view, blockId, file) {
    if (!isImage(file)) return this.fail(blockId, "Choose an image file.")
    if (file.size > MAX_BYTES) return this.fail(blockId, "The file is too big (at most 25 MB).")

    const body = new FormData()
    body.append("image", file)
    return this.send(view, blockId, this.uploadUrl, body, "Uploading…")
  }

  fromUrl(view, blockId, url) {
    if (!url.trim()) return this.fail(blockId, "Enter the URL of an image.")

    const body = JSON.stringify({url: url.trim()})
    return this.send(view, blockId, this.fromUrlUrl, body, "Fetching the image…", {"content-type": "application/json"})
  }

  fail(blockId, message) {
    this.set(blockId, {status: "error", message})
    return Promise.resolve(false)
  }

  async send(view, blockId, url, body, message, headers = {}) {
    if (this.state(blockId)?.status === "uploading") return false
    if (!url) return this.fail(blockId, "Images cannot be added here.")

    this.set(blockId, {status: "uploading", message})
    let response, data

    try {
      response = await this.fetch(url, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers: {accept: "application/json", "x-csrf-token": this.csrfToken || "", ...headers}
      })
      data = await response.json().catch(() => ({}))
    } catch (_error) {
      return this.fail(blockId, NETWORK_ERROR)
    }

    if (!response.ok || !data.id || !data.url) {
      return this.fail(blockId, data.error || "The image could not be added.")
    }

    this.set(blockId, undefined)
    return placeImage(view, blockId, data)
  }

  set(blockId, state) {
    if (state) this.states.set(blockId, state)
    else this.states.delete(blockId)
    this.listeners.get(blockId)?.forEach((listener) => listener())
  }
}

// Puts the uploaded image into the block, wherever it is by now. A block
// deleted meanwhile (or a closed editor) gets nothing.
function placeImage(view, blockId, {id, url}) {
  if (view.isDestroyed) return false

  let pos = null
  view.state.doc.forEach((node, offset) => {
    if (node.type === schema.nodes.image && node.attrs.id === blockId) pos = offset
  })
  if (pos === null) return false

  const node = view.state.doc.nodeAt(pos)
  view.dispatch(closeHistory(view.state.tr.setNodeMarkup(pos, null, {...node.attrs, image_id: id, src: url})))
  return true
}

export class ImageView {
  constructor(node, view, uploads) {
    this.node = node
    this.view = view
    this.uploads = uploads

    this.img = element("img", "pm-image__img", {alt: ""})
    this.picture = element("div", "pm-image__picture", {contenteditable: "false"}, [this.img])

    this.file = element("input", "pm-image__file", {type: "file", accept: "image/*"})
    this.file.addEventListener("change", () => this.chooseFile())
    this.uploadButton = element("label", "btn btn-sm btn-primary pm-image__upload", {}, ["Upload", this.file])

    this.url = element("input", "form-control form-control-sm pm-image__url", {
      type: "url",
      inputmode: "url",
      placeholder: "Paste an image URL",
      "aria-label": "Image URL"
    })
    this.url.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" || event.isComposing) return
      event.preventDefault()
      this.addUrl()
    })
    this.urlButton = element("button", "btn btn-sm btn-outline-secondary pm-image__add", {type: "button"}, ["From URL"])
    this.urlButton.addEventListener("click", () => this.addUrl())

    this.message = element("p", "pm-image__message", {role: "status"})
    this.picker = keepOutOfForm(
      element("div", "pm-image__picker", {contenteditable: "false"}, [
        element("div", "pm-image__controls", {}, [this.uploadButton, this.url, this.urlButton]),
        this.message
      ])
    )

    this.contentDOM = element("figcaption", "pm-image__caption", {"data-placeholder": "Caption"})
    this.dom = element("figure", "pm-block pm-image", {}, [this.picture, this.picker, this.contentDOM])

    this.listen()
    this.render()
  }

  get blockId() {
    return this.node.attrs.id
  }

  listen() {
    this.unsubscribe?.()
    this.listenedId = this.blockId
    this.unsubscribe = this.uploads.subscribe(this.blockId, () => this.render())
  }

  chooseFile() {
    const [file] = this.file.files
    this.file.value = ""
    if (file) this.uploads.upload(this.view, this.blockId, file)
  }

  addUrl() {
    this.uploads.fromUrl(this.view, this.blockId, this.url.value).then((placed) => {
      if (placed) this.url.value = ""
    })
  }

  render() {
    const {src} = this.node.attrs
    const state = this.uploads.state(this.blockId)
    const uploading = state?.status === "uploading"

    if (src && this.img.getAttribute("src") !== src) this.img.src = src
    this.img.alt = this.node.textContent
    this.picture.hidden = !src
    this.picker.hidden = filled(this.node)
    this.dom.classList.toggle("is-uploading", uploading)
    this.dom.classList.toggle("is-placeholder", !filled(this.node))

    this.message.textContent = state?.message || ""
    this.message.hidden = !state
    this.message.classList.toggle("is-error", state?.status === "error")
    this.file.disabled = this.url.disabled = this.urlButton.disabled = uploading
    this.uploadButton.classList.toggle("disabled", uploading)
    this.contentDOM.classList.toggle("is-empty", this.node.content.size === 0)
  }

  update(node) {
    if (node.type !== this.node.type) return false
    this.node = node
    if (this.listenedId !== this.blockId) this.listen()
    this.render()
    return true
  }

  // The controls handle their own events; ProseMirror must not treat a
  // click or key there as editing.
  stopEvent(event) {
    return this.picker.contains(event.target)
  }

  ignoreMutation(mutation) {
    return mutation.type !== "selection" && !this.contentDOM.contains(mutation.target)
  }

  destroy() {
    this.unsubscribe?.()
  }
}

export const imageView = (uploads) => (node, view) => new ImageView(node, view, uploads)

// The image files of a paste or drop.
export const imageFiles = (data) => Array.from(data?.files || []).filter(isImage)

// New image blocks for `files` at the top-level gap `gap` (replacing the
// block there with `replace`), each uploading its file. The cursor goes to
// the last one's caption.
export function insertImages(view, uploads, files, gap, {replace = false} = {}) {
  const {doc} = view.state
  const nodes = files.map(() => schema.nodes.image.create({id: generateId()}))
  const pos = blockStart(doc, gap)
  const tr = closeHistory(view.state.tr)

  if (replace) tr.replaceWith(pos, pos + doc.child(gap).nodeSize, nodes)
  else tr.insert(pos, nodes)

  const last = pos + nodes.slice(0, -1).reduce((size, node) => size + node.nodeSize, 0)
  view.dispatch(tr.setSelection(TextSelection.create(tr.doc, last + 1)).scrollIntoView())
  nodes.forEach((node, index) => uploads.upload(view, node.attrs.id, files[index]))
}

// Copied rich text (e.g. from Word) may carry a picture of itself as a
// file; its text wins. Copied images come with at most an <img> as HTML.
function pastedText(data) {
  const html = data.getData("text/html")
  if (!html) return false
  return new window.DOMParser().parseFromString(html, "text/html").body.textContent.trim() !== ""
}

const isEmptyParagraph = (node) => node.type === schema.nodes.paragraph && node.content.size === 0

export const imageDrops = (uploads) =>
  new Plugin({
    props: {
      handlePaste(view, event) {
        const files = imageFiles(event.clipboardData)
        if (!files.length || pastedText(event.clipboardData)) return false

        const index = view.state.selection.$from.index(0)
        const replace = isEmptyParagraph(view.state.doc.child(index))
        insertImages(view, uploads, files, replace ? index : index + 1, {replace})
        return true
      },

      handleDrop(view, event, _slice, moved) {
        const files = moved ? [] : imageFiles(event.dataTransfer)
        if (!files.length) return false

        event.preventDefault()
        insertImages(view, uploads, files, gapAt(view, event.clientY))
        return true
      }
    }
  })
