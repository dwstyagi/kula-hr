import { Controller } from "@hotwired/stimulus"

// Animates a number counting up from 0 with Indian digit grouping.
//
//   <span data-controller="countup" data-countup-value-value="2529760"
//         data-countup-prefix-value="₹">₹25,29,760</span>
//
// The server-rendered text is the no-JS/reduced-motion fallback.
export default class extends Controller {
  static values = {
    value: Number,
    duration: { type: Number, default: 900 },
    prefix: { type: String, default: "" },
    suffix: { type: String, default: "" }
  }

  connect() {
    const target = this.valueValue
    if (!Number.isFinite(target)) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.render(target)
      return
    }

    const startedAt = performance.now()
    const tick = (now) => {
      const t = Math.min((now - startedAt) / this.durationValue, 1)
      const eased = 1 - Math.pow(1 - t, 3)
      this.render(target * eased)
      if (t < 1) this.frame = requestAnimationFrame(tick)
    }
    this.frame = requestAnimationFrame(tick)
  }

  disconnect() {
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  render(n) {
    this.element.textContent =
      this.prefixValue + Math.round(n).toLocaleString("en-IN") + this.suffixValue
  }
}
