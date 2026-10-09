defmodule FeatherWeb.PrototypeEditorLive do
  @moduledoc """
  PROTOTYPE, throwaway: a Notion-like block editor on LiveView. Not for
  `main`; dev only at `/dev/editor-prototype`, in memory, without tests.

  It answers one question: do Enter, Backspace, focus and type changes feel
  instant when the server is far away?

  The `.BlockEditor` hook applies every edit to the DOM at once and only then
  pushes it. New blocks get their id on the client, so the server never
  echoes a client edit back: it applies the edit to `@blocks` and re-renders
  nothing but the state panel. Only changes the server makes (an image URL
  becoming an image) go through the `:blocks` stream. A `phx-update="stream"`
  container keeps the children the hook inserts, and stream inserts of
  existing elements update them in place.
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
  def mount(_params, _session, socket) do
    blocks = sample_blocks()

    {:ok,
     socket
     |> assign(page_title: "Editor prototype", menu: @menu, events: 0)
     |> assign_blocks(blocks)
     |> stream_configure(:blocks, dom_id: &"pe-#{&1.id}")
     |> stream(:blocks, blocks)}
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
          <div id="pe-blocks" class="pe-blocks" phx-update="stream">
            <.block :for={{dom_id, block} <- @streams.blocks} id={dom_id} block={block} />
          </div>
          <button type="button" id="pe-append" class="pe-append" data-action="append">
            Click to add a block
          </button>
        </div>

        <aside class="pe-side">
          <section class="card pe-panel">
            <div class="card-body">
              <h2 class="pe-panel__title">Simulated latency</h2>
              <div id="pe-latency" class="d-flex flex-wrap gap-1" phx-update="ignore">
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
              <h2 class="pe-panel__title">
                Server state <span class="pe-muted">· {@events} events applied</span>
              </h2>
              <pre id="pe-state" class="pe-state">{@state}</pre>
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
          <div id="pe-toolbar" class="pe-toolbar" hidden>
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
        // PROTOTYPE. Every edit lands in the DOM first and is pushed afterwards;
        // the server never sends a client edit back.
        const SHORTCUTS = {"#": "h2", "##": "h2", "###": "h3", "-": "bulleted", "*": "bulleted",
          "1.": "numbered", ">": "quote", "```": "code"}
        const LIST_TYPES = ["bulleted", "numbered"]

        const newId = () => (crypto.randomUUID ? crypto.randomUUID() :
          Math.random().toString(36).slice(2) + Date.now().toString(36))
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
        const setType = (block, type) => {
          ;[...block.classList].filter((c) => c.startsWith("pe-block--")).forEach((c) => block.classList.remove(c))
          block.classList.add(`pe-block--${type}`)
          block.dataset.type = type
        }

        export default {
          mounted() {
            this.list = this.el.querySelector("#pe-blocks")
            this.menu = this.el.querySelector("#pe-menu")
            this.toolbar = this.el.querySelector("#pe-toolbar")
            this.status = this.el.querySelector("#pe-status")
            this.timers = new Map()
            this.pending = 0
            this.slash = null
            this.dragged = null

            this.el.addEventListener("keydown", (e) => this.onKeydown(e))
            this.el.addEventListener("input", (e) => this.onInput(e))
            this.el.addEventListener("paste", (e) => this.onPaste(e))
            this.el.addEventListener("click", (e) => this.onClick(e))
            this.el.addEventListener("mousedown", (e) => this.onMousedown(e))
            this.el.addEventListener("focusout", (e) => {
              const block = blockOf(e.target)
              if (block && e.target.matches("[data-editable]")) this.flush(block)
              this.closeMenu()
            })
            this.list.addEventListener("dragstart", (e) => this.onDragstart(e))
            this.list.addEventListener("dragover", (e) => this.onDragover(e))
            this.list.addEventListener("drop", (e) => this.onDrop(e))
            this.list.addEventListener("dragend", () => this.endDrag())
            this.onSelection = () => this.updateToolbar()
            document.addEventListener("selectionchange", this.onSelection)
            this.markLatency(window.liveSocket?.getLatencySim() || 0)
          },

          destroyed() {
            document.removeEventListener("selectionchange", this.onSelection)
          },

          // ---- talking to the server -------------------------------------

          push(event, payload) {
            this.pending++
            this.renderStatus()
            const done = () => { this.pending--; this.renderStatus() }
            this.pushEvent(event, payload).then(done, done)
          },

          renderStatus() {
            this.status.classList.toggle("is-pending", this.pending > 0)
            this.status.textContent = this.pending > 0
              ? `${this.pending} change${this.pending > 1 ? "s" : ""} on the way to the server…`
              : "Server in sync"
          },

          textOf(block) {
            const ed = editableOf(block)
            return block.dataset.type === "code" ? ed.innerText.replace(/\n$/, "") : ed.innerHTML
          },

          schedule(block) {
            clearTimeout(this.timers.get(block.dataset.id))
            this.timers.set(block.dataset.id, setTimeout(() => this.flush(block), 300))
          },

          flush(block) {
            clearTimeout(this.timers.get(block.dataset.id))
            if (!block.isConnected || !isText(block)) return
            const text = this.textOf(block)
            if (block.peSent === text) return
            block.peSent = text
            this.push("text", {id: block.dataset.id, text})
          },

          // ---- block operations (DOM first, then push) ---------------------

          createBlock(type, html, ref, where = "after") {
            const id = newId()
            const kind = type === "image" ? "image" : "text"
            const holder = document.createElement("div")
            holder.innerHTML = this.el.querySelector(`#pe-template-${kind}`).innerHTML.replaceAll("__ID__", id).trim()
            const block = holder.firstElementChild
            setType(block, type)
            if (kind === "text") editableOf(block).innerHTML = html
            ref[where](block)
            const prev = block.previousElementSibling
            block.peSent = html
            this.push("insert", {id, after: prev ? prev.dataset.id : null, type, text: html})
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
            this.flush(block)
            const next = this.createBlock(type, holder.innerHTML, block)
            setCaret(editableOf(next), 0)
          },

          merge(block, prev) {
            const ed = editableOf(block)
            const ped = editableOf(prev)
            const offset = ped.textContent.length
            if (prev.dataset.type === "code") ped.append(document.createTextNode(ed.innerText))
            else while (ed.firstChild) ped.appendChild(ed.firstChild)
            clearTimeout(this.timers.get(block.dataset.id))
            block.remove()
            setCaret(ped, offset)
            this.flush(prev)
            this.push("delete", {id: block.dataset.id})
          },

          changeType(block, type) {
            if (type === "image") return this.toImage(block)
            setType(block, type)
            clearTimeout(this.timers.get(block.dataset.id))
            const text = this.textOf(block)
            block.peSent = text
            this.push("set_type", {id: block.dataset.id, type, text})
          },

          toImage(block) {
            const holder = document.createElement("div")
            holder.innerHTML = this.el.querySelector("#pe-template-image").innerHTML.replaceAll("__ID__", block.dataset.id).trim()
            const image = holder.firstElementChild
            clearTimeout(this.timers.get(block.dataset.id))
            block.replaceWith(image)
            image.querySelector("input[name=url]")?.focus()
            this.push("set_type", {id: block.dataset.id, type: "image", text: ""})
          },

          // ---- keyboard ------------------------------------------------------

          onKeydown(e) {
            if (this.slash && this.menuKey(e)) return
            if (e.target.id === "pe-title" && (e.key === "Enter" || e.key === "ArrowDown")) {
              e.preventDefault()
              const first = [...this.list.children].find(isText)
              if (first) setCaret(editableOf(first), 0)
              return
            }
            const ed = e.target.closest?.("[data-editable]")
            if (!ed || e.isComposing) return
            const block = blockOf(ed)
            const type = block.dataset.type
            const sel = getSelection()

            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault()
              if (type === "code" && !(e.metaKey || e.ctrlKey)) {
                document.execCommand("insertText", false, "\n")
              } else if (ed.textContent === "" && [...LIST_TYPES, "quote"].includes(type)) {
                this.changeType(block, "paragraph")
              } else {
                this.split(block)
              }
              return
            }

            if (e.key === "Backspace" && sel.isCollapsed && caretOffset(ed) === 0) {
              const prev = block.previousElementSibling
              if (type !== "paragraph") {
                e.preventDefault()
                this.changeType(block, "paragraph")
              } else if (prev && isText(prev)) {
                e.preventDefault()
                this.merge(block, prev)
              } else if (prev && ed.textContent === "") {
                e.preventDefault()
                block.remove()
                this.push("delete", {id: block.dataset.id})
              }
              return
            }

            if (e.key === "ArrowUp" && onEdgeLine(ed, "top")) {
              const prev = block.previousElementSibling
              if (isText(prev)) {
                e.preventDefault()
                setCaret(editableOf(prev), editableOf(prev).textContent.length)
              }
            } else if (e.key === "ArrowDown" && onEdgeLine(ed, "bottom")) {
              const next = block.nextElementSibling
              if (isText(next)) {
                e.preventDefault()
                setCaret(editableOf(next), 0)
              }
            }
          },

          onInput(e) {
            const ed = e.target.closest?.("[data-editable]")
            if (!ed) return
            const block = blockOf(ed)
            tidy(ed)
            if (this.slash) this.updateMenu()
            else if (e.inputType === "insertText" && e.data === "/") this.openMenu(ed)

            if (e.inputType === "insertText" && e.data === " " && block.dataset.type !== "code") {
              const before = rangeAt(ed, 0, caretOffset(ed)).toString()
              const match = before.match(/^(\S+)[\s ]$/)
              const type = match && SHORTCUTS[match[1]]
              if (type) {
                rangeAt(ed, 0, before.length).deleteContents()
                tidy(ed)
                this.changeType(block, type)
                return
              }
            }
            this.schedule(block)
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
            this.flush(block)
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
              this.flush(block)
              const next = this.createBlock(type, "", block)
              if (type === "image") next.querySelector("input[name=url]")?.focus()
              else setCaret(editableOf(next), 0)
            }
          },

          // ---- inline toolbar ------------------------------------------------

          updateToolbar() {
            const sel = getSelection()
            const range = sel.rangeCount && sel.getRangeAt(0)
            const ed = range && !sel.isCollapsed && elOf(range.commonAncestorContainer).closest("[data-editable]")
            if (!ed || !this.el.contains(ed) || blockOf(ed).dataset.type === "code") {
              this.toolbar.hidden = true
              return
            }
            for (const button of this.toolbar.querySelectorAll("[data-cmd]")) {
              const cmd = button.dataset.cmd
              const active = ["bold", "italic", "underline"].includes(cmd) && document.queryCommandState(cmd)
              button.classList.toggle("is-active", !!active)
            }
            const rect = range.getBoundingClientRect()
            this.toolbar.hidden = false
            this.toolbar.style.left = `${Math.max(8, rect.left + rect.width / 2 - this.toolbar.offsetWidth / 2)}px`
            this.toolbar.style.top = `${Math.max(8, rect.top - this.toolbar.offsetHeight - 8)}px`
          },

          format(cmd) {
            const sel = getSelection()
            if (!sel.rangeCount) return
            const range = sel.getRangeAt(0)
            const block = blockOf(range.commonAncestorContainer)
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
            if (block) this.schedule(block)
            this.updateToolbar()
          },

          // ---- mouse: gutter, menu, toolbar, latency, drag & drop ------------

          onMousedown(e) {
            if (e.target.closest("#pe-menu, #pe-toolbar")) e.preventDefault()
            const handle = e.target.closest(".pe-handle")
            if (handle) blockOf(handle).draggable = true
          },

          onClick(e) {
            const target = e.target
            const latency = target.closest("[data-latency]")
            if (latency) return this.setLatency(parseInt(latency.dataset.latency))
            const item = target.closest("#pe-menu [data-type]")
            if (item && this.slash) return this.choose(item.dataset.type)
            const cmd = target.closest("#pe-toolbar [data-cmd]")
            if (cmd) return this.format(cmd.dataset.cmd)

            const add = target.closest("[data-action=add]")
            const append = target.closest("[data-action=append]")
            if (add || append) {
              const last = this.list.lastElementChild
              let block
              if (append && last && isText(last) && editableOf(last).textContent === "") block = last
              else if (append && !last) {
                // Empty document: the stream container has nothing to hang the block on.
                const anchor = document.createElement("div")
                this.list.append(anchor)
                block = this.createBlock("paragraph", "", anchor)
                anchor.remove()
              } else block = this.createBlock("paragraph", "", add ? blockOf(add) : last)
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
              const next = this.dragged.nextElementSibling
              this.push("move", {id: this.dragged.dataset.id, before: next ? next.dataset.id : null})
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
          },

          setLatency(ms) {
            if (ms) window.liveSocket.enableLatencySim(ms)
            else window.liveSocket.disableLatencySim()
            this.markLatency(ms)
          },

          markLatency(ms) {
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
            <form id={"#{@id}-caption"} phx-change="image_caption">
              <input type="hidden" name="block_id" value={@block.id} />
              <input
                name="caption"
                class="pe-caption"
                value={@block.caption}
                placeholder="Write a caption…"
                autocomplete="off"
                phx-debounce="300"
              />
            </form>
          <% else %>
            <form id={"#{@id}-url"} class="pe-image__form" phx-submit="image_url">
              <input type="hidden" name="block_id" value={@block.id} />
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
          contenteditable="true"
          phx-update="ignore"
          data-editable
          phx-no-format
        >{if @block.type == "code", do: @block.text, else: raw(@block.text)}</div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("text", %{"id" => id, "text" => text}, socket) do
    {:noreply,
     change(socket, &update_block(&1, id, fn b -> %{b | text: clean(b.type, text)} end))}
  end

  def handle_event("insert", %{"id" => id, "after" => after_id, "type" => type} = params, socket) do
    block = new_block(id, type, clean(type, params["text"]))

    {:noreply,
     change(socket, fn blocks ->
       if Enum.any?(blocks, &(&1.id == id)),
         do: blocks,
         else: insert_after(blocks, after_id, block)
     end)}
  end

  def handle_event("set_type", %{"id" => id, "type" => type, "text" => text}, socket)
      when type in @types do
    {:noreply,
     change(socket, &update_block(&1, id, fn b -> %{b | type: type, text: clean(type, text)} end))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, change(socket, &Enum.reject(&1, fn b -> b.id == id end))}
  end

  def handle_event("move", %{"id" => id, "before" => before_id}, socket) do
    {:noreply,
     change(socket, fn blocks ->
       case Enum.split_with(blocks, &(&1.id == id)) do
         {[block], rest} -> insert_before(rest, before_id, block)
         _ -> blocks
       end
     end)}
  end

  # The one change the server makes itself: the URL becomes an image, so the
  # block is rendered through the stream.
  def handle_event("image_url", %{"block_id" => id, "url" => url}, socket) do
    socket = change(socket, &update_block(&1, id, fn b -> %{b | url: url} end))

    case Enum.find(socket.assigns.blocks, &(&1.id == id)) do
      nil -> {:noreply, socket}
      block -> {:noreply, stream_insert(socket, :blocks, block)}
    end
  end

  def handle_event("image_caption", %{"block_id" => id, "caption" => caption}, socket) do
    {:noreply, change(socket, &update_block(&1, id, fn b -> %{b | caption: caption} end))}
  end

  defp change(socket, fun) do
    socket
    |> assign_blocks(fun.(socket.assigns.blocks))
    |> update(:events, &(&1 + 1))
  end

  defp assign_blocks(socket, blocks) do
    assign(socket, blocks: blocks, state: Jason.encode!(export(blocks), pretty: true))
  end

  defp update_block(blocks, id, fun),
    do: Enum.map(blocks, fn b -> if b.id == id, do: fun.(b), else: b end)

  defp insert_after(blocks, nil, block), do: [block | blocks]

  defp insert_after(blocks, after_id, block) do
    case Enum.find_index(blocks, &(&1.id == after_id)) do
      nil -> blocks ++ [block]
      index -> List.insert_at(blocks, index + 1, block)
    end
  end

  defp insert_before(blocks, nil, block), do: blocks ++ [block]

  defp insert_before(blocks, before_id, block) do
    case Enum.find_index(blocks, &(&1.id == before_id)) do
      nil -> blocks ++ [block]
      index -> List.insert_at(blocks, index, block)
    end
  end

  defp new_block(id, type, text),
    do: %{id: id, type: type, text: text || "", url: nil, caption: ""}

  defp clean("code", text), do: text || ""
  defp clean("image", _text), do: ""
  defp clean(_type, text), do: HTML.sanitize(text, :editor)

  # The blocks in the stored content format (Feather.Content.Blocks): list
  # items are grouped into lists. Images keep their URL (no image id here).
  defp export(blocks) do
    blocks
    |> Enum.reduce([], fn
      %{type: "bulleted"} = b, [%{"type" => "list", "style" => "ul"} = list | rest] ->
        [add_item(list, b) | rest]

      %{type: "numbered"} = b, [%{"type" => "list", "style" => "ol"} = list | rest] ->
        [add_item(list, b) | rest]

      b, acc ->
        [to_content(b) | acc]
    end)
    |> Enum.reverse()
    |> Enum.flat_map(fn
      %{"type" => "image"} = image -> [image]
      block -> Blocks.normalize([block])
    end)
  end

  defp add_item(list, b),
    do: Map.update!(list, "items", &(&1 ++ [%{"content" => b.text, "items" => []}]))

  defp to_content(%{type: "paragraph"} = b),
    do: %{"id" => b.id, "type" => "paragraph", "text" => b.text}

  defp to_content(%{type: "h2"} = b),
    do: %{"id" => b.id, "type" => "header", "level" => 2, "text" => b.text}

  defp to_content(%{type: "h3"} = b),
    do: %{"id" => b.id, "type" => "header", "level" => 3, "text" => b.text}

  defp to_content(%{type: "quote"} = b), do: %{"id" => b.id, "type" => "quote", "text" => b.text}
  defp to_content(%{type: "code"} = b), do: %{"id" => b.id, "type" => "code", "code" => b.text}

  defp to_content(%{type: "bulleted"} = b),
    do: add_item(%{"id" => b.id, "type" => "list", "style" => "ul", "items" => []}, b)

  defp to_content(%{type: "numbered"} = b),
    do: add_item(%{"id" => b.id, "type" => "list", "style" => "ol", "items" => []}, b)

  defp to_content(%{type: "image"} = b),
    do: %{"id" => b.id, "type" => "image", "url" => b.url, "caption" => b.caption}

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
    |> Enum.map(fn {type, text} -> new_block(Ecto.UUID.generate(), type, text) end)
  end
end
