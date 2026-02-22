import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "label", "plusIcon", "dashIcon"]

  toggle() {
    const opening = this.panelTarget.hasAttribute("hidden")

    if (opening) {
      this.panelTarget.removeAttribute("hidden")
      this.labelTarget.textContent = "Observação"
      this.plusIconTarget.hidden = true
      this.dashIconTarget.hidden = false
    } else {
      this.panelTarget.setAttribute("hidden", "hidden")
      this.labelTarget.textContent = "Observação"
      this.plusIconTarget.hidden = false
      this.dashIconTarget.hidden = true
    }
  }
}
