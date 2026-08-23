import { Controller } from "@hotwired/stimulus"

// Drives the off-cycle "employees and amounts" table. The form lists every
// eligible employee, so on a large tenant this is a few hundred rows of which
// HR usually fills two or three. Filtering narrows what is on screen, and
// pruning drops the untouched rows from the POST body on submit.
export default class extends Controller {
  static targets = ["bulkAmount", "amount", "row", "search", "department", "count"]

  connect() {
    this.filter()
  }

  filter() {
    const term = (this.hasSearchTarget ? this.searchTarget.value : "").trim().toLowerCase()
    const department = this.hasDepartmentTarget ? this.departmentTarget.value : ""
    let visible = 0

    this.rowTargets.forEach((row) => {
      const matchesTerm = !term || (row.dataset.searchText || "").includes(term)
      const matchesDepartment = !department || row.dataset.department === department
      const shown = matchesTerm && matchesDepartment

      row.hidden = !shown
      if (shown) visible += 1
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = `Showing ${visible} of ${this.rowTargets.length}`
    }
  }

  // "Apply to all" means the rows HR can currently see — applying a bonus to
  // employees hidden behind a department filter would be a nasty surprise.
  applyAmount() {
    const value = this.bulkAmountTarget.value
    if (!value || Number(value) <= 0) return

    this.visibleAmountInputs().forEach((input) => { input.value = value })
  }

  clearAmounts() {
    this.visibleAmountInputs().forEach((input) => { input.value = "" })
  }

  // Disabled fields are left out of the submitted FormData, so a row with no
  // amount never reaches the server. Rows are pruned on their own amount only,
  // never on visibility: an amount typed before filtering must still be sent.
  pruneBlankRows() {
    this.rowTargets.forEach((row) => {
      const amount = row.querySelector("[data-off-cycle-form-target='amount']")
      const blank = !amount || amount.value.trim() === "" || Number(amount.value) <= 0

      row.querySelectorAll("input, select, textarea").forEach((field) => {
        field.disabled = blank
      })
    })
  }

  visibleAmountInputs() {
    return this.amountTargets.filter((input) => !input.closest("tr")?.hidden)
  }
}
