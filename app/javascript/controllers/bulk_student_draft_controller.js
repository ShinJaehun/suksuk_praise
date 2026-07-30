import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["addButton", "count", "list", "row", "studentCount", "template"]
  static values = {
    avatarAlt: String,
    boyAvatarKeys: Array,
    boyAvatarUrls: Array,
    countLabel: String,
    girlAvatarKeys: Array,
    girlAvatarUrls: Array,
    maxRows: Number
  }

  connect() {
    this.nextRowIndex = 0
    this.updateCount()
  }

  add(event) {
    event.preventDefault()
    if (this.rowTargets.length >= this.maxRowsValue) return

    const rowKey = `new_${Date.now()}_${this.nextRowIndex++}`
    const wrapper = document.createElement("div")
    wrapper.innerHTML = this.templateTarget.innerHTML.replaceAll("__ROW_KEY__", rowKey).trim()
    const row = wrapper.firstElementChild
    if (!row) return

    const studentNumber = row.querySelector("[data-bulk-student-draft-target='studentNumber']")
    if (studentNumber) studentNumber.value = this.nextStudentNumber()

    this.listTarget.appendChild(row)
    row.querySelector("input[type='text']")?.focus()
    this.updateCount()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-bulk-student-draft-target='row']")
    if (!row || this.rowTargets.length <= 1) return

    row.remove()
    this.updateCount()
  }

  selectGender(event) {
    const radio = event.currentTarget
    const row = radio.closest("[data-bulk-student-draft-target='row']")
    if (!row) return

    const gender = radio.value
    const sameGenderRows = this.rowTargets.filter((candidate) => {
      return candidate.querySelector("input[type='radio']:checked")?.value === gender
    })
    const keys = gender === "boy" ? this.boyAvatarKeysValue : this.girlAvatarKeysValue
    const urls = gender === "boy" ? this.boyAvatarUrlsValue : this.girlAvatarUrlsValue
    if (keys.length === 0 || urls.length === 0) return

    sameGenderRows.forEach((candidate, position) => {
      const poolIndex = position % keys.length
      const avatarKey = candidate.querySelector("[data-bulk-student-draft-target='avatarKey']")
      const preview = candidate.querySelector("[data-bulk-student-draft-target='avatarPreview']")
      const placeholder = candidate.querySelector("[data-bulk-student-draft-target='avatarPlaceholder']")

      if (avatarKey) avatarKey.value = keys[poolIndex]
      if (preview) {
        preview.src = urls[poolIndex]
        preview.alt = this.avatarAltValue
        preview.classList.remove("hidden")
      }
      placeholder?.classList.add("hidden")
    })
  }

  nextStudentNumber() {
    const numbers = this.rowTargets
      .map((row) => row.querySelector("[data-bulk-student-draft-target='studentNumber']")?.value)
      .filter((value) => /^[1-9]\d*$/.test(value))
      .map(Number)

    return numbers.length > 0 ? Math.max(...numbers) + 1 : 1
  }

  updateCount() {
    const count = this.rowTargets.length
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.countLabelValue.replace("%{count}", count)
    }
    if (this.hasStudentCountTarget) {
      this.studentCountTarget.value = count
    }
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = count >= this.maxRowsValue
    }
  }
}
