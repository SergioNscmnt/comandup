import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.fieldTargets.forEach((input) => this.applyMask(input))
  }

  mask(event) {
    this.applyMask(event.target)
  }

  applyMask(input) {
    const digits = input.value.replace(/\D/g, "")
    if (digits.length === 0) {
      input.value = ""
      return
    }

    const cents = Number.parseInt(digits, 10)
    const value = (cents / 100).toFixed(2)
    const [whole, decimal] = value.split(".")
    const wholeWithSeparator = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
    input.value = `${wholeWithSeparator},${decimal}`
  }
}
