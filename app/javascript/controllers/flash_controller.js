import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { timeout: { type: Number, default: 4000 } }

    connect() {
        setTimeout(() => {
            this.element.classList.add("opacity-0", "translate-y-[-10px]")
            setTimeout(() => this.element.remove(), 300)
        }, this.timeoutValue)
    }
}