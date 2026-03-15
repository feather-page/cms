import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: { type: Boolean, default: true } }

  connect() {
    this.render()
  }

  toggle() {
    this.openValue = !this.openValue
    this.render()
  }

  render() {
    if (this.hasContentTarget) {
      this.contentTarget.style.display = this.openValue ? "flex" : "none"
    }
    if (this.hasIconTarget) {
      this.iconTarget.textContent = this.openValue ? "▼" : "▶"
    }
  }
}
