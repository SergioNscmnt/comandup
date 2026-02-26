import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "showIcon", "hideIcon"]
  static values = {
    visibleLabel: { type: String, default: "Ocultar senha" },
    hiddenLabel: { type: String, default: "Mostrar senha" }
  }

  connect() {
    this.sync()
  }

  toggle() {
    if (!this.hasInputTarget) return

    this.inputTarget.type = this.inputTarget.type === "password" ? "text" : "password"
    this.sync()
  }

  sync() {
    if (!this.hasInputTarget) return

    const visible = this.inputTarget.type === "text"

    if (this.hasShowIconTarget) this.showIconTarget.hidden = visible
    if (this.hasHideIconTarget) this.hideIconTarget.hidden = !visible

    if (this.hasButtonTarget) {
      const label = visible ? this.visibleLabelValue : this.hiddenLabelValue
      this.buttonTarget.setAttribute("aria-label", label)
      this.buttonTarget.setAttribute("title", label)
    }
  }
}
