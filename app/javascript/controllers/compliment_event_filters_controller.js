import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["student"]

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
}
