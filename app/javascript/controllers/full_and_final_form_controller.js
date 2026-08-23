import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["earning", "deduction", "gross", "deductions", "net", "recovery"]

  connect() {
    this.calculate()
  }

  calculate() {
    const earnings = this.sum(this.earningTargets)
    const deductions = this.sum(this.deductionTargets)
    const net = Math.max(earnings - deductions, 0)
    const recovery = Math.max(deductions - earnings, 0)

    this.grossTarget.textContent = this.money(earnings)
    this.deductionsTarget.textContent = this.money(deductions)
    this.netTarget.textContent = this.money(net)
    this.recoveryTarget.textContent = this.money(recovery)
  }

  sum(inputs) {
    return inputs.reduce((total, input) => total + (parseFloat(input.value) || 0), 0)
  }

  money(value) {
    return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(value)
  }
}
