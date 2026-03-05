import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tip", "progressFill", "cta"]
  static values = {
    tips: Array,
    progress: Number,
    cartTotal: Number
  }

  connect() {
    this.tipIndex = 0
    this.renderTip()
    this.animateProgress()
    this.highlightCta()
    this.startRotation()
  }

  disconnect() {
    this.stopRotation()
  }

  startRotation() {
    if (this.tipsValue.length <= 1) return

    this.rotationTimer = setInterval(() => {
      this.tipIndex = (this.tipIndex + 1) % this.tipsValue.length
      this.renderTip()
    }, 3500)
  }

  stopRotation() {
    if (!this.rotationTimer) return

    clearInterval(this.rotationTimer)
    this.rotationTimer = null
  }

  renderTip() {
    if (!this.hasTipTarget || this.tipsValue.length === 0) return

    this.tipTarget.classList.remove("is-visible")
    requestAnimationFrame(() => {
      this.tipTarget.textContent = this.tipsValue[this.tipIndex]
      this.tipTarget.classList.add("is-visible")
    })
  }

  animateProgress() {
    if (!this.hasProgressFillTarget) return
    this.progressFillTarget.style.width = `${this.progressValue}%`
  }

  highlightCta() {
    if (!this.hasCtaTarget || this.cartTotalValue <= 0) return
    this.ctaTarget.classList.add("is-pulsing")
  }
}
