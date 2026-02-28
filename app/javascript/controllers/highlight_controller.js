import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { id: String }

    disconnect() {
        if (this.retryTimer) clearTimeout(this.retryTimer)
    }

    connect() {
        if (!this.hasIdValue) {
            this.cleanup()
            return
        }
        this.tryHighlightWithRetry()
    }

    tryHighlightWithRetry(tries = 20) {
        // 오버레이가 떠있는 동안은 하이라이트를 지연시킨다.
        if (document.getElementById("coupon_animation_overlay")) {
            // 오버레이 대기 동안에는 재시도 횟수를 소모하지 않는다.
            this.retryTimer = setTimeout(() => this.tryHighlightWithRetry(tries), 80)
            return
        }

        const el = document.getElementById(this.idValue)
        if (el) {
            el.classList.add("ring-2", "ring-amber-400", "bg-amber-50")
            setTimeout(() => el.classList.remove("ring-2", "ring-amber-400", "bg-amber-50"), 1000)
            this.cleanup()
            return
        }

        if (tries <= 0) return this.cleanup()
        this.retryTimer = setTimeout(() => this.tryHighlightWithRetry(tries - 1), 80)
    }

    cleanup() {
        // effects 컨테이너 내 trigger 노드 누적 방지
        this.element.remove()
    }
}
