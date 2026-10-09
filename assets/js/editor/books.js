// Book blocks: an empty one searches the site's bookshelf, a filled one
// shows the book as a card (cover or emoji, title, author). The search goes
// to the book lookup (FeatherWeb.BookLookupController), which answers a
// list of {public_id, title, author, cover_url, emoji}; without a query it
// lists the books read last.
import {NodeSelection} from "prosemirror-state"
import {closeHistory} from "prosemirror-history"
import {filled, schema} from "./schema"
import {element, keepOutOfForm} from "./dom"
import {registerSlashItem} from "./slash_items"

const DEBOUNCE_MS = 250
const NETWORK_ERROR = "The books could not be loaded. Check the connection and try again."

registerSlashItem({
  name: "book",
  label: "Book",
  icon: "📖",
  keywords: ["bookshelf", "reading", "review"],
  create: () => schema.nodes.book.create()
})

// Covers come from the site's own image paths; anything else (e.g. pasted
// HTML) is not loaded.
export const coverSrc = (url) => (typeof url === "string" && /^\/(?![/\\])/.test(url) ? url : null)

export class BookLookup {
  constructor({lookupUrl, fetch: fetchFn} = {}) {
    this.lookupUrl = lookupUrl
    this.fetch = fetchFn || ((...args) => window.fetch(...args))
  }

  // The books matching `query`; rejects when the lookup fails.
  async search(query) {
    if (!this.lookupUrl) throw new Error("no book lookup")

    const url = `${this.lookupUrl}?q=${encodeURIComponent(query.trim())}`
    const response = await this.fetch(url, {credentials: "same-origin", headers: {accept: "application/json"}})
    if (!response.ok) throw new Error(`book lookup failed: ${response.status}`)

    const books = await response.json()
    if (!Array.isArray(books)) throw new Error("book lookup answered no list")
    return books.filter((book) => typeof book?.public_id === "string" && book.public_id)
  }
}

// The book block at `pos` becomes `book` (an answer of the lookup) and stays
// selected. Its own undo step: undo brings back the empty block.
export function setBook(view, pos, book) {
  const node = view.state.doc.nodeAt(pos)
  if (node?.type !== schema.nodes.book) return false

  const attrs = {
    ...node.attrs,
    book_public_id: book.public_id,
    title: book.title ?? null,
    author: book.author ?? null,
    cover_url: book.cover_url ?? null,
    emoji: book.emoji ?? null
  }
  const tr = closeHistory(view.state.tr.setNodeMarkup(pos, null, attrs))
  view.dispatch(tr.setSelection(NodeSelection.create(tr.doc, pos)).scrollIntoView())
  view.focus()
  return true
}

// Cover (or emoji), title and author of a book node or lookup answer.
function bookCard(className, {title, author, cover_url: coverUrl, emoji}) {
  const src = coverSrc(coverUrl)
  const cover = src
    ? element("img", "pm-book__cover", {src, alt: ""})
    : element("div", "pm-book__emoji", {"aria-hidden": "true"}, [emoji || "📖"])

  return element("div", className, {}, [
    cover,
    element("div", "pm-book__text", {}, [
      element("div", "pm-book__title", {}, [title || "Untitled book"]),
      ...(author ? [element("div", "pm-book__author", {}, [author])] : [])
    ])
  ])
}

let listboxCount = 0

export class BookView {
  constructor(node, view, getPos, lookup) {
    this.node = node
    this.view = view
    this.getPos = getPos
    this.lookup = lookup
    this.results = []
    this.active = -1
    this.requests = 0
    this.listboxId = `book-results-${++listboxCount}`

    this.card = element("div", "pm-book__card")

    this.search = element("input", "form-control form-control-sm pm-book__search", {
      type: "search",
      enterkeyhint: "search",
      autocomplete: "off",
      placeholder: "Search the bookshelf by title or author",
      "aria-label": "Search the bookshelf",
      role: "combobox",
      "aria-autocomplete": "list",
      "aria-expanded": "false",
      "aria-controls": this.listboxId
    })
    this.search.addEventListener("input", () => this.searchSoon())
    this.search.addEventListener("focus", () => {
      if (this.searched === undefined) this.runSearch()
    })
    this.search.addEventListener("keydown", (event) => this.keydown(event))

    this.list = element("ul", "pm-book__results", {id: this.listboxId, role: "listbox", "aria-label": "Books"})
    // The search field keeps the focus (and an on-screen keyboard stays).
    this.list.addEventListener("mousedown", (event) => event.preventDefault())
    this.list.addEventListener("click", (event) => {
      const option = event.target.closest("[data-index]")
      if (option) this.choose(Number(option.dataset.index))
    })
    this.message = element("p", "pm-book__message", {role: "status"})
    this.message.hidden = true
    this.picker = keepOutOfForm(element("div", "pm-book__picker", {}, [this.search, this.list, this.message]))

    this.dom = element("div", "pm-block pm-book", {contenteditable: "false"}, [this.card, this.picker])

    this.render()
    this.focusSearchWhenChosen()
  }

