import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        // 이 컨트롤러는 "form" 요소에 붙는다고 가정
        this.onSubmit = this.onSubmit.bind(this)
        this.onTurboSubmitEnd = this.onTurboSubmitEnd.bind(this)

        this.element.addEventListener("submit", this.onSubmit)
        document.addEventListener("turbo:submit-end", this.onTurboSubmitEnd)
    }

    disconnect() {
        this.element.removeEventListener("submit", this.onSubmit)
        document.removeEventListener("turbo:submit-end", this.onTurboSubmitEnd)
    }

    onSubmit() {
        this.setBusy(true)
    }

    // turbo:submit-end 전역 이벤트에서, 이 폼에 대한 응답일 때만 busy 해제
    onTurboSubmitEnd(event) {
        const form = event.target
        if (form === this.element) {
            this.setBusy(false)
        }
    }

    setBusy(isBusy) {
        this.element.setAttribute("aria-busy", isBusy ? "true" : "false")

        this.element
            .querySelectorAll("button, input[type=submit]")
            .forEach((el) => {
                el.disabled = isBusy
                el.setAttribute("aria-disabled", isBusy ? "true" : "false")
                el.classList.toggle("opacity-60", isBusy)
                el.classList.toggle("cursor-not-allowed", isBusy)
                el.classList.toggle("pointer-events-none", isBusy)
            })
    }
}