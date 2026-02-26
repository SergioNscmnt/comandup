import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidden = !this.menuTarget.hidden
  }

  hideOnOutsideClick(event) {
    if (!this.hasMenuTarget) return
    if (this.element.contains(event.target)) return

    this.menuTarget.hidden = true
  }
}