  // Chosen from the slash menu, the new block is selected: the search is
  // what to fill in first.
  focusSearchWhenChosen() {
    if (filled(this.node)) return

    setTimeout(() => {
      const {selection} = this.view.state
      if (this.view.isDestroyed || !this.view.hasFocus()) return
      if (!(selection instanceof NodeSelection) || selection.from !== this.getPos()) return
      this.search.focus()
    })
  }

  searchSoon() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.runSearch(), DEBOUNCE_MS)
  }

  async runSearch() {
    clearTimeout(this.timer)
    const query = this.search.value
    const request = ++this.requests
    this.searched = query

    let books
    try {
      books = await this.lookup.search(query)
    } catch (_error) {
      if (request === this.requests && !this.destroyed) this.showResults([], NETWORK_ERROR, true)
      return
    }

    // An answer to an older query, or for a block that is gone.
    if (request !== this.requests || this.destroyed) return
    const empty = query.trim() ? "No book on the bookshelf matches." : "The bookshelf has no books yet."
    this.showResults(books, books.length ? "" : empty)
  }

  showResults(books, message, error = false) {
    this.results = books
    this.active = books.length ? 0 : -1
    this.list.replaceChildren(
      ...books.map((book, index) => {
        const option = bookCard("pm-book__result", book)
        option.id = `${this.listboxId}-${index}`
        option.setAttribute("role", "option")
        option.dataset.index = index
        return option
      })
    )
    this.message.textContent = message
    this.message.hidden = !message
    this.message.classList.toggle("is-error", error)
    this.search.setAttribute("aria-expanded", books.length ? "true" : "false")
    this.markActive()
  }

  markActive() {
    this.list.querySelectorAll("[role=option]").forEach((option, index) => {
      option.classList.toggle("is-active", index === this.active)
      option.setAttribute("aria-selected", index === this.active ? "true" : "false")
    })
    if (this.active >= 0) this.search.setAttribute("aria-activedescendant", `${this.listboxId}-${this.active}`)
    else this.search.removeAttribute("aria-activedescendant")
  }

  keydown(event) {
    if (event.isComposing) return

    const count = this.results.length
    if ((event.key === "ArrowDown" || event.key === "ArrowUp") && count) {
      event.preventDefault()
      this.active = (this.active + (event.key === "ArrowDown" ? 1 : -1) + count) % count
      this.markActive()
    } else if (event.key === "Enter") {
      event.preventDefault()
      // Results of an older query would be the wrong ones: search first.
      const query = this.search.value
      const searched = this.searched === query ? Promise.resolve() : this.runSearch()
      searched.then(() => {
        if (this.searched === query && this.active >= 0 && !this.destroyed) this.choose(this.active)
      })
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.selectBlock()
    }
  }

  choose(index) {
    const book = this.results[index]
    const pos = this.getPos()
    if (book && pos !== undefined) setBook(this.view, pos, book)
  }

  // Back to the editor with this block selected (Backspace deletes it).
  selectBlock() {
    const pos = this.getPos()
    if (pos === undefined) return
    this.view.dispatch(this.view.state.tr.setSelection(NodeSelection.create(this.view.state.doc, pos)))
    this.view.focus()
  }

  render() {
    const full = filled(this.node)
    this.dom.classList.toggle("is-placeholder", !full)
    this.picker.hidden = full
    this.card.hidden = !full

    const key = JSON.stringify(this.node.attrs)
    if (full && key !== this.cardKey) {
      this.cardKey = key
      this.card.replaceWith((this.card = bookCard("pm-book__card", this.node.attrs)))
    }
  }

  update(node) {
    if (node.type !== this.node.type) return false
    this.node = node
    this.render()
    return true
  }

  // The search handles its own events; ProseMirror must not treat a click
  // or key there as editing.
  stopEvent(event) {
    return this.picker.contains(event.target)
  }

  ignoreMutation() {
    return true
  }

  destroy() {
    this.destroyed = true
    clearTimeout(this.timer)
  }
}

export const bookView = (lookup) => (node, view, getPos) => new BookView(node, view, getPos, lookup)
