import { Controller } from "@hotwired/stimulus"

// Refreshes the payroll-readiness Turbo Frame when the month/year selects
// change, so HR sees who's ready / blocked / will-be-skipped before creating
// the run. The frame's id ("readiness") is matched out of the /new response.
export default class extends Controller {
  static targets = ["frame"]

  refresh() {
    const month = this.element.querySelector("[name='payroll_run[month]']").value
    const year = this.element.querySelector("[name='payroll_run[year]']").value
    if (!month || !year) return

    const params = new URLSearchParams({ month, year })
    this.frameTarget.src = `/admin/payroll_runs/new?${params}`
  }
}
