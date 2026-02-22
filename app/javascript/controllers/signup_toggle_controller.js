import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button", "label", "plusIcon", "dashIcon"]

  toggle() {
    const opening = this.panelTarget.hasAttribute("hidden")

    if (opening) {
      this.panelTarget.removeAttribute("hidden")
      this.buttonTarget.setAttribute("aria-expanded", "true")
      this.labelTarget.textContent = "Observação"
      this.plusIconTarget.hidden = true
      this.dashIconTarget.hidden = false
      this.panelTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    } else {
      this.panelTarget.setAttribute("hidden", "hidden")
      this.buttonTarget.setAttribute("aria-expanded", "false")
      this.labelTarget.textContent = "Observação"
      this.plusIconTarget.hidden = false
      this.dashIconTarget.hidden = true
    }
  }
}
