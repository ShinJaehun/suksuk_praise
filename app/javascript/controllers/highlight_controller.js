import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { id: String }
    connect() {
        if (!this.hasIdValue) return
        const el = document.getElementById(this.idValue)
        if (!el) return
        el.classList.add("ring-2", "ring-amber-400", "bg-amber-50")
        setTimeout(() => el.classList.remove("ring-2", "ring-amber-400", "bg-amber-50"), 1000)
    }
}
