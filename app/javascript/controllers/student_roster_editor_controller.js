import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]
  static values = {
    avatarAlt: String,
    boyAvatarKeys: Array,
    boyAvatarUrls: Array,
    girlAvatarKeys: Array,
    girlAvatarUrls: Array
  }

  selectGender(event) {
    const row = event.currentTarget.closest("[data-student-roster-editor-target='row']")
    if (!row) return

    const gender = event.currentTarget.value
    const keys = gender === "boy" ? this.boyAvatarKeysValue : this.girlAvatarKeysValue
    const urls = gender === "boy" ? this.boyAvatarUrlsValue : this.girlAvatarUrlsValue
    if (keys.length === 0 || urls.length === 0) return

    const avatarKey = row.querySelector("[data-student-roster-editor-target='avatarKey']")
    const preview = row.querySelector("[data-student-roster-editor-target='avatarPreview']")
    if (!avatarKey || !preview) return
    if (
      gender === row.dataset.originalGender &&
      avatarKey.value === row.dataset.originalAvatarKey
    ) return

    let poolIndex = keys.indexOf(avatarKey.value)
    if (poolIndex < 0) {
      poolIndex = Number(row.dataset.rosterPosition || 0) % keys.length
      avatarKey.value = keys[poolIndex]
    }

    if (row.dataset.uploadedAvatar !== "true") {
      preview.src = urls[poolIndex]
      preview.alt = this.avatarAltValue
      preview.classList.remove("hidden")
    }
  }
}
