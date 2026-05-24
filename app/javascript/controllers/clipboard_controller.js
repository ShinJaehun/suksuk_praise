import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["source", "status"]

    async copy() {
        const text = this.sourceTarget.textContent.trim()

        if (await this.copyWithClipboardApi(text) || this.copyWithTextareaFallback(text)) {
            this.showStatus("복사했습니다.")
            return
        }

        this.showStatus("복사하지 못했습니다. 주소를 직접 선택해 주세요.")
    }

    async copyWithClipboardApi(text) {
        if (!window.isSecureContext || !navigator.clipboard?.writeText) return false

        try {
            await navigator.clipboard.writeText(text)
            return true
        } catch (_error) {
            return false
        }
    }

    copyWithTextareaFallback(text) {
        const textarea = document.createElement("textarea")

        try {
            textarea.value = text
            textarea.setAttribute("readonly", "")
            textarea.style.position = "fixed"
            textarea.style.left = "-9999px"
            textarea.style.top = "0"

            document.body.appendChild(textarea)
            textarea.focus()
            textarea.select()

            return document.execCommand("copy")
        } catch (_error) {
            return false
        } finally {
            textarea.remove()
        }
    }

    showStatus(message) {
        if (!this.hasStatusTarget) return

        this.statusTarget.textContent = message
    }
}
