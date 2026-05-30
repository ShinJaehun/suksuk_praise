import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["avatarKey", "image"]
  static values = {
    maleKeys: Array,
    femaleKeys: Array,
    allKeys: Array,
    imageSources: Object
  }

  update(event) {
    const avatarKey = this.randomKey(this.keysFor(event.target.value))
    const imageSource = this.imageSourcesValue[avatarKey]

    if (!avatarKey || !imageSource) return

    this.avatarKeyTarget.value = avatarKey
    this.imageTarget.src = imageSource
  }

  keysFor(gender) {
    if (gender === "male") return this.maleKeysValue
    if (gender === "female") return this.femaleKeysValue

    return this.allKeysValue
  }

  randomKey(keys) {
    return keys[Math.floor(Math.random() * keys.length)]
  }
}
