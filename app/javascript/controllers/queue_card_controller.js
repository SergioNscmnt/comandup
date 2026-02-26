import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "details"]

  connect() {
    this.sync()
  }

  toggleDetails() {
    this.sync()
  }

  sync() {
    if (!this.hasItemsTarget || !this.hasDetailsTarget) return

    this.itemsTarget.hidden = this.detailsTarget.open
  }
}
