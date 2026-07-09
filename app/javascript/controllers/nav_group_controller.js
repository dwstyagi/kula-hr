import { Controller } from "@hotwired/stimulus"

// Collapsible sidebar section. The group root carries data-state="open|closed";
// all visuals (height, chevron, bubbled count pill) are CSS driven off that.
//
// Open state: a group containing the active nav item always opens; otherwise
// the user's last choice (localStorage) wins; first visit defaults to open.
export default class extends Controller {
  static targets = ["content", "button"]
  static values = { key: String }

  connect() {
    const remembered = localStorage.getItem(this.#storageKey)
    const containsActive = this.element.querySelector(".nav-item-active")
    const open = containsActive ? true : remembered === null ? true : remembered === "open"
    this.#apply(open, false)
  }

  toggle() {
    const open = this.element.dataset.state !== "open"
    this.#apply(open, true)
    localStorage.setItem(this.#storageKey, open ? "open" : "closed")
  }

  #apply(open, animate) {
    if (!animate && this.hasContentTarget) {
      // Snap to the restored state without a visible slide on page load.
      this.contentTarget.style.transition = "none"
      requestAnimationFrame(() => { this.contentTarget.style.transition = "" })
    }
    this.element.dataset.state = open ? "open" : "closed"
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", open)
  }

  get #storageKey() {
    return `sidebar-group-${this.keyValue}`
  }
}
