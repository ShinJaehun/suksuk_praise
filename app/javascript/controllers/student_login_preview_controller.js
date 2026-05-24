import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["select", "image", "name"]

    connect() {
        this.defaultImageSrc = this.imageTarget.src
        this.defaultImageAlt = this.imageTarget.alt
        this.defaultName = this.nameTarget.textContent
        this.update()
    }

    update() {
        const option = this.selectTarget.selectedOptions[0]
        const avatarUrl = option?.dataset.avatarUrl
        const studentName = option?.dataset.studentName

        if (!avatarUrl || !studentName) {
            this.imageTarget.src = this.defaultImageSrc
            this.imageTarget.alt = this.defaultImageAlt
            this.imageTarget.classList.add("opacity-40")
            this.nameTarget.textContent = this.defaultName
            return
        }

        this.imageTarget.src = avatarUrl
        this.imageTarget.alt = studentName
        this.imageTarget.classList.remove("opacity-40")
        this.nameTarget.textContent = studentName
    }
}
