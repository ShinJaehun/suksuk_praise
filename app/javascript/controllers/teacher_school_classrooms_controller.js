import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["school", "group"]

  connect() {
    this.update()
  }

  update() {
    const schoolId = this.schoolTarget.value

    this.groupTargets.forEach((group) => {
      const active = schoolId !== "" && group.dataset.schoolId === schoolId
      group.hidden = !active
      group.querySelectorAll('input[type="checkbox"]').forEach((checkbox) => {
        checkbox.disabled = !active
      })
    })
  }
}
