import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button", "label", "plusIcon", "dashIcon"]
  static values = {
    openLabel: String,
    closedLabel: String,
    scrollOnOpen: Boolean
  }

  connect() {
    this.sync()
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.panelTarget.removeAttribute("hidden")

    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")
    if (this.hasPlusIconTarget) this.plusIconTarget.hidden = true
    if (this.hasDashIconTarget) this.dashIconTarget.hidden = false
    this.updateLabel(true)

    if (this.scrollOnOpenValue) {
      this.panelTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  close() {
    this.panelTarget.setAttribute("hidden", "hidden")

    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    if (this.hasPlusIconTarget) this.plusIconTarget.hidden = false
    if (this.hasDashIconTarget) this.dashIconTarget.hidden = true
    this.updateLabel(false)
  }

  sync() {
    if (!this.hasPanelTarget) return

    if (this.isOpen()) {
      this.open()
    } else {
      this.close()
    }
  }

  isOpen() {
    return this.hasPanelTarget && !this.panelTarget.hasAttribute("hidden")
  }

  updateLabel(open) {
    if (!this.hasLabelTarget) return

    if (open && this.hasOpenLabelValue) {
      this.labelTarget.textContent = this.openLabelValue
      return
    }

    if (!open && this.hasClosedLabelValue) {
      this.labelTarget.textContent = this.closedLabelValue
    }
  }
}
