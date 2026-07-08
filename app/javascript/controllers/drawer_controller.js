import { Controller } from "@hotwired/stimulus"

// Slide-over drawer. Lives on a container that wraps the whole page section:
//
//   <div data-controller="drawer">
//     <a data-action="drawer#open" data-drawer-url-param="/admin/leave_requests/1">…</a>
//     <div data-drawer-target="backdrop" class="drawer-backdrop opacity-0 pointer-events-none" data-action="click->drawer#close"></div>
//     <aside data-drawer-target="panel" class="drawer-panel translate-x-full">
//       <turbo-frame id="drawer" data-drawer-target="frame"></turbo-frame>
//     </aside>
//   </div>
//
// open() sets the turbo-frame src so the detail loads lazily, then slides in.
export default class extends Controller {
  static targets = ["panel", "backdrop", "frame"]

  connect() {
    this.onKeydown = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.body.style.overflow = ""
  }

  open(event) {
    event.preventDefault()
    const url = event.params.url || event.currentTarget.getAttribute("href")
    if (url && this.hasFrameTarget && this.frameTarget.src !== url) {
      this.frameTarget.innerHTML = this.#skeleton()
      this.frameTarget.src = url
    }
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    document.body.style.overflow = ""
  }

  // Close after a successful form submit inside the drawer (e.g. approve/reject).
  submitEnd(event) {
    if (event.detail.success) this.close()
  }

  #skeleton() {
    return `
      <div class="p-6 space-y-4 animate-pulse" aria-hidden="true">
        <div class="h-6 w-2/3 rounded bg-stone-200"></div>
        <div class="h-4 w-1/2 rounded bg-stone-100"></div>
        <div class="h-24 rounded-xl bg-stone-100"></div>
        <div class="h-4 w-3/4 rounded bg-stone-100"></div>
        <div class="h-4 w-2/3 rounded bg-stone-100"></div>
      </div>`
  }
}
