import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "row"]
  static values = {
    countLabel: String
  }

  connect() {
    this.updateCount()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-bulk-student-draft-target='row']")
    if (!row || this.rowTargets.length <= 1) return

    row.remove()
    this.updateCount()
  }

  updateCount() {
    if (!this.hasCountTarget) return

    const count = this.rowTargets.length
    this.countTarget.textContent = this.countLabelValue.replace("%{count}", count)
  }
}
