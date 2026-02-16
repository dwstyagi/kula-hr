import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "transition-opacity", "duration-300")
    setTimeout(() => this.element.remove(), 300)
  }
}
