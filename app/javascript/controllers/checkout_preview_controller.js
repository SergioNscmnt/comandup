import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["coupon", "cep", "status", "discount", "fee", "total", "distance"]
  static values = { url: String, orderType: String }

  connect() {
    this.refresh()
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refresh(), 280)
  }

  async refresh() {
    const orderType = this.currentOrderType()
    const cep = this.cepValue()

    if (orderType === "delivery" && cep.length !== 8) {
      this.setStatus("Informe um CEP válido para calcular frete e total final do delivery.", true)
      this.setMoney(this.discountTarget, 0)
      this.setMoney(this.feeTarget, 0)
      this.setMoney(this.totalTarget, this.currentSubtotalCents())
      if (this.hasDistanceTarget) this.distanceTarget.textContent = "-"
      return
    }

    const params = new URLSearchParams()
    params.set("order_type", orderType)
    params.set("coupon_code", this.couponValue())
    if (cep.length === 8) params.set("delivery_cep", cep)

    try {
      const response = await fetch(`${this.urlValue}?${params.toString()}`)
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || "Não foi possível atualizar os valores.")

      this.setMoney(this.discountTarget, data.discount_cents || 0)
      this.setMoney(this.feeTarget, data.delivery_fee_cents || 0)
      this.setMoney(this.totalTarget, data.total_cents || 0)

      if (this.hasDistanceTarget) {
        const distance = Number(data.delivery_distance_km || 0)
        this.distanceTarget.textContent = distance > 0 ? `${distance.toFixed(2)} km` : "-"
      }

      if (data.promotion_applied) {
        this.setStatus(`Cupom aplicado: ${data.promotion_name}.`, false)
      } else if (data.free_shipping) {
        this.setStatus("Entrega com taxa zero pelo valor do pedido.", false)
      } else if (orderType === "delivery" && Number(data.minimum_delivery_order_cents || 0) > 0) {
        const missing = Math.max(Number(data.minimum_delivery_order_cents) - Number(data.subtotal_cents || 0), 0)
        this.setStatus(`Faltam ${this.money(missing)} para liberar taxa zero no delivery.`, false)
      } else {
        this.setStatus("Resumo atualizado conforme regras de cupom e frete.", false)
      }
    } catch (error) {
      this.setStatus(error.message, true)
    }
  }

  couponValue() {
    return this.hasCouponTarget ? this.couponTarget.value.trim() : ""
  }

  cepValue() {
    if (!this.hasCepTarget) return ""
    return this.cepTarget.value.replace(/\D/g, "")
  }

  currentOrderType() {
    if (this.orderTypeValue) return this.orderTypeValue

    const checked = this.element.querySelector("input[name='order_type']:checked")
    return checked ? checked.value : "pickup"
  }

  setMoney(target, cents) {
    target.textContent = this.money(cents)
  }

  currentSubtotalCents() {
    const text = this.element.querySelector("[data-viacep-subtotal-cents-value]")?.dataset?.viacepSubtotalCentsValue
    const value = Number(text || 0)
    return Number.isFinite(value) ? value : 0
  }

  setStatus(message, error) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message || ""
    this.statusTarget.classList.toggle("text-danger", !!error)
    this.statusTarget.classList.toggle("text-secondary", !error)
  }

  money(cents) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(Number(cents || 0) / 100)
  }
}
