import { Controller } from "@hotwired/stimulus"

// Global tooltip controller — attach once to <body>.
// Intercepts native [title] attributes and replaces them with a styled tooltip.
// No changes needed to individual views — all existing title= attributes work automatically.
export default class extends Controller {
  connect() {
    this._show = this.show.bind(this)
    this._hide = this.hide.bind(this)
    this.element.addEventListener("mouseover", this._show)
    this.element.addEventListener("mouseout",  this._hide)
  }

  disconnect() {
    this.element.removeEventListener("mouseover", this._show)
    this.element.removeEventListener("mouseout",  this._hide)
    this.tooltip?.remove()
  }

  show(event) {
    const target = event.target.closest("[title]")
    if (!target || this.tooltip) return

    const text = target.getAttribute("title")
    if (!text) return

    // Stash and remove to prevent the browser's own tooltip
    target.dataset.tooltipText = text
    target.removeAttribute("title")

    this.currentTarget = target
    this.tooltip = document.createElement("div")
    this.tooltip.textContent = text
    this.tooltip.className = [
      "fixed z-[9999] px-2 py-1 rounded-md shadow-md",
      "text-xs font-medium text-white bg-gray-800",
      "pointer-events-none whitespace-nowrap"
    ].join(" ")

    // Start invisible before appending — then fade in via rAF.
    // Without this, the element is already at opacity:1 when the transition
    // class is applied, so the browser sees no change and never animates.
    this.tooltip.style.cssText = "opacity:0; transition: opacity 150ms ease-out;"

    document.body.appendChild(this.tooltip)
    this.position(target)

    requestAnimationFrame(() => {
      if (this.tooltip) this.tooltip.style.opacity = "1"
    })
  }

  hide(event) {
    if (!this.tooltip) return

    // Restore title so it works again next hover
    const target = this.currentTarget
    if (target?.dataset.tooltipText) {
      target.setAttribute("title", target.dataset.tooltipText)
      delete target.dataset.tooltipText
    }

    // Capture reference before nulling — fade out then remove
    const tip = this.tooltip
    this.tooltip = null
    this.currentTarget = null

    tip.style.opacity = "0"
    setTimeout(() => tip.remove(), 150)
  }

  position(target) {
    const rect    = target.getBoundingClientRect()
    const tipRect = this.tooltip.getBoundingClientRect()

    let top  = rect.bottom + 6
    let left = rect.left + rect.width / 2 - tipRect.width / 2

    // Keep within viewport horizontally
    const padding = 8
    left = Math.max(padding, Math.min(left, window.innerWidth - tipRect.width - padding))

    // Flip above if too close to bottom
    if (top + tipRect.height > window.innerHeight - padding) {
      top = rect.top - tipRect.height - 6
    }

    this.tooltip.style.top  = `${top}px`
    this.tooltip.style.left = `${left}px`
  }
}
