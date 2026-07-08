import { Controller } from "@hotwired/stimulus"

// Row selection for bulk actions. Checkboxes are `item` targets; `all` is the
// header checkbox; `bar` (with `count` inside) appears while anything is
// selected; `submit` stays disabled at zero.
export default class extends Controller {
  static targets = ["item", "all", "bar", "count", "submit"]

  connect() {
    this.refresh()
  }

  toggleAll() {
    const on = this.allTarget.checked
    this.itemTargets.forEach((box) => { box.checked = on })
    this.refresh()
  }

  refresh() {
    const selected = this.itemTargets.filter((box) => box.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = selected
    if (this.hasSubmitTarget) this.submitTarget.disabled = selected === 0
    if (this.hasBarTarget) this.barTarget.classList.toggle("hidden", selected === 0)
    if (this.hasAllTarget) {
      this.allTarget.checked = selected > 0 && selected === this.itemTargets.length
      this.allTarget.indeterminate = selected > 0 && selected < this.itemTargets.length
    }
  }

  // Keeps checkbox/button clicks inside a clickable row from opening the drawer.
  stop(event) {
    event.stopPropagation()
  }
}
