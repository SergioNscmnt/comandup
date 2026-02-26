import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["currency", "radius", "integer"]

  connect() {
    this.currencyTargets.forEach((input) => this.applyCurrencyMask(input))
    this.radiusTargets.forEach((input) => this.applyRadiusMask(input))
    this.integerTargets.forEach((input) => this.applyIntegerMask(input))
  }

  maskCurrency(event) {
    this.applyCurrencyMask(event.target)
  }

  maskRadius(event) {
    this.applyRadiusMask(event.target)
  }

  maskInteger(event) {
    this.applyIntegerMask(event.target)
  }

  applyCurrencyMask(input) {
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

  applyRadiusMask(input) {
    const normalized = input.value.replace(/[^\d,]/g, "")
    if (normalized.length === 0) {
      input.value = ""
      return
    }

    const parts = normalized.split(",")
    const whole = parts[0].replace(/^0+(?=\d)/, "")
    const decimal = (parts[1] || "").slice(0, 2)
    input.value = decimal.length > 0 ? `${whole},${decimal}` : whole
  }

  applyIntegerMask(input) {
    input.value = input.value.replace(/\D/g, "")
  }
}
