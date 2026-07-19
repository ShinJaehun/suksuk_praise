import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewContainer"]
  static values = { initialSource: String }

  connect() {
    this.objectUrl = null
    this.restoreInitialPreview()
  }

  disconnect() {
    this.releaseObjectUrl()
  }

  update() {
    this.releaseObjectUrl()

    const file = this.inputTarget.files?.[0]

    if (!file || !file.type.startsWith("image/")) {
      this.restoreInitialPreview()
      return
    }

    this.objectUrl = URL.createObjectURL(file)
    this.previewTarget.src = this.objectUrl
    this.previewContainerTarget.hidden = false
  }

  restoreInitialPreview() {
    if (this.hasInitialSourceValue && this.initialSourceValue) {
      this.previewTarget.src = this.initialSourceValue
      this.previewContainerTarget.hidden = false
      return
    }

    this.previewTarget.removeAttribute("src")
    this.previewContainerTarget.hidden = true
  }

  releaseObjectUrl() {
    if (!this.objectUrl) return

    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }
}
