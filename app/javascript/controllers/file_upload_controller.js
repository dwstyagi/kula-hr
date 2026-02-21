import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "filename", "dropzone"]

  connect() {
    this.dropzoneTarget.addEventListener("dragover",  this.onDragOver.bind(this))
    this.dropzoneTarget.addEventListener("dragenter", this.onDragEnter.bind(this))
    this.dropzoneTarget.addEventListener("dragleave", this.onDragLeave.bind(this))
    this.dropzoneTarget.addEventListener("drop",      this.onDrop.bind(this))
  }

  disconnect() {
    this.dropzoneTarget.removeEventListener("dragover",  this.onDragOver.bind(this))
    this.dropzoneTarget.removeEventListener("dragenter", this.onDragEnter.bind(this))
    this.dropzoneTarget.removeEventListener("dragleave", this.onDragLeave.bind(this))
    this.dropzoneTarget.removeEventListener("drop",      this.onDrop.bind(this))
  }

  onDragOver(event) {
    event.preventDefault()
  }

  onDragEnter(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50")
    this.dropzoneTarget.classList.remove("border-gray-300")
  }

  onDragLeave(event) {
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
      this.dropzoneTarget.classList.add("border-gray-300")
    }
  }

  onDrop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
    this.dropzoneTarget.classList.add("border-gray-300")

    const file = event.dataTransfer.files[0]
    if (!file) return

    if (!file.name.endsWith(".xlsx")) {
      this.showError("Only .xlsx files are supported.")
      return
    }

    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    this.inputTarget.files = dataTransfer.files

    this.showFilename(file.name)
  }

  onFileSelected(event) {
    const file = event.target.files[0]
    if (file) this.showFilename(file.name)
  }

  showFilename(name) {
    this.filenameTarget.textContent = name
    this.filenameTarget.classList.remove("hidden")
    this.labelTarget.classList.add("hidden")
  }

  showError(message) {
    this.filenameTarget.textContent = message
    this.filenameTarget.classList.remove("hidden")
    this.filenameTarget.classList.add("text-red-600")
    this.labelTarget.classList.add("hidden")
  }
}
