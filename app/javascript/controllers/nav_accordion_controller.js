import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundSync = this.syncState.bind(this)
    window.addEventListener("resize", this.boundSync)
    this.syncState()
  }

  disconnect() {
    window.removeEventListener("resize", this.boundSync)
  }

  syncState() {
    if (window.matchMedia("(min-width: 992px)").matches) {
      this.element.setAttribute("open", "open")
    } else {
      this.element.removeAttribute("open")
    }
  }
}
