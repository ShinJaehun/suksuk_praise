import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["progress"]

  connect() {
    this.reset = this.reset.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)

    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
    document.addEventListener("turbo:fetch-request-error", this.reset)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    document.removeEventListener("turbo:fetch-request-error", this.reset)
    this.clearTimers()
  }

  close() {
    //this.element.innerHTML = ""
    //this.element.className = "modal-default"
    this.element.closest("turbo-frame#modal").innerHTML = "";
  }

  clear(event) {
    event.preventDefault()
    const frame = document.getElementById("modal")
    if (frame) frame.innerHTML = ""
  }

  //showProgress(event){
  //if(this.hasProgressTarget){
  //this.progressTarget.classList.remove("hidden");
  //this.progressTarget.querySelector(".bar").style.width="70%";
  //}
  //}
  showProgress(event) {
    this.element.setAttribute("aria-busy", "true")
    this.disabledElements = Array.from(
      this.element.querySelectorAll("button:not(:disabled), input[type=submit]:not(:disabled)")
    )
    this.disabledElements.forEach((element) => {
      element.disabled = true
    })
    this.readonlyElements = Array.from(
      this.element.querySelectorAll("input:not([type=submit]):not([readonly]), textarea:not([readonly])")
    )
    this.readonlyElements.forEach((element) => {
      element.readOnly = true
    })
    this.ariaDisabledElements = Array.from(
      this.element.querySelectorAll("select:not([aria-disabled=true]), a[href]:not([aria-disabled=true])")
    )
    this.ariaDisabledElements.forEach((element) => {
      element.setAttribute("aria-disabled", "true")
    })
    this.pointerDisabledElements = Array.from(
      this.element.querySelectorAll("select:not(.pointer-events-none), a[href]:not(.pointer-events-none)")
    )
    this.pointerDisabledElements.forEach((element) => {
      element.classList.add("pointer-events-none")
    })

    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove("hidden");
      // 0%에서 시작
      let progress = 0;
      let target = this.progressTarget.querySelector('.bar');
      let count = Number(document.querySelector('input[type=number]').value || 30);
      let step = 100 / count;
      target.style.width = "0%";
      // 진짜 생성과 동기화되는 건 아니지만, UX 개선용
      this.progressInterval = setInterval(() => {
        progress += step;
        if (progress >= 100) {
          progress = 100;
          clearInterval(this.progressInterval);
          this.progressInterval = null;
        }
        target.style.width = progress + "%";
      }, 100); // 0.1초마다 1명씩 처리된다고 가정
    }

    this.unlockTimeout = setTimeout(() => this.reset(), 300000)
  }

  onSubmitEnd(event) {
    if (this.element.contains(event.target)) {
      this.reset()
    }
  }

  reset() {
    this.clearTimers()
    this.element.removeAttribute("aria-busy")
    this.disabledElements?.forEach((element) => {
      element.disabled = false
    })
    this.disabledElements = []
    this.readonlyElements?.forEach((element) => {
      element.readOnly = false
    })
    this.readonlyElements = []
    this.ariaDisabledElements?.forEach((element) => {
      element.removeAttribute("aria-disabled")
    })
    this.ariaDisabledElements = []
    this.pointerDisabledElements?.forEach((element) => {
      element.classList.remove("pointer-events-none")
    })
    this.pointerDisabledElements = []

    if (this.hasProgressTarget) {
      this.progressTarget.classList.add("hidden")
    }
  }

  clearTimers() {
    clearInterval(this.progressInterval)
    clearTimeout(this.unlockTimeout)
    this.progressInterval = null
    this.unlockTimeout = null
  }
}
