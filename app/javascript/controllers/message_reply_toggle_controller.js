import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]
  static values = {
    openLabel: String,
    closedLabel: String
  }

  connect() {
    this.sync()
  }

  toggle() {
    this.formTarget.hidden = !this.formTarget.hidden
    this.sync()
  }

  sync() {
    const open = !this.formTarget.hidden

    this.buttonTarget.setAttribute("aria-expanded", open.toString())
    this.buttonTarget.textContent = open ? this.openLabelValue : this.closedLabelValue
  }
}
