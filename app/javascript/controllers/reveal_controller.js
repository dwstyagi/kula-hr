import { Controller } from "@hotwired/stimulus"

// Staggered fade-up reveal. Attach to a container; its direct children (or
// explicit item targets) animate in one after another.
//
//   <div data-controller="reveal" data-reveal-delay-value="60">…</div>
export default class extends Controller {
  static targets = ["item"]
  static values = {
    delay: { type: Number, default: 60 },  // ms between items
    start: { type: Number, default: 0 }    // ms before the first item
  }

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    const items = this.hasItemTarget ? this.itemTargets : Array.from(this.element.children)
    items.forEach((el, i) => {
      el.style.animationDelay = `${this.startValue + i * this.delayValue}ms`
      el.classList.add("animate-fade-up")
    })
  }
}
