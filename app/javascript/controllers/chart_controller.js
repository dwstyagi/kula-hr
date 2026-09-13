import { Controller } from "@hotwired/stimulus"

let libraries
function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = src
    script.onload = resolve
    script.onerror = () => { script.remove(); reject(new Error("Chart library could not load")) }
    document.head.appendChild(script)
  })
}
function loadLibraries() {
  libraries ||= (async () => {
    if (!window.Chart) await loadScript("https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js")
    if (!window.Chartkick) await loadScript("https://cdn.jsdelivr.net/npm/chartkick@5.0.1/dist/chartkick.min.js")
  })().catch(error => { libraries = null; throw error })
  return libraries
}

export default class extends Controller {
  static values = { type: String, data: Array, options: Object }

  async connect() {
    const generation = this.generation = Symbol()
    try {
      await loadLibraries()
      if (this.generation !== generation) return
      const Chart = window.Chartkick[this.typeValue === "pie" ? "PieChart" : "LineChart"]
      this.chart = new Chart(this.element, this.dataValue, this.optionsValue)
    } catch {
      if (this.generation === generation) this.element.textContent = "Chart could not load. Refresh to try again."
    }
  }

  disconnect() {
    this.generation = null
    this.chart?.destroy()
    this.chart = null
  }
}
