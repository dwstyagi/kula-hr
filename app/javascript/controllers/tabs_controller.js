import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }

  connect() {
    const initial = this.activeValue || this.tabTargets[0]?.dataset.tab
    if (initial) this.showTab(initial)
  }

  switch(event) {
    event.preventDefault()
    this.showTab(event.currentTarget.dataset.tab)
  }

  showTab(name) {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === name
      tab.classList.toggle("border-kula-700", isActive)
      tab.classList.toggle("text-kula-800", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-stone-500", !isActive)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.panel !== name)
    })

    this.activeValue = name
  }
}
