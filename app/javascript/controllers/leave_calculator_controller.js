import { Controller } from "@hotwired/stimulus"

// Calculates business days between from/to dates and shows remaining balance
export default class extends Controller {
  static targets = ["fromDate", "toDate", "days", "balance", "warning"]
  static values  = { balances: Object }

  connect() {
    this.recalculate()
  }

  recalculate() {
    const from = this.fromDateTarget.value
    const to   = this.toDateTarget.value

    if (from && to) {
      const days = this.countBusinessDays(new Date(from), new Date(to))
      this.daysTarget.textContent = days > 0 ? `${days} day${days !== 1 ? "s" : ""}` : "—"
      this.checkBalance(days)
    } else {
      this.daysTarget.textContent = "—"
      this.warningTarget.classList.add("hidden")
    }
  }

  leaveTypeChanged() {
    this.recalculate()
  }

  countBusinessDays(start, end) {
    if (end < start) return 0
    let count = 0
    const current = new Date(start)
    while (current <= end) {
      const day = current.getDay()
      if (day !== 0 && day !== 6) count++ // skip Sun=0, Sat=6
      current.setDate(current.getDate() + 1)
    }
    return count
  }

  checkBalance(requestedDays) {
    const select   = this.element.querySelector("[data-leave-type]")
    const leaveTypeId = select?.value
    if (!leaveTypeId) return

    const remaining = this.balancesValue[leaveTypeId]

    if (remaining === undefined) {
      // LOP or type with no balance record — always allowed
      this.balanceTarget.textContent = "Unlimited"
      this.warningTarget.classList.add("hidden")
      return
    }

    this.balanceTarget.textContent = `${remaining} day${remaining !== 1 ? "s" : ""} available`

    if (requestedDays > remaining) {
      this.warningTarget.classList.remove("hidden")
    } else {
      this.warningTarget.classList.add("hidden")
    }
  }
}
