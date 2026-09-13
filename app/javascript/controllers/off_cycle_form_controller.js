import { Controller } from "@hotwired/stimulus"

// Loads a bounded employee search page while preserving amounts already entered.
// Submit only rows with a positive payment amount, including hidden selections.
export default class extends Controller {
  static values = { url: String }
  static targets = ["bulkAmount", "amount", "row", "search", "department", "count"]

  connect() {
    this.generation = 0
    this.filter()
  }

  disconnect() {
    this.generation++
    clearTimeout(this.searchTimer)
    this.request?.abort()
  }

  search() {
    this.generation++
    clearTimeout(this.searchTimer)
    this.request?.abort()
    this.searchTimer = setTimeout(() => this.loadCandidates(), 250)
  }

  async loadCandidates() {
    if (!this.hasUrlValue) return this.filter()
    const generation = this.generation
    const request = new AbortController()
    this.request = request
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.searchTarget.value)
    if (this.hasDepartmentTarget) url.searchParams.set("department", this.departmentTarget.value)
    try {
      const response = await fetch(url, {signal: request.signal, headers: {Accept: "application/json"}})
      if (!response.ok) return
      const candidates = await response.json()
      if (request.signal.aborted || generation !== this.generation) return
      const body = this.element.querySelector("tbody")
      this.rowTargets.forEach(row => {
        const amount = row.querySelector("[data-off-cycle-form-target='amount']")
        if (!amount?.value || Number(amount.value) <= 0) row.remove()
      })
      const selected = new Set([...body.querySelectorAll("input[name$='[employee_id]']")].map(input => input.value))
      candidates.forEach(employee => {
        if (selected.has(String(employee.id))) return
        const row = document.createElement("tr")
        row.dataset.offCycleFormTarget = "row"
        row.dataset.department = employee.department || ""
        row.dataset.searchText = `${employee.name} ${employee.code}`.toLowerCase()
        const label = row.insertCell()
        label.textContent = `${employee.name} · ${employee.code} · ${employee.department || "No department"}`
        const id = document.createElement("input")
        id.type = "hidden"
        id.name = `payroll_run[off_cycle_payroll_entries_attributes][employee_${employee.id}][employee_id]`
        id.value = employee.id
        label.appendChild(id)
        for (const field of ["gross_amount", "tds_amount", "notes"]) {
          const input = document.createElement("input")
          input.name = `payroll_run[off_cycle_payroll_entries_attributes][employee_${employee.id}][${field}]`
          input.type = field === "notes" ? "text" : "number"
          input.className = "input"
          if (field !== "notes") { input.min = "0"; input.step = "0.01" }
          if (field === "tds_amount") input.value = "0"
          if (field === "gross_amount") input.dataset.offCycleFormTarget = "amount"
          row.insertCell().appendChild(input)
        }
        body.appendChild(row)
      })
      this.filter()
    } catch(error) {
      if (generation === this.generation && error.name !== "AbortError" && this.hasCountTarget) this.countTarget.textContent = "Search failed. Please try again."
    }
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
