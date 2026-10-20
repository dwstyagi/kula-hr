import { Controller } from "@hotwired/stimulus"

// Calculates business days between from/to dates and shows remaining balance
export default class extends Controller {
  static targets = ["fromDate", "toDate", "days", "balance", "warning", "duration"]
  static values  = { balances: Object, weekOffPattern: String, holidayDates: Array }

  connect() {
    this.recalculate()
  }

  recalculate() {
    const from = this.fromDateTarget.value
    const to   = this.toDateTarget.value

    if (from && to) {
      let days = this.countBusinessDays(new Date(from), new Date(to))
      const halfDay = this.hasDurationTarget && this.durationTarget.value !== "full_day"
      if (halfDay && from !== to) {
        this.daysTarget.textContent = "Half days require one date"
        this.warningTarget.classList.add("hidden")
        return
      }
      if (halfDay && days > 0) days = 0.5
      this.daysTarget.textContent = `${days} day${days !== 1 ? "s" : ""}`
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
      if (this.isWorkingDay(current) && !this.isHoliday(current)) count++
      current.setUTCDate(current.getUTCDate() + 1)
    }
    return count
  }

  isHoliday(date) {
    const iso = date.toISOString().split("T")[0]  // "YYYY-MM-DD"
    return (this.holidayDatesValue || []).includes(iso)
  }

  // Mirrors the Ruby WorkingDaysCalculator.working_day? logic
  isWorkingDay(date) {
    const day = date.getUTCDay() // Date inputs are parsed at UTC midnight.
    const pattern = this.weekOffPatternValue || "all_saturdays_sundays"

    switch (pattern) {
      case "only_sundays":
        return day !== 0

      case "alternate_saturdays_sundays":
        if (day === 0) return false           // Sunday always off
        if (day !== 6) return true            // Mon–Fri always working
        // 1st and 3rd Saturdays are working; 2nd and 4th are off
        const weekNumber = Math.floor((date.getUTCDate() - 1) / 7) + 1
        return weekNumber === 1 || weekNumber === 3

      default: // all_saturdays_sundays
        return day !== 0 && day !== 6
    }
  }

  checkBalance(requestedDays) {
    const select   = this.element.querySelector("[data-leave-type]")
    const leaveTypeId = select?.value
    if (!leaveTypeId) return

    const remaining = this.balancesValue[leaveTypeId]

    if (remaining === undefined) {
      const unlimited = select.selectedOptions?.[0]?.dataset.unlimited === "true"
      this.balanceTarget.textContent = unlimited ? "Unlimited (unpaid leave)" : "No balance available for this financial year"
      this.warningTarget.classList.toggle("hidden", unlimited)
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
