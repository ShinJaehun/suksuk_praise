import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["student", "customDates"]

  connect() {
    this.toggleCustomDates()
  }

  classroomChanged(event) {
    if (this.hasStudentTarget) {
      this.studentTarget.value = ""
    }

    const pageInput = this.element.querySelector("[name='page']")
    if (pageInput) {
      pageInput.remove()
    }

    event.target.form?.requestSubmit()
  }

  periodChanged() {
    this.toggleCustomDates()
  }

  toggleCustomDates() {
    if (!this.hasCustomDatesTarget) return

    const periodSelect = this.element.querySelector("[name='period']")
    const customSelected = periodSelect?.value === "custom"

    this.customDatesTarget.classList.toggle("hidden", !customSelected)
    this.customDatesTarget.classList.toggle("flex", customSelected)
  }
}
