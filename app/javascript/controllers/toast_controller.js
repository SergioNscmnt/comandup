import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timer"]
  static values = { timeout: Number }

  connect() {
    const timeout = this.hasTimeoutValue ? this.timeoutValue : 4200
    if (this.hasTimerTarget) {
      this.timerTarget.style.animationDuration = `${timeout}ms`
    }
    this.timer = setTimeout(() => this.remove(), timeout)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  close(event) {
    event.preventDefault()
    this.remove()
  }

  remove() {
    this.element.classList.add("is-closing")
    setTimeout(() => this.element.remove(), 160)
  }
}
