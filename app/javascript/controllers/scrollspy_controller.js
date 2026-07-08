import { Controller } from "@hotwired/stimulus"

// Highlights the nav link for the section currently in view.
//   <div data-controller="scrollspy">
//     <a data-scrollspy-target="link" href="#job">Job</a>
//     <section id="job" data-scrollspy-target="section">…</section>
//   </div>
export default class extends Controller {
  static targets = ["link", "section"]
  static classes = ["active"]

  connect() {
    this.observer = new IntersectionObserver(this.#onIntersect, {
      rootMargin: "-20% 0px -70% 0px"
    })
    this.sectionTargets.forEach((s) => this.observer.observe(s))
  }

  disconnect() {
    this.observer?.disconnect()
  }

  // Smooth-scroll on click and highlight immediately.
  jump(event) {
    event.preventDefault()
    const id = event.currentTarget.getAttribute("href").slice(1)
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" })
    this.#activate(id)
  }

  #onIntersect = (entries) => {
    const visible = entries.find((e) => e.isIntersecting)
    if (visible) this.#activate(visible.target.id)
  }

  #activate(id) {
    this.linkTargets.forEach((link) => {
      const active = link.getAttribute("href") === `#${id}`
      this.activeClasses.forEach((cls) => link.classList.toggle(cls, active))
    })
  }
}
