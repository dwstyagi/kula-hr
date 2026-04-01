import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  toggle() {
    this.sidebarTarget.classList.contains("-translate-x-full") ? this.open() : this.close()
  }

  open() {
    this.sidebarTarget.classList.remove("-translate-x-full")
    // Remove display:none first, then fade in next frame so the transition fires
    this.overlayTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.overlayTarget.style.opacity = "1"
    })
  }

  close() {
    this.sidebarTarget.classList.add("-translate-x-full")
    // Fade out, then hide after transition completes
    this.overlayTarget.style.opacity = "0"
    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
      this.overlayTarget.style.opacity = ""
    }, 200)
  }
}
