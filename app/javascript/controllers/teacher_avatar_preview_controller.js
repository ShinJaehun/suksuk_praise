import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["avatarKey", "image", "gender", "avatarSection", "picker", "option"]
  static values = {
    maleKeys: Array,
    femaleKeys: Array,
    allKeys: Array,
    imageSources: Object
  }

  connect() {
    const gender = this.genderTarget.value

    this.filterOptions(gender)
    this.syncSelectedOption()
    this.syncAvatarSection(gender)
  }

  update(event) {
    const gender = event.target.value

    if (!gender) {
      this.avatarKeyTarget.value = ""
      this.closePicker()
      this.filterOptions(gender)
      this.syncSelectedOption()
      this.syncAvatarSection(gender)
      return
    }

    const avatarKey = this.randomKey(this.keysFor(gender))

    this.setAvatar(avatarKey)
    this.filterOptions(gender)
    this.closePicker()
    this.syncAvatarSection(gender)
  }

  togglePicker(event) {
    this.pickerTarget.hidden = !this.pickerTarget.hidden
    event.currentTarget.setAttribute("aria-expanded", String(!this.pickerTarget.hidden))
  }

  select(event) {
    this.setAvatar(event.currentTarget.dataset.avatarKey)
  }

  keysFor(gender) {
    if (gender === "male") return this.maleKeysValue
    if (gender === "female") return this.femaleKeysValue

    return this.allKeysValue
  }

  randomKey(keys) {
    return keys[Math.floor(Math.random() * keys.length)]
  }

  setAvatar(avatarKey) {
    const imageSource = this.imageSourcesValue[avatarKey]
    if (!avatarKey || !imageSource) return

    this.avatarKeyTarget.value = avatarKey
    this.imageTarget.src = imageSource
    this.syncSelectedOption()
  }

  filterOptions(gender) {
    const visibleKeys = this.keysFor(gender)

    this.optionTargets.forEach((option) => {
      option.hidden = !visibleKeys.includes(option.dataset.avatarKey)
    })
  }

  syncAvatarSection(gender) {
    const validSelection = this.keysFor(gender).includes(this.avatarKeyTarget.value)
    this.avatarSectionTarget.hidden = !gender || !validSelection

    if (this.avatarSectionTarget.hidden) this.closePicker()
  }

  closePicker() {
    this.pickerTarget.hidden = true

    const toggle = this.element.querySelector('[data-action~="teacher-avatar-preview#togglePicker"]')
    if (toggle) toggle.setAttribute("aria-expanded", "false")
  }

  syncSelectedOption() {
    this.optionTargets.forEach((option) => {
      const selected = option.dataset.avatarKey === this.avatarKeyTarget.value
      option.setAttribute("aria-pressed", String(selected))
      option.classList.toggle("border-blue-500", selected)
      option.classList.toggle("bg-blue-50", selected)
      option.classList.toggle("ring-2", selected)
      option.classList.toggle("ring-blue-100", selected)

      const check = option.querySelector('[data-teacher-avatar-preview-target~="check"]')
      if (check) check.hidden = !selected
    })
  }
}
