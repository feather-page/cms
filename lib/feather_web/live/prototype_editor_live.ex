defmodule FeatherWeb.PrototypeEditorLive do
  @moduledoc """
  PROTOTYPE, throwaway: a Notion-like block editor on LiveView. Not for
  `main`; dev only at `/dev/editor-prototype`, in memory, without tests.

  It answers one question: do Enter, Backspace, focus and type changes feel
  instant when the server is far away?

  The `.BlockEditor` hook applies every edit to the DOM at once and only then
  pushes it. New blocks get their id on the client, so the server never
  echoes a client edit back: it applies the edit to `@blocks` and re-renders
  nothing but the state panel. The block list is rendered once and then
  belongs to the client (`phx-update="ignore"`), also across reconnects. The
  one change the server makes (an image URL becoming an image) comes back as
  the block's HTML in the reply to the event.
  """
  use FeatherWeb, :live_view

  alias Feather.Content.Blocks
  alias Feather.Content.HTML

  @types ~w(paragraph h2 h3 quote bulleted numbered code image)

  @menu [
    {"paragraph", "Text", "Aa"},
    {"h2", "Heading 2", "H2"},
    {"h3", "Heading 3", "H3"},
    {"bulleted", "Bulleted list", "•"},
    {"numbered", "Numbered list", "1."},
    {"quote", "Quote", "❝"},
    {"code", "Code", "</>"},
    {"image", "Image", "▣"}
  ]

  @impl true
  def mount(params, _session, socket) do
    # Stands in for the database, so a reconnect finds what the server had.
    reset? = params["reset"] && get_connect_params(socket)["_mounts"] in [nil, 0]
    blocks = (!reset? && :persistent_term.get(__MODULE__, nil)) || sample_blocks()

    {:ok,
     socket
     |> assign(page_title: "Editor prototype", menu: @menu, events: 0, show_state: false)
     |> assign(initial: blocks)
     |> assign_blocks(blocks), temporary_assigns: [initial: []]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="pe-editor" class="pe" phx-hook=".BlockEditor">
        <div class="pe-main">
          <div id="pe-head" phx-update="ignore">
            <p class="pe-badge">Prototype · in memory, nothing is saved</p>
            <input
              id="pe-title"
              class="pe-title"
              placeholder="Untitled"
              value="Writing in feather"
              autocomplete="off"
            />
          </div>
          <div id="pe-blocks" class="pe-blocks" phx-update="ignore" phx-hook=".BlockSync">
            <.block :for={block <- @initial} id={"pe-#{block.id}"} block={block} />
          </div>
          <button type="button" id="pe-append" class="pe-append" data-action="append">
            Click to add a block
          </button>
        </div>

        <aside class="pe-side">
          <section class="card pe-panel">
            <div class="card-body">
              <h2 class="pe-panel__title">Simulated latency</h2>
              <div
                id="pe-latency"
                class="d-flex flex-wrap gap-1"
                phx-update="ignore"
                phx-hook=".Latency"
              >
                <button
                  :for={ms <- [0, 150, 500, 1000]}
                  type="button"
                  class="btn btn-sm btn-outline-secondary"
                  data-latency={ms}
                >
                  {ms} ms
                </button>
              </div>
              <p id="pe-status" class="pe-status" phx-update="ignore">Server in sync</p>
            </div>
          </section>
          <section class="card pe-panel">
            <div class="card-body">
              <h2 class="pe-panel__title d-flex align-items-center gap-2">
                Server state
                <span class="pe-muted">· {@events} events · {length(@blocks)} blocks</span>
                <button
                  type="button"
                  id="pe-state-toggle"
                  class="btn btn-sm btn-link ms-auto p-0"
                  phx-click="toggle_state"
                >
                  {if @show_state, do: "Hide JSON", else: "Show JSON"}
                </button>
              </h2>
              <pre :if={@show_state} id="pe-state" class="pe-state">{@state}</pre>
            </div>
          </section>
        </aside>

        <div id="pe-chrome" phx-update="ignore">
          <div id="pe-menu" class="pe-menu" hidden>
            <p class="pe-menu__title">Blocks</p>
            <button
              :for={{type, label, glyph} <- @menu}
              type="button"
              class="pe-menu__item"
              data-type={type}
              data-label={label}
            >
              <span class="pe-menu__glyph">{glyph}</span> {label}
            </button>
          </div>
          <div id="pe-toolbar" class="pe-toolbar" phx-hook=".Toolbar" hidden>
            <button type="button" data-cmd="bold" title="Bold"><b>B</b></button>
            <button type="button" data-cmd="italic" title="Italic"><i>i</i></button>
            <button type="button" data-cmd="underline" title="Underline"><u>U</u></button>
            <button type="button" data-cmd="code" title="Inline code"><code>&lt;/&gt;</code></button>
            <button type="button" data-cmd="link" title="Link">Link</button>
          </div>
        </div>

        <template id="pe-template-text">
          <.block id="pe-__ID__" block={new_block("__ID__", "paragraph", "")} />
        </template>
        <template id="pe-template-image">
          <.block id="pe-__ID__" block={new_block("__ID__", "image", "")} />
        </template>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".BlockEditor">
        // PROTOTYPE. Editing only changes the DOM; .BlockSync pushes it afterwards
        // and the server never sends a client edit back.
        const SHORTCUTS = {"#": "h2", "##": "h2", "###": "h3", "-": "bulleted", "*": "bulleted",
          "1.": "numbered", ">": "quote", "```": "code"}
        const LIST_TYPES = ["bulleted", "numbered"]

        // Ids like Feather.Content.Blocks generates them: 10 characters of [0-9a-zA-Z].
        const ID_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        const newId = () => Array.from(crypto.getRandomValues(new Uint8Array(10)), (b) => ID_CHARS[b % 62]).join("")
        const elOf = (node) => (node && node.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement)
        const blockOf = (node) => elOf(node)?.closest(".pe-block")
        const editableOf = (block) => block?.querySelector(":scope > [data-editable]")
        const isText = (block) => block && block.dataset.type !== "image"
        const escapeHtml = (text) => text.replace(/[&<>"]/g, (c) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]))
        const tidy = (node) => { if (node.textContent === "" && !node.querySelector("img")) node.innerHTML = "" }

        const pointAt = (ed, offset) => {
          const walker = document.createTreeWalker(ed, NodeFilter.SHOW_TEXT)
          let node, rest = offset
          while ((node = walker.nextNode())) {
            if (rest <= node.length) return [node, rest]
            rest -= node.length
          }
          return [ed, ed.childNodes.length]
        }
        const rangeAt = (ed, from, to) => {
          const range = document.createRange()
          range.setStart(...pointAt(ed, from))
          range.setEnd(...pointAt(ed, to))
          return range
        }
        const caretOffset = (ed) => {
          const sel = getSelection()
          if (!sel.rangeCount) return 0
          const range = sel.getRangeAt(0)
          const before = document.createRange()
          before.selectNodeContents(ed)
          before.setEnd(range.startContainer, range.startOffset)
          return before.toString().length
        }
        const setCaret = (ed, offset) => {
          ed.focus()
          const range = rangeAt(ed, offset, offset)
          const sel = getSelection()
          sel.removeAllRanges()
          sel.addRange(range)
        }
        const caretRect = () => {
          const sel = getSelection()
          if (!sel.rangeCount) return null
          const range = sel.getRangeAt(0).cloneRange()
          range.collapse(true)
          const rect = range.getClientRects()[0]
          return rect && rect.height ? rect : null
        }
        const onEdgeLine = (ed, edge) => {
          const rect = caretRect()
          if (!rect) return true
          const box = ed.getBoundingClientRect()
          const line = parseFloat(getComputedStyle(ed).lineHeight) || 24
          return edge === "top" ? rect.top - box.top < line * 0.8 : box.bottom - rect.bottom < line * 0.8
        }
        const textSibling = (block, dir) => {
          let el = block[dir]
          while (el && !isText(el)) el = el[dir]
          return el
        }
        // Puts the caret on the first or last line of `ed`, as close to `x` as
        // possible, the way ArrowUp/Down move within one block.
        const caretAtX = (ed, x, line) => {
          ed.scrollIntoView({block: "nearest"})
          const all = document.createRange()
          all.selectNodeContents(ed)
          const rects = [...all.getClientRects()].filter((r) => r.height)
          if (!rects.length) return setCaret(ed, 0)
          const rect = line === "first" ? rects[0] : rects.at(-1)
          const box = ed.getBoundingClientRect()
          const px = Math.min(Math.max(x, box.left + 1), box.right - 1)
          const py = rect.top + rect.height / 2
          const pos = document.caretPositionFromPoint?.(px, py)
          const range = pos ? document.createRange() : document.caretRangeFromPoint?.(px, py)
          if (pos) range.setStart(pos.offsetNode, pos.offset)
          if (!range || !ed.contains(range.startContainer)) return setCaret(ed, line === "first" ? 0 : ed.textContent.length)
          ed.focus({preventScroll: true})
          range.collapse(true)
          getSelection().removeAllRanges()
          getSelection().addRange(range)
        }
        const setType = (block, type) => {
          ;[...block.classList].filter((c) => c.startsWith("pe-block--")).forEach((c) => block.classList.remove(c))
          block.classList.add(`pe-block--${type}`)
          block.dataset.type = type
          // Code is plain text: Enter, Tab and paste insert characters, not markup.
          const ed = editableOf(block)
          if (!ed) return
          if (type === "code" && ed.querySelector("*")) {
            const caret = document.activeElement === ed ? caretOffset(ed) : null
            ed.textContent = ed.textContent
            if (caret !== null) setCaret(ed, caret)
          }
          ed.contentEditable = type === "code" ? "plaintext-only" : "true"
        }

        export default {
          mounted() {
            this.list = this.el.querySelector("#pe-blocks")
            this.menu = this.el.querySelector("#pe-menu")
            this.slash = null
            this.dragged = null

            this.el.addEventListener("keydown", (e) => this.onKeydown(e))
            this.el.addEventListener("beforeinput", (e) => this.onBeforeinput(e))
            this.el.addEventListener("input", (e) => this.onInput(e))
            this.el.addEventListener("paste", (e) => this.onPaste(e))
            this.el.addEventListener("click", (e) => this.onClick(e))
            this.el.addEventListener("mousedown", (e) => this.onMousedown(e))
            this.el.addEventListener("focusout", () => this.closeMenu())
            this.list.addEventListener("dragstart", (e) => this.onDragstart(e))
            this.list.addEventListener("dragover", (e) => this.onDragover(e))
            this.list.addEventListener("drop", (e) => this.onDrop(e))
            this.list.addEventListener("dragend", () => this.endDrag())
          },

          // ---- block operations (they only change the DOM) -----------------

          fromTemplate(type, id) {
            const kind = type === "image" ? "image" : "text"
            const html = this.el.querySelector(`#pe-template-${kind}`).innerHTML.replaceAll("__ID__", id)
            const block = document.createRange().createContextualFragment(html).firstElementChild
            setType(block, type)
            return block
          },

          createBlock(type, html, ref, where = "after") {
            const block = this.fromTemplate(type, newId())
            if (isText(block)) editableOf(block).innerHTML = html
            ref[where](block)
            return block
          },

          split(block) {
            const ed = editableOf(block)
            const range = getSelection().getRangeAt(0)
            if (!range.collapsed) range.deleteContents()
            const type = LIST_TYPES.includes(block.dataset.type) ? block.dataset.type : "paragraph"

            if (caretOffset(ed) === 0 && ed.textContent !== "") {
              this.createBlock(type, "", block, "before")
              return
            }
            const tail = document.createRange()
            tail.selectNodeContents(ed)
            tail.setStart(range.startContainer, range.startOffset)
            const holder = document.createElement("div")
            holder.appendChild(tail.extractContents())
            tidy(ed)
            tidy(holder)
            const next = this.createBlock(type, holder.innerHTML, block)
            setCaret(editableOf(next), 0)
          },

          merge(block, prev) {
            const ed = editableOf(block)
            const ped = editableOf(prev)
            const offset = ped.textContent.length
            if (prev.dataset.type === "code") ped.append(document.createTextNode(ed.textContent))
            else while (ed.firstChild) ped.appendChild(ed.firstChild)
            block.remove()
            setCaret(ped, offset)
          },

          changeType(block, type) {
            if (type === "image") this.toImage(block)
            else setType(block, type)
          },

          toImage(block) {
            const image = this.fromTemplate("image", block.dataset.id)
            block.replaceWith(image)
            image.querySelector("input[name=url]")?.focus()
          },

          // ---- keyboard ------------------------------------------------------

          // Enter, Backspace and Delete are handled as beforeinput: Android
          // keyboards send keydown 229 ("Unidentified") for them, and Safari
          // sends a keydown Enter without isComposing when an IME commits.
          onKeydown(e) {
            if (e.isComposing || e.keyCode === 229) return
            if (this.slash && this.menuKey(e)) return
            if (e.target.id === "pe-title" && (e.key === "Enter" || e.key === "ArrowDown")) {
              e.preventDefault()
              const first = [...this.list.children].find(isText)
              if (first) setCaret(editableOf(first), 0)
              return
            }
            const ed = e.target.closest?.("[data-editable]")
            if (!ed) return
            const block = blockOf(ed)

            if (e.key === "Enter" && (e.metaKey || e.ctrlKey) && block.dataset.type === "code") {
              e.preventDefault()
              return this.split(block)
            }
            if (e.key === "Tab") {
              e.preventDefault()
              if (block.dataset.type === "code" && !e.shiftKey) document.execCommand("insertText", false, "  ")
              return
            }

            const vertical = (e.key === "ArrowUp" || e.key === "ArrowDown") && !e.shiftKey
            if (!vertical) this.goalX = null
            if (!e.key.startsWith("Arrow") || e.shiftKey || e.altKey || e.metaKey || e.ctrlKey) return
            const up = e.key === "ArrowUp" || e.key === "ArrowLeft"
            const target = textSibling(block, up ? "previousElementSibling" : "nextElementSibling")
            if (!target) return
            const collapsed = getSelection().isCollapsed

            if (vertical && onEdgeLine(ed, up ? "top" : "bottom")) {
              e.preventDefault()
              this.goalX ??= caretRect()?.left ?? ed.getBoundingClientRect().left
              caretAtX(editableOf(target), this.goalX, up ? "last" : "first")
            } else if (e.key === "ArrowLeft" && collapsed && caretOffset(ed) === 0) {
              e.preventDefault()
              setCaret(editableOf(target), editableOf(target).textContent.length)
            } else if (e.key === "ArrowRight" && collapsed && caretOffset(ed) === ed.textContent.length) {
              e.preventDefault()
              setCaret(editableOf(target), 0)
            }
          },

          onBeforeinput(e) {
            const ed = e.target.closest?.("[data-editable]")
            if (!ed || e.isComposing) return
            const block = blockOf(ed)
            const type = block.dataset.type
            const sel = getSelection()
            const atStart = sel.isCollapsed && caretOffset(ed) === 0
            const atEnd = sel.isCollapsed && caretOffset(ed) === ed.textContent.replace(/\n$/, "").length

            // Stopgap until there is an own undo: the browser's stack does not know
            // the splits and merges done through the DOM and replays old typing
            // into the wrong block.
            if (e.inputType === "historyUndo" || e.inputType === "historyRedo") {
              e.preventDefault()
            } else if (e.inputType === "insertParagraph" && type !== "code") {
              e.preventDefault()
              if (this.slash) this.choose(this.visibleItems()[this.menuIndex].dataset.type)
              else if (ed.textContent === "" && [...LIST_TYPES, "quote"].includes(type)) this.changeType(block, "paragraph")
              else this.split(block)
            } else if (e.inputType === "deleteContentBackward" && atStart) {
              e.preventDefault()
              const prev = block.previousElementSibling
              if (type !== "paragraph") this.changeType(block, "paragraph")
              else if (isText(prev)) this.merge(block, prev)
              else if (prev && ed.textContent === "") block.remove()
            } else if (e.inputType === "deleteContentForward" && atEnd) {
              e.preventDefault()
              const next = block.nextElementSibling
              if (isText(next)) this.merge(next, block)
            }
          },

          onInput(e) {
            const ed = e.target.closest?.("[data-editable]")
            if (!ed) return
            const block = blockOf(ed)
            tidy(ed)
            if (this.slash) this.updateMenu()
            else if (e.inputType === "insertText" && e.data === "/" && block.dataset.type !== "code") this.openMenu(ed)

            if (e.inputType === "insertText" && e.data === " " && block.dataset.type !== "code") {
              const before = rangeAt(ed, 0, caretOffset(ed)).toString()
              const match = before.match(/^(\S+)[\s ]$/)
              const type = match && SHORTCUTS[match[1]]
              if (type) {
                rangeAt(ed, 0, before.length).deleteContents()
                tidy(ed)
                this.changeType(block, type)
              }
            }
          },

          onPaste(e) {
            const ed = e.target.closest?.("[data-editable]")
            if (!ed) return
            e.preventDefault()
            const block = blockOf(ed)
            const text = e.clipboardData.getData("text/plain")
            if (block.dataset.type === "code" || !text.includes("\n")) {
              document.execCommand("insertText", false, text)
              return
            }
            const lines = text.split(/\r?\n/).filter((line) => line.trim() !== "")
            document.execCommand("insertText", false, lines.shift() || "")
            let ref = block
            for (const line of lines) ref = this.createBlock("paragraph", escapeHtml(line), ref)
            setCaret(editableOf(ref), editableOf(ref).textContent.length)
          },

          // ---- slash menu ----------------------------------------------------

          openMenu(ed) {
            this.slash = {ed, start: caretOffset(ed) - 1}
            this.menuIndex = 0
            this.updateMenu()
          },

          closeMenu() {
            this.slash = null
            this.menu.hidden = true
          },

          visibleItems() {
            return [...this.menu.querySelectorAll("[data-type]")].filter((item) => !item.hidden)
          },

          updateMenu() {
            const {ed, start} = this.slash
            const caret = caretOffset(ed)
            if (!ed.isConnected || caret <= start || ed.textContent[start] !== "/") return this.closeMenu()
            const query = ed.textContent.slice(start + 1, caret).toLowerCase()
            for (const item of this.menu.querySelectorAll("[data-type]")) {
              item.hidden = !item.dataset.label.toLowerCase().includes(query) && !item.dataset.type.includes(query)
            }
            const items = this.visibleItems()
            if (!items.length) return this.closeMenu()
            this.menuIndex = Math.min(this.menuIndex, items.length - 1)
            items.forEach((item, i) => item.classList.toggle("is-active", i === this.menuIndex))
            const rect = caretRect() || ed.getBoundingClientRect()
            this.menu.hidden = false
            const below = rect.bottom + 6
            const top = below + this.menu.offsetHeight > innerHeight ? rect.top - this.menu.offsetHeight - 6 : below
            this.menu.style.left = `${Math.max(8, rect.left)}px`
            this.menu.style.top = `${Math.max(8, top)}px`
          },

          menuKey(e) {
            const items = this.visibleItems()
            if (e.key === "ArrowDown" || e.key === "ArrowUp") {
              e.preventDefault()
              const step = e.key === "ArrowDown" ? 1 : -1
              this.menuIndex = (this.menuIndex + step + items.length) % items.length
              this.updateMenu()
              return true
            }
            if (e.key === "Enter" || e.key === "Tab") {
              e.preventDefault()
              this.choose(items[this.menuIndex].dataset.type)
              return true
            }
            if (e.key === "Escape") {
              e.preventDefault()
              this.closeMenu()
              return true
            }
            return false
          },

          choose(type) {
            const {ed, start} = this.slash
            const caret = caretOffset(ed)
            this.closeMenu()
            rangeAt(ed, start, caret).deleteContents()
            tidy(ed)
            const block = blockOf(ed)
            if (ed.textContent === "") {
              this.changeType(block, type)
              if (type !== "image") setCaret(ed, 0)
            } else {
              const next = this.createBlock(type, "", block)
              if (type === "image") next.querySelector("input[name=url]")?.focus()
              else setCaret(editableOf(next), 0)
            }
          },

          // ---- mouse: gutter, menu, drag & drop -----------------------------

          onMousedown(e) {
            this.goalX = null
            if (e.target.closest("#pe-menu")) e.preventDefault()
            const handle = e.target.closest(".pe-handle")
            if (handle) blockOf(handle).draggable = true
          },

          onClick(e) {
            const target = e.target
            const item = target.closest("#pe-menu [data-type]")
            if (item && this.slash) return this.choose(item.dataset.type)

            const add = target.closest("[data-action=add]")
            const append = target.closest("[data-action=append]")
            if (add || append) {
              const last = this.list.lastElementChild
              let block
              if (append && last && isText(last) && editableOf(last).textContent === "") block = last
              else if (append && !last) block = this.createBlock("paragraph", "", this.list, "append")
              else block = this.createBlock("paragraph", "", add ? blockOf(add) : last)
              const ed = editableOf(block)
              setCaret(ed, 0)
              if (add) document.execCommand("insertText", false, "/")
            }
          },

          onDragstart(e) {
            const block = e.target.closest?.(".pe-block")
            if (!block || !block.draggable) return
            this.dragged = block
            e.dataTransfer.effectAllowed = "move"
            e.dataTransfer.setData("text/plain", "")
            block.classList.add("is-dragging")
          },

          onDragover(e) {
            if (!this.dragged) return
            e.preventDefault()
            const target = e.target.closest?.(".pe-block")
            this.clearDrop()
            if (!target || target === this.dragged) return
            const rect = target.getBoundingClientRect()
            const after = e.clientY > rect.top + rect.height / 2
            target.classList.add(after ? "pe-drop-after" : "pe-drop-before")
            this.drop = {target, after}
          },

          onDrop(e) {
            e.preventDefault()
            if (this.dragged && this.drop) {
              const {target, after} = this.drop
              target[after ? "after" : "before"](this.dragged)
            }
            this.endDrag()
          },

          clearDrop() {
            this.list.querySelectorAll(".pe-drop-before, .pe-drop-after")
              .forEach((el) => el.classList.remove("pe-drop-before", "pe-drop-after"))
            this.drop = null
          },

          endDrag() {
            this.clearDrop()
            this.list.querySelectorAll("[draggable=true]").forEach((el) => { el.draggable = false })
            this.dragged?.classList.remove("is-dragging")
            this.dragged = null
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".BlockSync">
        // The block list is the document. Every change to it is pushed as
        // {order?: [[id, type]], texts?: {id: html}}, debounced, with only what
        // differs from the last push; after a failed push or a reconnect it
        // sends everything, which heals any loss.
        const textOf = (block) => {
          const ed = block.querySelector(":scope > [data-editable]")
          if (block.dataset.type === "image") return block.querySelector(".pe-caption")?.value ?? ""
          return block.dataset.type === "code" ? ed.textContent.replace(/\n$/, "") : ed.innerHTML
        }

        export default {
          mounted() {
            this.status = document.getElementById("pe-status")
            this.pending = 0
            this.sent = this.snapshot()
            this.observer = new MutationObserver(() => this.changed())
            this.observer.observe(this.el, {childList: true, subtree: true, characterData: true, attributeFilter: ["data-type"]})
            this.el.addEventListener("input", () => this.changed())
            this.el.addEventListener("focusout", () => this.sync())
            this.el.addEventListener("submit", (e) => this.onSubmit(e))
          },

          destroyed() {
            this.observer.disconnect()
          },

          reconnected() {
            this.sent = null
            this.sync()
          },

          changed() {
            clearTimeout(this.timer)
            this.timer = setTimeout(() => this.sync(), 300)
            this.renderStatus()
          },

          snapshot() {
            const blocks = [...this.el.children]
            return {
              order: JSON.stringify(blocks.map((b) => [b.dataset.id, b.dataset.type])),
              texts: Object.fromEntries(blocks.map((b) => [b.dataset.id, textOf(b)]))
            }
          },

          sync() {
            clearTimeout(this.timer)
            this.timer = null
            const now = this.snapshot(), last = this.sent || {texts: {}}
            const payload = {}
            if (now.order !== last.order) payload.order = JSON.parse(now.order)
            const texts = Object.entries(now.texts).filter(([id, text]) => last.texts[id] !== text)
            if (texts.length) payload.texts = Object.fromEntries(texts)
            if (!payload.order && !payload.texts) return this.renderStatus()
            this.sent = now
            this.push("sync", payload).catch(() => { this.sent = null; this.changed() })
          },

          // The server turns the URL into an image and replies with the block's HTML.
          onSubmit(e) {
            const form = e.target.closest(".pe-image__form")
            if (!form) return
            e.preventDefault()
            const block = form.closest(".pe-block")
            this.sync()
            this.push("image_url", {id: block.dataset.id, url: form.elements.url.value})
              .then(({html}) => { if (html && block.isConnected) block.outerHTML = html })
          },

          push(event, payload) {
            this.pending++
            this.renderStatus()
            const done = () => { this.pending--; this.renderStatus() }
            const promise = this.pushEvent(event, payload)
            promise.then(done, done)
            return promise
          },

          renderStatus() {
            const busy = this.timer || this.pending > 0
            this.status.classList.toggle("is-pending", !!busy)
            this.status.textContent = busy ? "Saving…" : "Server in sync"
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Toolbar">
        // Formats the selection inside a text block. It only changes the DOM;
        // .BlockSync notices.
        export default {
          mounted() {
            this.onSelection = () => this.update()
            document.addEventListener("selectionchange", this.onSelection)
            this.el.addEventListener("mousedown", (e) => e.preventDefault())
            this.el.addEventListener("click", (e) => {
              const button = e.target.closest("[data-cmd]")
              if (button) this.format(button.dataset.cmd)
            })
          },

          destroyed() {
            document.removeEventListener("selectionchange", this.onSelection)
          },

          update() {
            const sel = getSelection()
            const range = sel.rangeCount && sel.getRangeAt(0)
            const node = range && range.commonAncestorContainer
            const ed = !sel.isCollapsed && (node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement).closest("#pe-blocks [data-editable]")
            if (!ed || ed.closest(".pe-block").dataset.type === "code") {
              this.el.hidden = true
              return
            }
            for (const button of this.el.querySelectorAll("[data-cmd]")) {
              const cmd = button.dataset.cmd
              const active = ["bold", "italic", "underline"].includes(cmd) && document.queryCommandState(cmd)
              button.classList.toggle("is-active", !!active)
            }
            const rect = range.getBoundingClientRect()
            this.el.hidden = false
            this.el.style.left = `${Math.max(8, rect.left + rect.width / 2 - this.el.offsetWidth / 2)}px`
            this.el.style.top = `${Math.max(8, rect.top - this.el.offsetHeight - 8)}px`
          },

          format(cmd) {
            const sel = getSelection()
            if (!sel.rangeCount) return
            const range = sel.getRangeAt(0)
            if (cmd === "code") {
              const code = document.createElement("code")
              code.textContent = range.toString()
              range.deleteContents()
              range.insertNode(code)
              sel.selectAllChildren(code)
            } else if (cmd === "link") {
              const url = prompt("Link URL", "https://")
              if (url) document.execCommand("createLink", false, url)
            } else {
              document.execCommand(cmd)
            }
            this.update()
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Latency">
        export default {
          mounted() {
            this.mark(window.liveSocket?.getLatencySim() || 0)
            this.el.addEventListener("click", (e) => {
              const button = e.target.closest("[data-latency]")
              if (!button) return
              const ms = parseInt(button.dataset.latency)
              if (ms) window.liveSocket.enableLatencySim(ms)
              else window.liveSocket.disableLatencySim()
              this.mark(ms)
            })
          },

          mark(ms) {
            for (const button of this.el.querySelectorAll("[data-latency]")) {
              const active = parseInt(button.dataset.latency) === ms
              button.classList.toggle("btn-secondary", active)
              button.classList.toggle("btn-outline-secondary", !active)
            }
          }
        }
      </script>
    </Layouts.app>
    """
  end

  defp render_block(block) do
    %{id: "pe-#{block.id}", block: block}
    |> block()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  attr :id, :string, required: true
  attr :block, :map, required: true

  defp block(assigns) do
    ~H"""
    <div
      id={@id}
      class={["pe-block", "pe-block--#{@block.type}"]}
      data-id={@block.id}
      data-type={@block.type}
    >
      <div class="pe-gutter" contenteditable="false">
        <button type="button" class="pe-gutter__btn" data-action="add" title="Add a block below">
          <.icon name="plus" size={16} />
        </button>
        <span class="pe-gutter__btn pe-handle" title="Drag to move">⋮⋮</span>
      </div>
      <%= if @block.type == "image" do %>
        <div class="pe-image">
          <%= if @block.url do %>
            <img src={@block.url} alt="" />
            <input
              class="pe-caption"
              value={@block.caption}
              placeholder="Write a caption…"
              autocomplete="off"
            />
          <% else %>
            <form id={"#{@id}-url"} class="pe-image__form">
              <input
                type="url"
                name="url"
                class="form-control"
                placeholder="Paste an image URL and press Enter"
                required
              />
            </form>
          <% end %>
        </div>
      <% else %>
        <div
          id={"#{@id}-text"}
          class="pe-text"
          contenteditable={if @block.type == "code", do: "plaintext-only", else: "true"}
          phx-update="ignore"
          data-editable
          phx-no-format
        >{if @block.type == "code", do: @block.text, else: raw(@block.text)}</div>
      <% end %>
    </div>
    """
  end

  # What changed in the document: the block order with types (all of it, or
  # nil when unchanged) and the texts that changed. The client owns order,
  # types, text and captions; the server owns what it made (image URLs).
  # Malformed parts are dropped instead of crashing the process.
  @impl true
  def handle_event("sync", params, socket) do
    order = if is_list(params["order"]), do: params["order"]
    texts = if is_map(params["texts"]), do: params["texts"], else: %{}
    {:noreply, change(socket, &apply_sync(&1, order, texts))}
  end

  # The one change the server makes itself: an http(s) URL becomes an image.
  # The reply carries the block's HTML, the URL form again if it was refused.
  def handle_event("image_url", %{"id" => id, "url" => url}, socket)
      when is_binary(id) and is_binary(url) do
    socket =
      if web_url?(url),
        do: change(socket, &update_block(&1, id, fn b -> %{b | url: url} end)),
        else: socket

    case Enum.find(socket.assigns.blocks, &(&1.id == id)) do
      nil -> {:reply, %{}, socket}
      block -> {:reply, %{html: render_block(block)}, socket}
    end
  end

  def handle_event("toggle_state", _params, socket) do
    socket = update(socket, :show_state, &(!&1))
    {:noreply, assign_blocks(socket, socket.assigns.blocks)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp change(socket, fun) do
    socket
    |> assign_blocks(fun.(socket.assigns.blocks))
    |> update(:events, &(&1 + 1))
  end

  # The JSON goes over the wire whole on every event (tens of KB for a long
  # document), so it is only rendered while it is shown.
  defp assign_blocks(socket, blocks) do
    :persistent_term.put(__MODULE__, blocks)
    state = if socket.assigns.show_state, do: Jason.encode!(export(blocks), pretty: true)
    assign(socket, blocks: blocks, state: state)
  end

  defp apply_sync(blocks, order, texts) do
    known = Map.new(blocks, &{&1.id, &1})

    for [id, type] when is_binary(id) and type in @types <-
          order || Enum.map(blocks, &[&1.id, &1.type]) do
      block = %{(known[id] || new_block(id, type, "")) | type: type}

      case Map.fetch(texts, id) do
        {:ok, caption} when type == "image" and is_binary(caption) -> %{block | caption: caption}
        {:ok, text} when is_binary(text) -> %{block | text: clean(type, text)}
        _ -> block
      end
    end
  end

  defp web_url?(url) do
    %URI{scheme: scheme, host: host} = URI.parse(url)
    scheme in ~w(http https) and host not in [nil, ""]
  end

  defp update_block(blocks, id, fun),
    do: Enum.map(blocks, fn b -> if b.id == id, do: fun.(b), else: b end)

  defp new_block(id, type, text),
    do: %{id: id, type: type, text: text || "", url: nil, caption: ""}

  defp clean("code", text), do: text
  defp clean(_type, text), do: HTML.sanitize(text, :editor)

  @stored %{
    "paragraph" => %{"type" => "paragraph"},
    "h2" => %{"type" => "header", "level" => 2},
    "h3" => %{"type" => "header", "level" => 3},
    "quote" => %{"type" => "quote"},
    "code" => %{"type" => "code"},
    "bulleted" => %{"type" => "list", "style" => "ul"},
    "numbered" => %{"type" => "list", "style" => "ol"}
  }

  # The stored content format (Feather.Content.Blocks): a run of list items
  # becomes one list. Images keep their URL here, the real editor stores an
  # image id (Blocks.normalize/1 drops image blocks without one).
  defp export(blocks) do
    blocks
    |> Enum.chunk_by(&if(&1.type in ~w(bulleted numbered), do: &1.type, else: &1.id))
    |> Enum.flat_map(fn
      [%{type: "image"} = b] ->
        caption = b.caption |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
        [%{"id" => b.id, "type" => "image", "url" => b.url, "caption" => caption}]

      [b | _] = run ->
        fields = %{
          "id" => b.id,
          "text" => b.text,
          "code" => b.text,
          "items" => Enum.map(run, & &1.text)
        }

        Blocks.normalize([Map.merge(@stored[b.type], fields)])
    end)
  end

  defp sample_blocks do
    [
      {"paragraph",
       "This is a <b>prototype</b> of a block editor on LiveView. Every keystroke stays in the browser; the server only hears about it afterwards."},
      {"h2", "Try it"},
      {"bulleted",
       "Press <b>Enter</b> to split a block, <b>Backspace</b> at the start to merge it"},
      {"bulleted",
       "Type <code>/</code> for the block menu, or <code>## </code>, <code>- </code>, <code>1. </code>, <code>&gt; </code>, <code>```</code>"},
      {"bulleted", "Select text for the formatting toolbar; drag blocks by their ⋮⋮ handle"},
      {"bulleted", "Set the latency to 1000 ms on the right and watch the server catch up"},
      {"quote", "Typing never waits for the server."},
      {"code", "def hello, do: :world"},
      {"paragraph", ""}
    ]
    |> Enum.with_index(fn {type, text}, i -> new_block("sample-#{i}", type, text) end)
  end
end
