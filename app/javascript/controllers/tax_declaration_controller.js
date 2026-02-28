import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["regimeSection", "hraFields"]

  connect() {
    this.updateRegimeSections()
  }

  // Show / hide Old Regime deduction sections based on selected regime radio
  toggleRegime() {
    this.updateRegimeSections()
  }

  updateRegimeSections() {
    const selected = this.element.querySelector("input[name*='[regime]']:checked")
    const isOldRegime = selected?.value === "old_regime"

    this.regimeSectionTargets.forEach(el => {
      el.classList.toggle("hidden", !isOldRegime)
    })
  }

  // Show / hide HRA detail fields based on checkbox state
  toggleHra(event) {
    this.hraFieldsTarget.classList.toggle("hidden", !event.target.checked)
  }

  // Clone the hidden <template> for the section and append a new row
  addInvestment(event) {
    const section    = event.currentTarget.dataset.section
    const template   = this.element.querySelector(`[data-investment-template="${section}"]`)
    const list       = this.element.querySelector(`[data-investment-list="${section}"]`)
    const timestamp  = Date.now()

    const html = template.innerHTML.replaceAll("NEW_RECORD", timestamp)
    list.insertAdjacentHTML("beforeend", html)

    // Focus the description field of the new row
    list.lastElementChild?.querySelector("input[type='text']")?.focus()
  }

  // Remove an investment row:
  //   • New (no id field): remove from DOM
  //   • Existing (has id field): set _destroy = "1" and hide
  removeInvestment(event) {
    const row         = event.currentTarget.closest("[data-investment-row]")
    const destroyField = row.querySelector("input[name*='[_destroy]']")
    const idField      = row.querySelector("input[name*='[id]']")

    if (idField?.value) {
      // Existing DB record — mark for destruction, keep in DOM (Rails needs it)
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      // New unsaved row — just remove it
      row.remove()
    }
  }
}
