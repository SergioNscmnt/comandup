import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    const timeout = this.hasTimeoutValue ? this.timeoutValue : 2200
    this.timer = setTimeout(() => this.remove(), timeout)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  remove() {
    this.element.remove()
  }
}
