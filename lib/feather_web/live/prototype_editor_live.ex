defmodule FeatherWeb.PrototypeEditorLive do
  @moduledoc """
  PROTOTYPE, throwaway: a Notion-like block editor on LiveView. Not for
  `main`; dev only at `/dev/editor-prototype`, without tests. A
  `:persistent_term` stands in for the database (`?reset=1` starts over).

  It answers one question: do typing, Enter, Backspace, focus and type
  changes feel instant when the server is far away?

  The client owns the block list. It is rendered once (`phx-update="ignore"`,
  editable once the hooks run) and then only changed in the DOM:

    * `.BlockEditor` edits: keys as `beforeinput` (Android, IME), slash menu,
      shortcuts, paste, the toolbar, block selection, gutter, drag and drop.
      It never talks to the server.
    * `.BlockSync` observes the list and pushes one idempotent `sync` event
      with the order and the changed texts (for images URL and caption),
      debounced; everything after a failed push or a reconnect. Ids are made
      on the client in the `Blocks` format, so the server never echoes an
      edit back.
    * `.Latency` simulates a far server.

  The server validates and sanitizes what it gets and keeps the stored
  format (`export/1`), shown as JSON on demand. The title is client-only.

  Known limits, on purpose: several tabs on the document are
  last-writer-wins (each tab's full resync overwrites the others). Undo is
  only disabled, there is no own undo yet. `enableLatencySim` combined with
  a dropped connection can wedge the LiveView client; that is an artifact
  of the simulator, not of the editor.
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
    blocks = (!reset? && :persistent_term.get(__MODULE__, nil)) || store(sample_blocks())

    {:ok,
     socket
     |> assign(page_title: "Editor prototype", menu: @menu, events: 0, show_state: false)
     |> assign(initial: blocks, blocks: blocks)
     |> assign_state(), temporary_assigns: [initial: []]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="pe-editor" class="pe" phx-hook=".BlockEditor">
        <div class="pe-main">
          <div id="pe-head" phx-update="ignore">
            <p class="pe-badge">Prototype · blocks kept in memory, the title is not saved</p>
            <input
              id="pe-title"
              class="pe-title"
              placeholder="Untitled (not saved)"
              value="Writing in feather"
              autocomplete="off"
            />
          </div>
          <div id="pe-gutter" class="pe-gutter" phx-update="ignore" hidden>
            <button type="button" class="pe-gutter__btn" data-action="add" title="Add a block below">
              <.icon name="plus" size={16} />
            </button>
            <span
              class="pe-gutter__btn pe-handle"
              draggable="true"
              title="Drag to move, click to select"
            >
              ⋮⋮
            </span>
          </div>
          <div id="pe-drop" class="pe-drop" phx-update="ignore" hidden></div>
          <div
            id="pe-blocks"
            class="pe-blocks"
            phx-update="ignore"
            phx-hook=".BlockSync"
            tabindex="-1"
          >
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
          <div id="pe-toolbar" class="pe-toolbar" hidden>
            <button type="button" class="pe-toolbar__touch" data-cmd="slash" title="Blocks">/</button>
            <button type="button" data-cmd="bold" title="Bold"><b>B</b></button>
            <button type="button" data-cmd="italic" title="Italic"><i>i</i></button>
            <button type="button" data-cmd="underline" title="Underline"><u>U</u></button>
            <button type="button" data-cmd="code" title="Inline code (Ctrl+E)">
              <code>&lt;/&gt;</code>
            </button>
            <button type="button" data-cmd="link" title="Link (Ctrl+K)">Link</button>
            <button type="button" class="pe-toolbar__touch" data-move="up" title="Move up">↑</button>
            <button type="button" class="pe-toolbar__touch" data-move="down" title="Move down">↓</button>
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
        const FORMAT_KEYS = {k: "link", e: "code"}
        const HEADINGS = ["h2", "h3"]
        // Cmd on Apple devices, Ctrl elsewhere (Ctrl+A on a Mac moves to the line start).
        const modKey = (e) => (/Mac|iPhone|iPad/.test(navigator.platform) ? e.metaKey : e.ctrlKey)

        // Ids like Feather.Content.Blocks generates them: 10 characters of [0-9a-zA-Z].
        const ID_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        const newId = () => Array.from(crypto.getRandomValues(new Uint8Array(10)), (b) => ID_CHARS[b % 62]).join("")
        const elOf = (node) => (node && node.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement)
        const blockOf = (node) => elOf(node)?.closest(".pe-block")
        const editableOf = (block) => block?.querySelector(":scope > [data-editable]")
        const isText = (block) => block && block.dataset.type !== "image"
        // The rule of Feather.Content.HTML.safe_url?/1: relative, or http(s), mailto, tel.
        const safeUrl = (url) => {
          const scheme = url.replace(/[\x00-\x20\x7F-\x9F]/g, "").toLowerCase().match(/^([^\/?#]*?):/)
          return !scheme || ["http", "https", "mailto", "tel"].includes(scheme[1])
        }
        // The server's rule (web_url?/1): http(s) with a host, normalized as the browser does.
        const webUrl = (value) => {
          try {
            const url = new URL(value.trim())
            return ["http:", "https:"].includes(url.protocol) && url.hostname ? url.href : null
          } catch {
            return null
          }
        }
        // A lone "\n" (left by Shift+Enter) shows as an empty line: the block is empty.
        const tidy = (node) => { if (/^\n?$/.test(node.textContent) && !node.querySelector("img")) node.innerHTML = "" }
        // Removes a "\n" at the start or end of node, where a block was split.
        const trimBreak = (node, atEnd) => {
          const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT)
          const texts = []
          while (walker.nextNode()) if (walker.currentNode.length) texts.push(walker.currentNode)
          const text = atEnd ? texts.at(-1) : texts[0]
          const at = atEnd ? text?.length - 1 : 0
          if (text?.data[at] === "\n") text.deleteData(at, 1)
        }

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
        const offsetOf = (ed, node, offset) => {
          const before = document.createRange()
          before.selectNodeContents(ed)
          before.setEnd(node, offset)
          return before.toString().length
        }
        const caretOffset = (ed) => {
          const sel = getSelection()
          if (!sel.rangeCount) return 0
          const range = sel.getRangeAt(0)
          return offsetOf(ed, range.startContainer, range.startOffset)
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
        // What Feather.Content.HTML keeps (:editor mode): b, i, u, code, br and a
        // with its href. The browser adds more (style spans, e.g. for bold in a
        // heading); drop it in the DOM too, so the editor shows what is stored.
        const KEEP = ["B", "I", "U", "A", "CODE", "BR"]
        const extraAttr = (el) => [...el.attributes].some((a) => !(el.tagName === "A" && a.name === "href"))
        const normalize = (ed) => {
          const extra = [...ed.querySelectorAll("*")].filter((el) => !KEEP.includes(el.tagName) || extraAttr(el))
          if (!extra.length) return
          const range = getSelection().rangeCount && getSelection().getRangeAt(0)
          const kept = range && ed.contains(range.startContainer) &&
            [offsetOf(ed, range.startContainer, range.startOffset), offsetOf(ed, range.endContainer, range.endOffset)]
          for (const el of extra) {
            if (!KEEP.includes(el.tagName)) el.replaceWith(...el.childNodes)
            else [...el.attributes].forEach((a) => a.name !== "href" && el.removeAttribute(a.name))
          }
          if (!kept) return
          getSelection().removeAllRanges()
          getSelection().addRange(rangeAt(ed, ...kept))
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
            this.toolbar = this.el.querySelector("#pe-toolbar")
            // Touch screens: the toolbar is docked above the keyboard while a block
            // has the focus, where the native selection menu does not cover it.
            this.touch = matchMedia("(pointer: coarse)").matches
            this.toolbar.classList.toggle("is-docked", this.touch)
            this.slash = null
            this.dragged = null
            this.selected = []
            // Blocks render read-only: text typed before the hooks exist would
            // never reach the server.
            for (const block of this.list.children) setType(block, block.dataset.type)

            this.el.addEventListener("keydown", (e) => this.onKeydown(e))
            this.el.addEventListener("beforeinput", (e) => this.onBeforeinput(e))
            this.el.addEventListener("input", (e) => this.onInput(e))
            this.el.addEventListener("compositionend", (e) => this.onCompositionend(e))
            this.el.addEventListener("paste", (e) => this.onPaste(e))
            this.el.addEventListener("submit", (e) => this.onSubmit(e))
            this.el.addEventListener("click", (e) => this.onClick(e))
            this.el.addEventListener("mousedown", (e) => this.onMousedown(e))
            this.el.addEventListener("focusout", () => this.closeMenu())
            this.menu.addEventListener("mousemove", (e) => {
              const index = this.visibleItems().indexOf(e.target.closest("[data-type]"))
              if (this.slash && index >= 0 && index !== this.menuIndex) {
                this.menuIndex = index
                this.updateMenu()
              }
            })
            this.onSelection = () => {
              this.menuOpen()
              this.updateToolbar()
            }
            document.addEventListener("selectionchange", this.onSelection)
            visualViewport?.addEventListener("resize", this.onSelection)
            visualViewport?.addEventListener("scroll", this.onSelection)
            this.onMouseup = () => {
              this.dragSelect = null
              this.list.classList.remove("is-selecting")
            }
            document.addEventListener("mouseup", this.onMouseup)
            this.el.addEventListener("copy", (e) => this.onCopy(e))
            this.el.addEventListener("cut", (e) => this.onCopy(e) && this.deleteBlocks(this.selected))
            this.main = this.el.querySelector(".pe-main")
            this.gutter = this.el.querySelector("#pe-gutter")
            this.dropLine = this.el.querySelector("#pe-drop")
            this.main.addEventListener("mousemove", (e) => this.onMousemove(e))
            this.main.addEventListener("mouseleave", () => { if (!this.dragged) this.gutter.hidden = true })
            this.main.addEventListener("dragstart", (e) => this.onDragstart(e))
            this.main.addEventListener("dragover", (e) => this.onDragover(e))
            this.main.addEventListener("drop", (e) => this.onDrop(e))
            this.main.addEventListener("dragend", () => this.endDrag())
          },

          destroyed() {
            document.removeEventListener("selectionchange", this.onSelection)
            document.removeEventListener("mouseup", this.onMouseup)
            visualViewport?.removeEventListener("resize", this.onSelection)
            visualViewport?.removeEventListener("scroll", this.onSelection)
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
            trimBreak(ed, true)
            trimBreak(holder, false)
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
            if (this.menuOpen() && this.menuKey(e)) return
            if (this.selected.length && e.target === this.list) return this.selectionKey(e)
            if (e.target.name === "url" && e.key === "Backspace" && e.target.value === "") {
              e.preventDefault()
              return this.deleteBlocks([blockOf(e.target)])
            }
            if (e.target.matches(".pe-caption") && e.key === "Enter") {
              e.preventDefault()
              return this.moveOn(blockOf(e.target))
            }
            if (e.target.id === "pe-title" && (e.key === "Enter" || e.key === "ArrowDown")) {
              e.preventDefault()
              const first = [...this.list.children].find(isText)
              if (first) setCaret(editableOf(first), 0)
              return
            }
            const ed = e.target.closest?.("[data-editable]")
            if (!ed) return
            const block = blockOf(ed)
            const mod = modKey(e)

            if (e.key === "Escape") {
              e.preventDefault()
              return this.selectBlocks(block, block)
            }
            if (mod && FORMAT_KEYS[e.key] && this.formatRange()) {
              e.preventDefault()
              return this.format(FORMAT_KEYS[e.key])
            }
            if (mod && e.shiftKey && (e.key === "ArrowUp" || e.key === "ArrowDown")) {
              e.preventDefault()
              return this.moveWithCaret(ed, e.key === "ArrowUp")
            }
            // Like Notion: Ctrl+A selects the block's text, a second one all blocks.
            if (mod && e.key === "a" && ed.textContent && getSelection().toString().length === ed.textContent.length) {
              e.preventDefault()
              return this.selectBlocks(this.list.firstElementChild, this.list.lastElementChild)
            }
            if (e.key === "Enter" && mod && block.dataset.type === "code") {
              e.preventDefault()
              return this.split(block)
            }
            // Tab indents code; elsewhere, and with Shift, it moves the focus as usual.
            if (e.key === "Tab" && !e.shiftKey && block.dataset.type === "code") {
              e.preventDefault()
              return document.execCommand("insertText", false, "  ")
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
            } else if (e.inputType === "formatBold" && HEADINGS.includes(type)) {
              // Headings are bold already; the browser would add a style span.
              e.preventDefault()
            } else if (e.inputType === "insertParagraph" && type !== "code") {
              e.preventDefault()
              if (this.menuOpen()) this.choose(this.visibleItems()[this.menuIndex].dataset.type)
              else if (ed.textContent === "" && [...LIST_TYPES, "quote"].includes(type)) this.changeType(block, "paragraph")
              else this.split(block)
            } else if (e.inputType === "deleteContentBackward" && atStart) {
              e.preventDefault()
              const prev = block.previousElementSibling
              if (type !== "paragraph") this.changeType(block, "paragraph")
              else if (isText(prev)) this.merge(block, prev)
              else if (prev && ed.textContent === "") {
                block.remove()
                prev.querySelector("input")?.focus()
              }
            } else if (e.inputType === "deleteContentForward" && atEnd) {
              e.preventDefault()
              const next = block.nextElementSibling
              if (isText(next)) this.merge(next, block)
            }
          },

          onInput(e) {
            const ed = e.target.closest?.("[data-editable]")
            if (!ed || e.isComposing) return
            this.gutter.hidden = true
            if (blockOf(ed).dataset.type !== "code") normalize(ed)
            tidy(ed)
            if (this.slash) this.updateMenu()
            if (e.inputType === "insertText") this.afterTyping(ed, e.data)
          },

          // With an IME, and with most Android keyboards, typed text arrives as
          // insertCompositionText and is final only at compositionend.
          onCompositionend(e) {
            const ed = e.target.closest?.("[data-editable]")
            if (!ed) return
            tidy(ed)
            if (this.slash) this.updateMenu()
            this.afterTyping(ed, e.data)
          },

          // Opens the slash menu or applies a markdown shortcut (full-width
          // forms count, as an IME types them).
          afterTyping(ed, data) {
            const block = blockOf(ed)
            if (block.dataset.type === "code") return
            const char = (data || "").normalize("NFKC").slice(-1)
            if (char === "/" && !this.slash) return this.openMenu(ed)
            if (!/\s/.test(char)) return
            const before = rangeAt(ed, 0, caretOffset(ed)).toString()
            const type = SHORTCUTS[before.normalize("NFKC").match(/^(\S+)\s$/)?.[1]]
            if (!type) return
            rangeAt(ed, 0, before.length).deleteContents()
            tidy(ed)
            this.changeType(block, type)
          },

          onPaste(e) {
            const ed = e.target.closest?.("[data-editable]")
            const block = blockOf(ed)
            // Code blocks are plaintext-only: the browser pastes plain text itself.
            if (!ed || block.dataset.type === "code") return
            e.preventDefault()
            const text = e.clipboardData.getData("text/plain")
            const [first = "", ...lines] = text.split(/\r?\n/).filter((line) => line.trim() !== "")
            if (!text.includes("\n")) return document.execCommand("insertText", false, text)
            if (!lines.length) return document.execCommand("insertText", false, first)
            // The text after the caret moves to the end of the last pasted line.
            const range = getSelection().getRangeAt(0)
            range.deleteContents()
            const after = document.createRange()
            after.selectNodeContents(ed)
            after.setStart(range.startContainer, range.startOffset)
            const tail = document.createElement("div")
            tail.appendChild(after.extractContents())
            tidy(tail)
            ed.append(first)
            const type = LIST_TYPES.includes(block.dataset.type) ? block.dataset.type : "paragraph"
            let ref = block
            for (const line of lines) {
              ref = this.createBlock(type, "", ref)
              editableOf(ref).append(line)
            }
            editableOf(ref).append(...tail.childNodes)
            setCaret(editableOf(ref), lines.at(-1).length)
          },

          // ---- image -------------------------------------------------------

          // The client owns the URL like the caption: the image shows at once,
          // .BlockSync sends both, and the caret moves on.
          onSubmit(e) {
            const form = e.target.closest(".pe-image__form")
            if (!form) return
            e.preventDefault()
            const url = webUrl(form.elements.url.value)
            form.querySelector(".pe-hint").hidden = !!url
            if (!url) return
            const block = blockOf(form)
            form.replaceWith(Object.assign(document.createElement("img"), {src: url, alt: ""}))
            block.querySelector(".pe-caption").hidden = false
            this.moveOn(block)
          },

          moveOn(block) {
            const next = block.nextElementSibling
            const empty = isText(next) && editableOf(next).textContent === ""
            setCaret(editableOf(empty ? next : this.createBlock("paragraph", "", block)), 0)
          },

          // ---- block selection (Escape, a click on the handle or an image) ----

          selectBlocks(anchor, head) {
            this.clearSelection()
            const all = [...this.list.children]
            const [from, to] = [all.indexOf(anchor), all.indexOf(head)].sort((a, b) => a - b)
            this.selected = all.slice(from, to + 1)
            this.selected.forEach((b) => b.classList.add("is-selected"))
            this.anchor = anchor
            this.head = head
            getSelection().removeAllRanges()
            this.list.focus({preventScroll: true})
            head.scrollIntoView({block: "nearest"})
          },

          clearSelection() {
            this.selected.forEach((b) => b.classList.remove("is-selected"))
            this.selected = []
          },

          selectionKey(e) {
            const blocks = this.selected
            const mod = modKey(e)
            const up = e.key === "ArrowUp"
            if (mod && (e.key === "c" || e.key === "x")) return
            e.preventDefault()
            if (e.key === "Escape") this.clearSelection()
            else if (e.key === "Enter" && isText(this.head)) {
              this.clearSelection()
              setCaret(editableOf(this.head), editableOf(this.head).textContent.length)
            } else if (e.key === "Backspace" || e.key === "Delete") this.deleteBlocks(blocks)
            else if (mod && e.key === "a") this.selectBlocks(this.list.firstElementChild, this.list.lastElementChild)
            else if (mod && e.shiftKey && (up || e.key === "ArrowDown")) this.moveBlocks(blocks, up)
            else if (up || e.key === "ArrowDown") {
              const edge = up ? blocks[0] : blocks.at(-1)
              const next = (e.shiftKey ? this.head : edge)[up ? "previousElementSibling" : "nextElementSibling"]
              if (next) this.selectBlocks(e.shiftKey ? this.anchor : next, next)
            }
          },

          onCopy(e) {
            if (!this.selected.length || e.target !== this.list) return false
            e.preventDefault()
            const texts = this.selected.filter(isText)
            e.clipboardData.setData("text/plain", texts.map((b) => editableOf(b).textContent).join("\n"))
            e.clipboardData.setData("text/html", texts.map((b) => `<p>${editableOf(b).innerHTML}</p>`).join(""))
            return true
          },

          moveBlocks(blocks, up) {
            const ref = up ? blocks[0].previousElementSibling : blocks.at(-1).nextElementSibling
            ref?.[up ? "before" : "after"](...blocks)
          },

          moveWithCaret(ed, up) {
            const offset = caretOffset(ed)
            this.moveBlocks([blockOf(ed)], up)
            setCaret(ed, offset)
          },

          deleteBlocks(blocks) {
            const prev = textSibling(blocks[0], "previousElementSibling")
            const next = textSibling(blocks.at(-1), "nextElementSibling")
            this.clearSelection()
            blocks.forEach((block) => block.remove())
            if (prev) setCaret(editableOf(prev), editableOf(prev).textContent.length)
            else if (next) setCaret(editableOf(next), 0)
            else setCaret(editableOf(this.createBlock("paragraph", "", this.list, "append")), 0)
          },

          // ---- slash menu ----------------------------------------------------

          openMenu(ed) {
            this.slash = {ed, start: caretOffset(ed) - 1}
            this.menuIndex = 0
            this.updateMenu()
          },

          // The menu stays open while the caret is behind its "/". selectionchange
          // comes late, so the keys check it themselves.
          menuOpen() {
            if (this.slash) this.updateMenu()
            return !!this.slash
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
            if (!ed.isConnected || caret <= start || (ed.textContent[start] || "").normalize("NFKC") !== "/") return this.closeMenu()
            const query = ed.textContent.slice(start + 1, caret).normalize("NFKC").toLowerCase()
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
            const bottom = window.visualViewport ? visualViewport.offsetTop + visualViewport.height : innerHeight
            const top = below + this.menu.offsetHeight > bottom ? rect.top - this.menu.offsetHeight - 6 : below
            this.menu.style.left = `${Math.max(8, rect.left)}px`
            this.menu.style.top = `${Math.max(8, top)}px`
            const active = items[this.menuIndex]
            const {scrollTop, clientHeight} = this.menu
            if (active.offsetTop < scrollTop) this.menu.scrollTop = active.offsetTop - 6
            else if (active.offsetTop + active.offsetHeight > scrollTop + clientHeight) {
              this.menu.scrollTop = active.offsetTop + active.offsetHeight - clientHeight + 6
            }
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

          // ---- toolbar: formats the selection in a text block ----------------

          // The selection if it can be formatted: text inside one block, not code.
          formatRange() {
            const sel = getSelection()
            const ed = sel.rangeCount && elOf(sel.anchorNode)?.closest("#pe-blocks [data-editable]")
            const ok = ed && !sel.isCollapsed && ed.contains(sel.focusNode) && blockOf(ed).dataset.type !== "code"
            return ok ? sel.getRangeAt(0) : null
          },

          updateToolbar() {
            const range = this.formatRange()
            const caret = this.touch && elOf(getSelection().anchorNode)?.closest("#pe-blocks [data-editable]")
            this.toolbar.hidden = !range && !caret
            if (this.toolbar.hidden) return
            const heading = HEADINGS.includes(blockOf(getSelection().anchorNode)?.dataset.type)
            for (const button of this.toolbar.querySelectorAll("[data-cmd]")) {
              const cmd = button.dataset.cmd
              const active = ["bold", "italic", "underline"].includes(cmd) && document.queryCommandState(cmd)
              button.classList.toggle("is-active", !!active)
              // Not disabled: a disabled button gets no mousedown to keep the selection.
              button.ariaDisabled = cmd === "bold" && heading
            }
            if (this.touch) {
              const view = window.visualViewport || {offsetTop: 0, height: innerHeight}
              this.toolbar.style.top = `${view.offsetTop + view.height - this.toolbar.offsetHeight - 8}px`
              return
            }
            const rect = range.getBoundingClientRect()
            this.toolbar.style.left = `${Math.max(8, rect.left + rect.width / 2 - this.toolbar.offsetWidth / 2)}px`
            this.toolbar.style.top = `${Math.max(8, rect.top - this.toolbar.offsetHeight - 8)}px`
          },

          format(cmd) {
            if (cmd === "slash") return document.execCommand("insertText", false, "/")
            const range = this.formatRange()
            if (!range) return
            const block = blockOf(range.startContainer)
            if (cmd === "code") {
              const code = document.createElement("code")
              code.textContent = range.toString()
              range.deleteContents()
              range.insertNode(code)
              getSelection().selectAllChildren(code)
            } else if (cmd === "link") {
              const url = prompt("Link URL", "https://")
              if (url && safeUrl(url)) document.execCommand("createLink", false, url)
            } else if (!(cmd === "bold" && HEADINGS.includes(block.dataset.type))) {
              document.execCommand(cmd)
            }
            normalize(editableOf(block))
            this.updateToolbar()
          },

          // ---- mouse: gutter, menu, drag & drop -----------------------------

          onMousedown(e) {
            this.goalX = null
            this.clearSelection()
            const ed = e.button === 0 && e.target.closest("[data-editable]")
            this.dragSelect = ed ? blockOf(ed) : null
            if (e.target.closest("#pe-menu, #pe-toolbar")) e.preventDefault()
          },

          // One gutter for the page, moved to the block under the pointer.
          blockAtY(y) {
            const block = blockOf(document.elementFromPoint(this.list.getBoundingClientRect().left + 8, y))
            return this.list.contains(block) ? block : null
          },

          onMousemove(e) {
            if (this.dragged || e.target.closest("#pe-gutter")) return
            const block = this.blockAtY(e.clientY)
            if (!block) return
            // A text selection cannot leave its block: dragging it into another
            // block turns it into a block selection.
            if (this.dragSelect && e.buttons === 1 && block !== this.dragSelect) {
              this.list.classList.add("is-selecting")
              if (block !== this.head || !this.selected.length) this.selectBlocks(this.dragSelect, block)
            }
            this.placeGutter(block)
          },

          placeGutter(block) {
            this.gutterBlock = block
            const ed = editableOf(block)
            const style = ed && getComputedStyle(ed)
            const line = (ed && parseFloat(style.lineHeight)) || 32
            const pad = ed ? ed.offsetTop + parseFloat(style.paddingTop) : 8
            this.gutter.style.top = `${block.offsetTop + pad + line / 2}px`
            this.gutter.hidden = false
          },

          onClick(e) {
            const target = e.target
            const item = target.closest("#pe-menu [data-type]")
            if (item && this.slash) return this.choose(item.dataset.type)
            const cmd = target.closest("#pe-toolbar [data-cmd]")
            if (cmd) return this.format(cmd.dataset.cmd)
            const move = target.closest("#pe-toolbar [data-move]")
            const editing = move && elOf(getSelection().anchorNode)?.closest("#pe-blocks [data-editable]")
            if (editing) return this.moveWithCaret(editing, move.dataset.move === "up")
            if (target.closest(".pe-handle") && this.gutterBlock?.isConnected) {
              return this.selectBlocks(this.gutterBlock, this.gutterBlock)
            }
            const image = target.closest(".pe-image img")
            if (image) return this.selectBlocks(blockOf(image), blockOf(image))

            const add = target.closest("[data-action=add]") && this.gutterBlock?.isConnected
            const append = target.closest("[data-action=append]")
            if (add || append) {
              const last = this.list.lastElementChild
              let block
              if (append && last && isText(last) && editableOf(last).textContent === "") block = last
              else if (append && !last) block = this.createBlock("paragraph", "", this.list, "append")
              else block = this.createBlock("paragraph", "", add ? this.gutterBlock : last)
              const ed = editableOf(block)
              setCaret(ed, 0)
              if (add) document.execCommand("insertText", false, "/")
            }
          },

          onDragstart(e) {
            const block = this.gutterBlock
            if (!e.target.closest?.(".pe-handle") || !block?.isConnected) return
            this.dragged = block
            e.dataTransfer.effectAllowed = "move"
            e.dataTransfer.setData("text/plain", "")
            e.dataTransfer.setDragImage(block, 0, 0)
            block.classList.add("is-dragging")
          },

          // The target is found by height, so the gaps between blocks and the
          // gutter count too and the line does not flicker.
          onDragover(e) {
            if (!this.dragged) return
            e.preventDefault()
            const target = this.blockAtY(e.clientY)
            if (!target) return
            const rect = target.getBoundingClientRect()
            const after = e.clientY > rect.top + rect.height / 2
            const noop = target === this.dragged ||
              (after ? target.nextElementSibling : target.previousElementSibling) === this.dragged
            this.drop = noop ? null : {target, after}
            this.dropLine.hidden = noop
            this.dropLine.style.top = `${target.offsetTop + (after ? target.offsetHeight : 0) - 2}px`
          },

          onDrop(e) {
            if (!this.dragged) return
            e.preventDefault()
            if (this.drop) {
              const {target, after} = this.drop
              target[after ? "after" : "before"](this.dragged)
            }
            this.endDrag()
          },

          endDrag() {
            this.drop = null
            this.dropLine.hidden = true
            this.dragged?.classList.remove("is-dragging")
            this.dragged = null
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".BlockSync">
        // The block list is the document. Every change to it is pushed as
        // {order?: [[id, type]], texts?: {id: html | {url, caption}}}, debounced,
        // with only what differs from the last push; after a failed push or a
        // reconnect it sends everything, which heals any loss.
        const textOf = (block) => {
          const ed = block.querySelector(":scope > [data-editable]")
          if (block.dataset.type === "image") {
            return {url: block.querySelector(".pe-image img")?.getAttribute("src") ?? null, caption: block.querySelector(".pe-caption").value}
          }
          if (block.dataset.type === "code") return ed.textContent.replace(/\n$/, "")
          // Shift+Enter puts "\n" into the pre-wrap block; the stored text needs <br>.
          return ed.innerHTML.replace(/\n$/, "").replace(/\n(?![^<]*>)/g, "<br>")
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
            // The debounce would lose the last edits when the tab is hidden or
            // closed; closing also warns while a push is unanswered.
            this.onHide = () => document.visibilityState === "hidden" && this.sync()
            this.onUnload = (e) => {
              this.sync()
              if (this.pending) e.preventDefault()
            }
            document.addEventListener("visibilitychange", this.onHide)
            window.addEventListener("beforeunload", this.onUnload)
          },

          destroyed() {
            this.observer.disconnect()
            clearTimeout(this.timer)
            document.removeEventListener("visibilitychange", this.onHide)
            window.removeEventListener("beforeunload", this.onUnload)
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
            const texts = Object.entries(now.texts).filter(([id, text]) => JSON.stringify(last.texts[id]) !== JSON.stringify(text))
            if (texts.length) payload.texts = Object.fromEntries(texts)
            if (!payload.order && !payload.texts) return this.renderStatus()
            this.sent = now
            this.push("sync", payload).catch(() => { this.sent = null; this.changed() })
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
      <%= if @block.type == "image" do %>
        <div class="pe-image">
          <img :if={@block.url} src={@block.url} alt="" />
          <form :if={!@block.url} class="pe-image__form" novalidate>
            <input
              type="url"
              name="url"
              class="form-control"
              placeholder="Paste an image URL and press Enter"
            />
            <p class="pe-hint" hidden>Only http(s) image URLs work here.</p>
          </form>
          <input
            class="pe-caption"
            value={@block.caption}
            placeholder="Write a caption…"
            autocomplete="off"
            hidden={!@block.url}
          />
        </div>
      <% else %>
        <div
          class="pe-text"
          contenteditable="false"
          data-editable
          phx-no-format
        >{if @block.type == "code", do: @block.text, else: raw(@block.text |> HTML.sanitize(:editor) |> String.replace("<br>", "\n"))}</div>
      <% end %>
    </div>
    """
  end

  # What changed in the document: the block order with types (all of it, or
  # nil when unchanged) and the texts that changed, for an image its URL and
  # caption. The client owns all of it; malformed parts are dropped instead
  # of crashing the process.
  @impl true
  def handle_event("sync", params, socket) do
    order = if is_list(params["order"]), do: params["order"]
    texts = if is_map(params["texts"]), do: params["texts"], else: %{}
    {:noreply, change(socket, &apply_sync(&1, order, texts))}
  end

  def handle_event("toggle_state", _params, socket) do
    socket = update(socket, :show_state, &(!&1))
    {:noreply, assign_state(socket)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp change(socket, fun) do
    socket
    |> assign(blocks: store(fun.(socket.assigns.blocks)))
    |> assign_state()
    |> update(:events, &(&1 + 1))
  end

  # The JSON goes over the wire whole on every event (tens of KB for a long
  # document), so it is only rendered while it is shown.
  defp assign_state(socket) do
    %{show_state: show?, blocks: blocks} = socket.assigns
    assign(socket, state: if(show?, do: Jason.encode!(export(blocks), pretty: true)))
  end

  defp store(blocks) do
    :persistent_term.put(__MODULE__, blocks)
    blocks
  end

  defp apply_sync(blocks, order, texts) do
    known = Map.new(blocks, &{&1.id, &1})

    for [id, type] when is_binary(id) and type in @types <-
          order || Enum.map(blocks, &[&1.id, &1.type]),
        id =~ ~r/\A[0-9a-zA-Z]{10}\z/ do
      block = known[id] || new_block(id, type, "")

      case Map.fetch(texts, id) do
        {:ok, %{"url" => url, "caption" => caption}}
        when type == "image" and is_binary(caption) ->
          %{
            block
            | type: type,
              url: if(is_binary(url) and web_url?(url), do: url),
              caption: caption
          }

        {:ok, text} when is_binary(text) and type != "image" ->
          %{block | type: type, text: clean(type, text)}

        # Code is stored raw: a new type cleans the old text for its own rules.
        _ when block.type != type ->
          %{block | type: type, text: clean(type, block.text)}

        _ ->
          block
      end
    end
  end

  defp web_url?(url) do
    %URI{scheme: scheme, host: host} = URI.parse(url)
    scheme in ~w(http https) and host not in [nil, ""]
  end

  defp new_block(id, type, text),
    do: %{id: id, type: type, text: text, url: nil, caption: ""}

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
    # Ids in the Blocks format (10 of [0-9a-zA-Z]), the only ones the sync takes.
    |> Enum.with_index(fn {type, text}, i -> new_block("sampleBlk#{i}", type, text) end)
  end
end
