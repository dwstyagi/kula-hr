import { Controller } from "@hotwired/stimulus"

// Filters the blog index list in place. Category pages would be a better fit
// once there are enough posts to fill them; with a handful, filtering client
// side avoids publishing thin one-post pages.
export default class extends Controller {
  static targets = ["item", "tab", "count", "empty"]

  connect() {
    this.filter()
  }

  select(event) {
    this.category = event.params.category
    this.filter()
  }

  filter() {
    const active = this.category || "all"
    let shown = 0

    this.itemTargets.forEach((item) => {
      const match = active === "all" || item.dataset.category === active
      item.hidden = !match
      if (match) shown += 1
    })

    this.tabTargets.forEach((tab) => {
      const selected = (tab.dataset.blogFilterCategoryParam || "all") === active
      tab.setAttribute("aria-pressed", selected)
      tab.classList.toggle("blog-tab-active", selected)
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${shown} ${shown === 1 ? "article" : "articles"}`
    }
    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = shown > 0
    }
  }
}
