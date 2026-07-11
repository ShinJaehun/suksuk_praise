import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.syncButtons()

    this.observer = new MutationObserver(() => this.syncButtons())
    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["hidden"]
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  submit(event) {
    const button = event.submitter || event.currentTarget.querySelector("[aria-controls]")
    const frame = this.frameFor(button)

    if (!frame) return

    if (!this.frameLoaded(frame)) {
      return
    }

    event.preventDefault()
    frame.hidden = !frame.hidden
    this.setExpanded(button, !frame.hidden)
  }

  frameFor(button) {
    if (!button) return null

    return document.getElementById(button.getAttribute("aria-controls"))
  }

  frameLoaded(frame) {
    return frame.children.length > 0 || frame.textContent.trim().length > 0
  }

  setExpanded(button, expanded) {
    if (!button) return

    button.setAttribute("aria-expanded", expanded.toString())
  }

  syncButtons() {
    this.element.querySelectorAll("button[aria-controls]").forEach((button) => {
      const frame = this.frameFor(button)
      const expanded = Boolean(frame && this.frameLoaded(frame) && !frame.hidden)

      this.setExpanded(button, expanded)
    })
  }
}
