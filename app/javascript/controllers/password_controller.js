import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "confirmation", "matchMessage"]

  toggle(event) {
    const btn = event.currentTarget
    const input = btn.closest("div").querySelector("input")
    const isHidden = input.type === "password"

    input.type = isHidden ? "text" : "password"

    // Swap eye icon
    btn.querySelector(".icon-show").classList.toggle("hidden", !isHidden)
    btn.querySelector(".icon-hide").classList.toggle("hidden", isHidden)
  }

  checkMatch() {
    const pw = this.passwordTarget.value
    const conf = this.confirmationTarget.value

    if (!conf) {
      this.matchMessageTarget.textContent = ""
      return
    }

    if (pw === conf) {
      this.matchMessageTarget.textContent = "Passwords match"
      this.matchMessageTarget.className = "mt-1 text-xs text-green-600"
    } else {
      this.matchMessageTarget.textContent = "Passwords do not match"
      this.matchMessageTarget.className = "mt-1 text-xs text-red-500"
    }
  }
}
