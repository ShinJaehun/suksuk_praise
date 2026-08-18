import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.inFlight = false
    this.handleVisibilityChange = () => {
      if (document.visibilityState === "visible") this.reconcile()
    }
    this.handleOnline = () => this.reconcile()

    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    window.addEventListener("online", this.handleOnline)
    this.interval = window.setInterval(() => {
      if (document.visibilityState === "visible") this.reconcile()
    }, 60_000)

    this.reconcile()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    window.removeEventListener("online", this.handleOnline)
    window.clearInterval(this.interval)
  }

  async reconcile() {
    if (this.inFlight || !this.hasUrlValue) return

    this.inFlight = true

    try {
      const response = await fetch(this.urlValue, {
        credentials: "same-origin",
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const state = await response.json()
      if (!Array.isArray(state.pending_coupon_request_student_ids) ||
          !Array.isArray(state.unread_student_message_student_ids)) return

      this.applyState(state)
    } catch (_error) {
      // Keep the current alerts until a later reconciliation succeeds.
    } finally {
      this.inFlight = false
    }
  }

  applyState(state) {
    const pendingCouponIds = new Set(state.pending_coupon_request_student_ids.map(String))
    const unreadMessageIds = new Set(state.unread_student_message_student_ids.map(String))

    document.querySelectorAll("[data-student-card-alert-reconciliation-student-id]").forEach((wrapper) => {
      const studentId = wrapper.dataset.studentCardAlertReconciliationStudentId
      wrapper.querySelector('[data-alert-kind="coupon"]')
        ?.classList.toggle("hidden", !pendingCouponIds.has(studentId))
      wrapper.querySelector('[data-alert-kind="message"]')
        ?.classList.toggle("hidden", !unreadMessageIds.has(studentId))
    })
  }
}
