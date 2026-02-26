import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    if (event) event.preventDefault()

    const frame = this.element.closest("turbo-frame")
    if (frame) frame.innerHTML = ""
  }

  closeIfBackdrop(event) {
    if (event.target === this.element) this.close(event)
  }
}
