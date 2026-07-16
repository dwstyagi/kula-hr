import { Controller } from "@hotwired/stimulus"

// Animated slide walkthrough for payroll setup.
// Usage: data-controller="payroll-guide" on a wrapper containing
// a launcher button (data-action="payroll-guide#open") and the
// dialog with slide/dot/progress targets.
export default class extends Controller {
  static targets = ["dialog", "slide", "dot", "progress", "prevBtn", "nextBtn", "counter"]

  connect() {
    this.index = 0
    this.boundKeydown = this.handleKeydown.bind(this)
  }

  open() {
    this.index = 0
    this.dialogTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.boundKeydown)
    this.render()
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.boundKeydown)
  }

  next() {
    if (this.index < this.slideTargets.length - 1) {
      this.index++
      this.render()
    } else {
      this.close()
    }
  }

  prev() {
    if (this.index > 0) {
      this.index--
      this.render()
    }
  }

  goTo(event) {
    this.index = Number(event.currentTarget.dataset.index)
    this.render()
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
    if (event.key === "ArrowRight") this.next()
    if (event.key === "ArrowLeft") this.prev()
  }

  render() {
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== this.index)
      if (i === this.index) this.replayAnimations(slide)
    })

    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("bg-kula-700", i === this.index)
      dot.classList.toggle("w-6", i === this.index)
      dot.classList.toggle("bg-stone-300", i !== this.index)
      dot.classList.toggle("w-2", i !== this.index)
    })

    const pct = ((this.index + 1) / this.slideTargets.length) * 100
    if (this.hasProgressTarget) this.progressTarget.style.width = `${pct}%`

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.index + 1} / ${this.slideTargets.length}`
    }

    if (this.hasPrevBtnTarget) {
      this.prevBtnTarget.classList.toggle("invisible", this.index === 0)
    }
    if (this.hasNextBtnTarget) {
      this.nextBtnTarget.textContent =
        this.index === this.slideTargets.length - 1 ? "Done" : "Next →"
    }
  }

  // Restart CSS animations inside the freshly shown slide so each
  // slide replays its entrance choreography every time it appears.
  replayAnimations(slide) {
    slide.querySelectorAll("[class*='animate-'], .draw-stroke").forEach((el) => {
      const classes = [...el.classList].filter(
        (c) => c.startsWith("animate-") || c === "draw-stroke"
      )
      el.classList.remove(...classes)
      void el.offsetWidth // force reflow
      el.classList.add(...classes)
    })
  }
}
