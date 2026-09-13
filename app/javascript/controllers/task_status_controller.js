import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onVisibility = () => { if (!document.hidden) this.schedule(0) }
    document.addEventListener("visibilitychange", this.onVisibility)
    this.schedule()
  }

  schedule(delay = 5000) {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      if (document.hidden) this.schedule()
      else window.Turbo.visit(window.location.href, { action: "replace" })
    }, delay)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("visibilitychange", this.onVisibility)
  }
}
