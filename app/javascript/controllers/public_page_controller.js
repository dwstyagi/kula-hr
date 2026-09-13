import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.header = this.element.querySelector("#site-header")
    this.onScroll = () => this.header?.classList.toggle("scrolled", window.scrollY > 24)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
    const items = this.element.querySelectorAll(".sr, .sr-stagger")
    if (!window.IntersectionObserver || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      items.forEach(item => item.classList.add("in"))
      return
    }
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add("in")
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.1, rootMargin: "0px 0px -40px 0px" })
    items.forEach(item => this.observer.observe(item))
    const steps = this.element.querySelector("#steps-grid")
    this.lineObserver = new IntersectionObserver(entries => {
      if (entries.some(entry => entry.isIntersecting)) {
        this.element.querySelector("#step-line")?.classList.add("in")
        this.lineObserver.disconnect()
      }
    }, { threshold: 0.25 })
    if (steps) this.lineObserver.observe(steps)
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    this.observer?.disconnect()
    this.lineObserver?.disconnect()
    this.header = null
  }
}
