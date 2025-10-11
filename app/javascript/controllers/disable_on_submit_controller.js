import { Controller } from "@hotwired/stimulus"

// export default class extends Controller {
//     connect() {
//         this.onSubmit = this.onSubmit.bind(this)
//         this.element.addEventListener("submit", this.onSubmit)
//         document.addEventListener("turbo:submit-end", () => { this.enable() })
//     }
//     disconnect() {
//         this.element.removeEventListener("submit", this.onSubmit)
//     }
//     onSubmit() {
//         this.element.querySelectorAll("button, input[type=submit]").forEach(el => {
//             el.disabled = true
//             el.classList.add("opacity-60", "cursor-not-allowed", "pointer-events-none")
//         })
//     }
//     enable() {
//         this.element.querySelectorAll("button, input[type=submit]").forEach(el => {
//             el.disabled = false
//             el.classList.remove("opacity-60", "cursor-not-allowed", "pointer-events-none")
//         })
//     }
// }

export default class extends Controller {
    onSubmit() { this.setBusy(true) }
    enable() { this.setBusy(false) }

    setBusy(isBusy) {
        // 폼 자체에 busy 표기
        this.element.setAttribute("aria-busy", isBusy ? "true" : "false")

        // 제출 버튼/submit input 비활성 + 시각적 피드백 + 접근성 속성
        this.element.querySelectorAll("button, input[type=submit]").forEach(el => {
            el.disabled = isBusy
            el.setAttribute("aria-disabled", isBusy ? "true" : "false")
            el.classList.toggle("opacity-60", isBusy)
            el.classList.toggle("cursor-not-allowed", isBusy)
            el.classList.toggle("pointer-events-none", isBusy)
        })
    }
}