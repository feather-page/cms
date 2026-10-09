// Autosave of the editor, without LiveView: `push(payload)` sends one
// idempotent sync (see FeatherWeb.ContentForm) and resolves with the reply.
//
// A sync names the lock_version it builds on and carries what changed since
// the last saved sync: `order`, the ids of all top-level blocks, only when
// the structure changed (else null), and `blocks`, the top-level nodes whose
// JSON changed. Pushes are debounced and one at a time, so each builds on
// the counter of the one before; changes made meanwhile go with the next.
// After a failed push (or `resend()` on a reconnect) it sends the order and
// every block, which heals anything lost. A "stale" reply means the record
// changed elsewhere: nothing more is sent.
//
// `onStatus(status)` reports "saved", "saving", "unsaved" (the last push
// failed; it retries) or "conflict". `settled()` sends pending edits at
// once and resolves with the status when no push is in flight any more.
//
// A record that does not exist yet has no lock_version (null): the first
// sync creates it, and the counter comes with the reply or `adopt()`.
// `adopt()` takes the counters of the record's own saves outside the
// editor (its form fields); never pass it a counter from elsewhere, e.g.
// one rendered after a reconnect.

import {filled} from "./schema"

const DEBOUNCE_MS = 500
const RETRY_MS = 3000

// Image, embed and book blocks that are not filled yet are not stored: they
// join the order once filled, so the order that places them goes out with
// them.
export function snapshot(doc) {
  const order = []
  const blocks = new Map()

  doc.forEach((node) => {
    if (!filled(node)) return
    order.push(node.attrs.id)
    blocks.set(node.attrs.id, JSON.stringify(node.toJSON()))
  })

  return {order, blocks}
}

// What `now` has that `sent` (null: nothing known to be saved) lacks, or
// null when nothing changed.
export function changes(sent, now) {
  const orderChanged = !sent || sent.order.join(" ") !== now.order.join(" ")
  const blocks = []

  for (const [id, json] of now.blocks) {
    if (!sent || sent.blocks.get(id) !== json) blocks.push(JSON.parse(json))
  }

  if (!orderChanged && blocks.length === 0) return null
  return {order: orderChanged ? now.order : null, blocks}
}

export class BlockSync {
  constructor(doc, {lockVersion, push, onStatus}) {
    this.doc = doc
    this.lockVersion = lockVersion
    this.pushSync = push
    this.onStatus = onStatus
    // Nothing is known to be saved yet: the first sync sends everything, so
    // ids the editor gave blocks while loading reach the server too.
    this.sent = null
    this.status = "saved"
    this.waiting = []
  }

  // The document changed.
  update(doc) {
    this.doc = doc
    if (this.status === "conflict") return

    this.setStatus("saving")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.sync(), DEBOUNCE_MS)
  }

  // A newer counter of the record after a save of the same view (its form
  // fields, or the save that created the record). A sync that was refused
  // before the record existed is sent again.
  adopt(lockVersion) {
    if (this.lockVersion != null && lockVersion <= this.lockVersion) return

    this.lockVersion = lockVersion
    if (this.status === "unsaved" && !this.inFlight) this.sync()
  }

  // The record changed elsewhere (e.g. noticed by a form field save).
  conflict() {
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)
    this.setStatus("conflict")
  }

  // Sends everything with the next sync, e.g. after a reconnect.
  resend() {
    this.sent = null
    this.sync()
  }

  // Whether some change is not saved yet and may still be.
  pending() {
    return this.status === "saving" || this.status === "unsaved"
  }

  // Sends pending edits at once (also those typed while a push is in
  // flight, which go with the next one) and resolves with the status once
  // nothing is in flight.
  settled() {
    return new Promise((resolve) => {
      this.waiting.push(resolve)
      this.sync()
    })
  }

  sync() {
    this.push()
    this.settle()
  }

  settle() {
    if (this.inFlight) return
    const waiting = this.waiting
    this.waiting = []
    waiting.forEach((resolve) => resolve(this.status))
  }

  push() {
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)
    this.timer = this.retryTimer = null
    if (this.inFlight || this.stopped || this.status === "conflict") return
    // A record that does not exist yet comes into being with the first edit.
    if (this.lockVersion == null && this.status === "saved") return

    const now = snapshot(this.doc)
    const payload = changes(this.sent, now)
    if (!payload) return this.setStatus("saved")

    this.inFlight = true
    this.setStatus("saving")

    this.pushSync({lock_version: this.lockVersion, ...payload}).then(
      (reply) => this.replied(reply, now),
      () => this.failed({retry: true})
    )
  }

  replied(reply, now) {
    this.inFlight = false

    switch (reply?.status) {
      case "saved":
        this.lockVersion = Math.max(this.lockVersion ?? 0, reply.lock_version)
        this.sent = now
        return this.sync()
      case "stale":
        this.setStatus("conflict")
        return this.settle()
      default:
        // The server refused the payload; sending it again would not help,
        // the next change sends everything.
        return this.failed({retry: false})
    }
  }

  failed({retry}) {
    this.inFlight = false
    this.sent = null
    this.setStatus("unsaved")
    if (retry) this.retryTimer = setTimeout(() => this.sync(), RETRY_MS)
    this.settle()
  }

  setStatus(status) {
    if (status === this.status) return
    this.status = status
    this.onStatus(status)
  }

  destroy() {
    this.stopped = true
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)
  }
}
