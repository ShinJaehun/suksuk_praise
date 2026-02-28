import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: String,
    title: String,
    imageUrl: String,
    type: String
  }

  connect() {
    this.targetCard = null

    this.titleText =
      this.titleValue ||
      this.extractTitle(this.targetCard) ||
      "당첨 쿠폰"
    this.imageSrc =
      this.imageUrlValue ||
      this.targetCard?.querySelector("img")?.getAttribute("src") ||
      ""

    this.resolveTargetCardWithRetry()

    if (this.animationType() === "use") {
      this.showUseSequence()
    } else {
      this.showDrawSequence()
    }
  }

  disconnect() {
    clearTimeout(this.highlightRetryTimer)
    this.teardown()
  }

  resolveTargetCardWithRetry(tries = 10) {
    if (!this.hasIdValue) return
    this.targetCard = document.getElementById(this.idValue)
    if (this.targetCard) return
    if (tries <= 0) return
    this.highlightRetryTimer = setTimeout(() => this.resolveTargetCardWithRetry(tries - 1), 80)
  }

  applyCardHighlight() {
    this.targetCard?.classList.add("ring-2", "ring-amber-400", "bg-amber-50")
  }

  showDrawSequence() {
    this.timers = []
    this.buildOverlay()
    this.showOverlay()
    this.phaseOne()

    this.timers.push(setTimeout(() => this.phaseTwo(), 900))
    this.timers.push(setTimeout(() => {
      this.revealCard("축하합니다")
      this.emitParticles()
    }, 1700))
  }

  showUseSequence() {
    this.timers = []
    this.buildOverlay()
    this.showOverlay()
    if (this.labelEl) this.labelEl.textContent = "쿠폰 사용 완료"
    this.revealCard()
    if (this.centerEl) this.centerEl.classList.add("animate-[fadeIn_.25s_ease-out]")
    this.emitFireworks()
  }

  phaseOne() {
    if (!this.labelEl) return
    this.labelEl.textContent = "뽑는 중"
  }

  phaseTwo() {
    if (!this.labelEl) return
    this.labelEl.textContent = "두근두근"
  }

  revealCard(message = null) {
    if (!this.centerEl) return
    if (message && this.labelEl) this.labelEl.textContent = message
    this.centerEl.classList.remove("hidden")
    this.nameEl.textContent = this.titleText

    if (this.imageSrc && this.imageEl && this.imageWrapEl) {
      this.imageEl.setAttribute("src", this.imageSrc)
      this.imageWrapEl.classList.remove("hidden")
    } else if (this.imageWrapEl) {
      this.imageWrapEl.classList.add("hidden")
    }
  }

  showOverlay() {
    this.overlay.classList.remove("hidden")
    this.overlay.setAttribute("aria-hidden", "false")
  }

  close() {
    this.resolveTargetCardWithRetry()
    this.hideOverlay()

    // use/draw 모두 오버레이가 닫힌 뒤 카드 하이라이트를 적용한다.
    if (!this.targetCard) {
      this.element.remove()
      return
    }

    this.applyCardHighlight()

    clearTimeout(this.highlightCleanupTimer)
    this.highlightCleanupTimer = setTimeout(() => {
      this.targetCard?.classList.remove("ring-2", "ring-amber-400", "bg-amber-50")
      this.element.remove()
    }, 1000)
  }

  hideOverlay() {
    if (!this.overlay) return
    this.overlay.classList.add("hidden")
    this.overlay.setAttribute("aria-hidden", "true")
    this.overlay.removeEventListener("click", this.onOverlayClick)
    this.overlay.remove()
    this.overlay = null
  }

  buildOverlay() {
    const existingOverlay = document.getElementById("coupon_animation_overlay")
    if (existingOverlay) existingOverlay.remove()

    const wrapper = document.createElement("div")
    wrapper.className = "hidden fixed inset-0 z-[9999] flex items-center justify-center bg-slate-950/60 backdrop-blur-[1px]"
    wrapper.id = "coupon_animation_overlay"
    wrapper.setAttribute("aria-hidden", "true")

    wrapper.innerHTML = `
      <div class="relative w-[320px] max-w-[90vw] rounded-2xl border border-amber-200/80 bg-white px-6 py-6 text-center shadow-2xl">
        <p class="text-sm font-semibold tracking-wide text-slate-500">쿠폰 추첨</p>
        <p class="mt-2 text-xl font-extrabold text-amber-600 animate-pulse" data-coupon-animation-role="label">뽑는 중...</p>

        <div class="mt-4 hidden" data-coupon-animation-role="center">
          <div class="mx-auto mb-3 hidden h-40 w-40 overflow-hidden rounded-xl border border-slate-200 bg-slate-50" data-coupon-animation-role="imageWrap">
            <img alt="당첨 쿠폰" class="h-full w-full object-cover" data-coupon-animation-role="image" />
          </div>
          <p class="text-lg font-bold text-slate-900" data-coupon-animation-role="name"></p>
          <p class="mt-2 text-xs text-slate-500">화면을 클릭하면 닫힙니다</p>
        </div>
      </div>
    `

    document.body.appendChild(wrapper)
    this.overlay = wrapper
    this.labelEl = wrapper.querySelector("[data-coupon-animation-role='label']")
    this.centerEl = wrapper.querySelector("[data-coupon-animation-role='center']")
    this.imageWrapEl = wrapper.querySelector("[data-coupon-animation-role='imageWrap']")
    this.imageEl = wrapper.querySelector("[data-coupon-animation-role='image']")
    this.nameEl = wrapper.querySelector("[data-coupon-animation-role='name']")

    this.onOverlayClick = () => this.close()
    this.overlay.addEventListener("click", this.onOverlayClick)
  }

  emitParticles() {
    if (!this.overlay) return
    const box = this.overlay.querySelector(".relative")
    if (!box) return

    const holder = document.createElement("div")
    holder.className = "pointer-events-none absolute inset-0 overflow-hidden"
    box.appendChild(holder)

    for (let i = 0; i < 18; i += 1) {
      const dot = document.createElement("span")
      const size = 6 + Math.floor(Math.random() * 6)
      const left = 10 + Math.floor(Math.random() * 80)
      const delay = (Math.random() * 250).toFixed(0)
      const colors = ["#f59e0b", "#22c55e", "#3b82f6", "#ef4444"]

      dot.className = "absolute rounded-full animate-ping"
      dot.style.width = `${size}px`
      dot.style.height = `${size}px`
      dot.style.left = `${left}%`
      dot.style.top = "52%"
      dot.style.backgroundColor = colors[i % colors.length]
      dot.style.animationDuration = "650ms"
      dot.style.animationDelay = `${delay}ms`
      holder.appendChild(dot)
    }

    this.timers.push(setTimeout(() => holder.remove(), 1200))
  }

  emitFireworks() {
    if (!this.overlay) return
    const box = this.overlay.querySelector(".relative")
    if (!box) return

    const holder = document.createElement("div")
    holder.className = "pointer-events-none absolute inset-0 overflow-hidden"
    box.appendChild(holder)

    const bursts = [
      { x: 22, y: 34 },
      { x: 50, y: 26 },
      { x: 78, y: 36 }
    ]
    const colors = ["#f59e0b", "#ef4444", "#22c55e", "#3b82f6", "#eab308", "#f97316"]

    bursts.forEach((origin, burstIdx) => {
      for (let i = 0; i < 16; i += 1) {
        const p = document.createElement("span")
        const angle = (Math.PI * 2 * i) / 16
        const distance = 28 + Math.random() * 34
        const dx = Math.cos(angle) * distance
        const dy = Math.sin(angle) * distance
        const size = 4 + Math.floor(Math.random() * 4)

        p.className = "absolute rounded-full"
        p.style.left = `${origin.x}%`
        p.style.top = `${origin.y}%`
        p.style.width = `${size}px`
        p.style.height = `${size}px`
        p.style.backgroundColor = colors[(i + burstIdx) % colors.length]
        p.style.opacity = "0"
        p.style.transform = "translate(-50%, -50%) scale(0.6)"
        p.style.transition = "transform 760ms cubic-bezier(.2,.8,.2,1), opacity 760ms ease-out"
        holder.appendChild(p)

        const delay = burstIdx * 120 + Math.floor(Math.random() * 90)
        this.timers.push(setTimeout(() => {
          p.style.opacity = "1"
          p.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) scale(1)`
        }, delay))
        this.timers.push(setTimeout(() => {
          p.style.opacity = "0"
        }, delay + 430))
      }
    })

    this.timers.push(setTimeout(() => holder.remove(), 1300))
  }

  extractTitle(card) {
    if (!card) return null
    const candidates = card.querySelectorAll(".font-semibold")
    for (const el of candidates) {
      const text = el.textContent?.trim()
      if (text) return text
    }
    return null
  }

  animationType() {
    return this.hasTypeValue ? this.typeValue : "draw"
  }

  teardown() {
    clearTimeout(this.highlightRetryTimer)
    clearTimeout(this.highlightCleanupTimer)
    if (this.timers) this.timers.forEach((id) => clearTimeout(id))
    this.timers = []
    this.targetCard?.classList.remove("ring-2", "ring-amber-400", "bg-amber-50")

    if (this.overlay) {
      this.overlay.removeEventListener("click", this.onOverlayClick)
      this.overlay.remove()
      this.overlay = null
    }
  }
}
