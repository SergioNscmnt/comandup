import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cep", "street", "number", "neighborhood", "complement", "address", "status", "distance", "fee", "total"]
  static values = { subtotalCents: Number }

  connect() {
    this.maskCep()
    this.compose()
  }

  maskCep() {
    if (!this.hasCepTarget) return

    const digits = this.cepTarget.value.replace(/\D/g, "").slice(0, 8)
    this.cepTarget.value = this.formatCep(digits)
  }

  async search() {
    const cep = this.cepTarget.value.replace(/\D/g, "")

    if (cep.length === 0) {
      this.clearStatus()
      this.clearQuote()
      return
    }

    if (cep.length !== 8) {
      this.setStatus("CEP inválido. Use 8 dígitos.", true)
      this.clearQuote()
      return
    }

    this.setStatus("Buscando endereço...")

    try {
      const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`)
      if (!response.ok) throw new Error("request_failed")

      const data = await response.json()
      if (data.erro) {
        this.setStatus("CEP não encontrado.", true)
        return
      }

      this.streetTarget.value = data.logradouro || ""
      this.neighborhoodTarget.value = data.bairro || ""
      this.cepTarget.value = this.formatCep(cep)
      this.compose()
    } catch (_error) {
      this.setStatus("Não foi possível consultar o CEP agora.", true)
      this.clearQuote()
      return
    }

    try {
      await this.loadQuote(cep)
      if (this.lastFeeCents === 0) {
        this.setStatus("Pedido mínimo atingido: entrega com taxa zero.")
      } else {
        this.setStatus("Rua e bairro preenchidos. Informe número e complemento.")
      }
    } catch (error) {
      this.setStatus(error.message || "Endereço encontrado, mas não foi possível calcular a taxa agora.", true)
      this.clearQuote()
    }
  }

  compose() {
    const street = this.hasStreetTarget ? this.streetTarget.value.trim() : ""
    const number = this.hasNumberTarget ? this.numberTarget.value.trim() : ""
    const neighborhood = this.hasNeighborhoodTarget ? this.neighborhoodTarget.value.trim() : ""
    const complement = this.hasComplementTarget ? this.complementTarget.value.trim() : ""

    const parts = []
    if (street) parts.push(street)
    if (number) parts.push(`Nº ${number}`)
    if (neighborhood) parts.push(neighborhood)
    if (complement) parts.push(complement)

    if (this.hasAddressTarget) {
      this.addressTarget.value = parts.join(", ")
    }
  }

  setStatus(message, error = false) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-danger", error)
    this.statusTarget.classList.toggle("text-secondary", !error)
  }

  clearStatus() {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = ""
    this.statusTarget.classList.remove("text-danger")
    this.statusTarget.classList.add("text-secondary")
  }

  async loadQuote(cep) {
    const response = await fetch(`/cart/delivery_quote?cep=${encodeURIComponent(cep)}&subtotal_cents=${encodeURIComponent(this.subtotalCentsValue)}`)
    const data = await response.json()
    if (!response.ok) throw new Error(data.error || "Não foi possível calcular a taxa de entrega.")

    this.setQuote(data)
  }

  setQuote(quote) {
    this.lastFeeCents = Number(quote.fee_cents || 0)

    if (this.hasDistanceTarget) {
      const distance = Number(quote.distance_km || 0)
      this.distanceTarget.textContent = `${distance.toFixed(2)} km`
    }

    if (this.hasFeeTarget) {
      this.feeTarget.textContent = this.money(this.lastFeeCents)
    }

    if (this.hasTotalTarget) {
      const totalCents = this.subtotalCentsValue + this.lastFeeCents
      this.totalTarget.textContent = this.money(totalCents)
    }
  }

  clearQuote() {
    this.lastFeeCents = 0
    if (this.hasDistanceTarget) this.distanceTarget.textContent = "-"
    if (this.hasFeeTarget) this.feeTarget.textContent = this.money(0)
    if (this.hasTotalTarget) this.totalTarget.textContent = this.money(this.subtotalCentsValue)
  }

  money(cents) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(cents / 100)
  }

  formatCep(cep) {
    if (cep.length <= 5) return cep
    return `${cep.slice(0, 5)}-${cep.slice(5)}`
  }
}
