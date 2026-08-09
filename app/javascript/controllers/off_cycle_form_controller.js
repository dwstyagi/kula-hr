import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bulkAmount", "amount"]

  applyAmount() {
    const value = this.bulkAmountTarget.value
    if (!value || Number(value) <= 0) return
    this.amountTargets.forEach((input) => { input.value = value })
  }

  clearAmounts() {
    this.amountTargets.forEach((input) => { input.value = "" })
  }
}
