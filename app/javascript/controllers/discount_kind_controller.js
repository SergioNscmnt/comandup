import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kind", "percentageGroup", "fixedValueGroup"]

  connect() {
    this.sync()
  }

  sync() {
    const kind = this.currentKind()
    if (!kind) return

    if (this.hasPercentageGroupTarget) this.percentageGroupTarget.hidden = kind !== "percentage"
    if (this.hasFixedValueGroupTarget) this.fixedValueGroupTarget.hidden = kind !== "fixed_value"
  }

  currentKind() {
    const checked = this.kindTargets.find((input) => input.checked)
    return checked ? checked.value : null
  }
}
