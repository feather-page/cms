// The block editor (assets/js/editor) as a LiveView hook, with the autosave
// status of the whole form.
//
// Markup (see FeatherWeb.ContentFormComponents.editor/1):
//
//   <div id="..." phx-hook="ProseMirror" data-label="Content"
//        data-lock-version="3" data-form-status="saved"
//        data-image-upload-url="/sites/…/images"
//        data-image-from-url-url="/sites/…/images/from-url" data-csrf-token="…"
//        data-book-lookup-url="/sites/…/books/lookup">
//     <div id="...-status" phx-update="ignore">
//       <span data-status-text>Saved</span> <button data-reload hidden>Reload</button>
//     </div>
//     <div id="...-document" phx-update="ignore" data-doc="<ProseMirror JSON>">
//       <div data-editor-mount></div>
//     </div>
//   </div>
//
// The editor autosaves by pushing "sync" events (editor/block_sync.js). The
// events go out from the hook's own element: LiveView locks it while a push
// is unanswered and patches a copy meanwhile, so the document and the
// status, which the browser owns, live in ignored children. (LiveView still
// merges data-* attributes into ignored elements, so the status is shown
// with classes.)
//
// The server renders the record's counter (data-lock-version, missing for
// a record that does not exist yet) and the state of the form fields
// (data-form-status: saved, invalid or conflict) on the hook element; the
// status shows the editor and the fields together.
//
// The counter is read once, on mount: later the editor learns newer ones
// from the replies to its syncs and from the "lock_version" events the
// view pushes after a field save. A render after a reconnect shows the
// counter of a new mount, which the editor must not take over: its resend
// names the counter it built on, so the server rejects it if the record
// changed meanwhile.
//
// A "feather:publish" event (sent by the Publish button) sends pending
// edits at once and then pushes "publish" with the editor's status.
import {createEditor} from "../editor"
import {BlockSync} from "../editor/block_sync"

const STATUS_TEXT = {
  saved: "Saved",
  saving: "Saving…",
  unsaved: "Not saved",
  invalid: "Not saved: check the marked fields",
  conflict: "Changed elsewhere"
}

export default {
  mounted() {
    // Publishing waits for the editor's pending edits, if it has loaded.
    this.onPublish = () => {
      const status = this.sync ? this.sync.settled() : Promise.resolve(undefined)
      status.then((editor) => this.pushEvent("publish", {editor}).catch(() => {}))
    }
    window.addEventListener("feather:publish", this.onPublish)

    const documentEl = document.getElementById(`${this.el.id}-document`)
    const mount = documentEl.querySelector("[data-editor-mount]")

    try {
      this.view = createEditor(mount, documentEl.dataset.doc, {
        label: this.el.dataset.label,
        onChange: (doc) => this.sync?.update(doc),
        images: {
          uploadUrl: this.el.dataset.imageUploadUrl,
          fromUrlUrl: this.el.dataset.imageFromUrlUrl,
          csrfToken: this.el.dataset.csrfToken
        },
        books: {lookupUrl: this.el.dataset.bookLookupUrl}
      })
    } catch (error) {
      // Nothing is synced, so the stored content stays as it is.
      console.error("The editor could not load the content:", error)
      mount.textContent = "The content could not be loaded into the editor."
      mount.className = "block-editor__error"
      return
    }

    this.handleEvent("lock_version", ({lock_version}) => this.sync?.adopt(lock_version))
    this.startAutosave()
  },

  startAutosave() {
    this.status = document.getElementById(`${this.el.id}-status`)
    this.status.querySelector("[data-reload]").addEventListener("click", () => window.location.reload())
    this.editorStatus = "saved"

    this.sync = new BlockSync(this.view.state.doc, {
      lockVersion: this.lockVersion(),
      push: (payload) => this.pushEvent("sync", payload),
      onStatus: (status) => {
        this.editorStatus = status
        this.showStatus()
      }
    })

    // The debounce would lose the last edits when the tab goes away or a
    // live navigation replaces the view (its channel is still up when the
    // navigation starts).
    this.onHide = () => document.visibilityState === "hidden" && this.sync.sync()
    this.onNavigate = () => this.sync.sync()
    window.addEventListener("phx:page-loading-start", this.onNavigate)
    this.onUnload = (event) => {
      this.sync.sync()
      if (this.sync.pending()) event.preventDefault()
    }
    document.addEventListener("visibilitychange", this.onHide)
    window.addEventListener("beforeunload", this.onUnload)
    this.showStatus()
  },

  updated() {
    if (!this.sync) return

    if (this.el.dataset.formStatus === "conflict") this.sync.conflict()
    this.showStatus()
  },

  lockVersion() {
    const value = this.el.dataset.lockVersion
    return value ? parseInt(value, 10) : null
  },

  showStatus() {
    const form = this.el.dataset.formStatus
    const editor = this.editorStatus
    let status = editor

    if (editor === "conflict" || form === "conflict") status = "conflict"
    else if (editor !== "unsaved" && form === "invalid") status = "invalid"

    this.status.classList.toggle("is-unsaved", status === "unsaved" || status === "invalid")
    this.status.classList.toggle("is-conflict", status === "conflict")
    this.status.querySelector("[data-status-text]").textContent = STATUS_TEXT[status]
    this.status.querySelector("[data-reload]").hidden = status !== "conflict"
  },

  reconnected() {
    this.sync?.resend()
  },

  destroyed() {
    // Pending edits still go out while the view is connected.
    this.sync?.sync()
    this.sync?.destroy()
    window.removeEventListener("phx:page-loading-start", this.onNavigate)
    document.removeEventListener("visibilitychange", this.onHide)
    window.removeEventListener("beforeunload", this.onUnload)
    window.removeEventListener("feather:publish", this.onPublish)
    this.view?.destroy()
  }
}
