import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { id: String }
    connect() {
        if (!this.hasIdValue) {
            this.element.remove()
            return
        }
        const el = document.getElementById(this.idValue)
        if (el) {
            el.classList.add("ring-2", "ring-amber-400", "bg-amber-50")
            setTimeout(() => el.classList.remove("ring-2", "ring-amber-400", "bg-amber-50"), 1000)
        }
        // effects 컨테이너 내 trigger 노드 누적 방지
        this.element.remove()
    }
}
