import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["deliveryRadio", "addressSection", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasDeliveryRadioTarget || !this.hasAddressSectionTarget) return

    const isDelivery = this.deliveryRadioTarget.checked
    this.addressSectionTarget.hidden = !isDelivery

    this.fieldTargets.forEach((field) => {
      field.disabled = !isDelivery

      if (field.dataset.requiredWhenDelivery === "true") {
        field.required = isDelivery
      } else {
        field.required = false
      }
    })
  }
}
