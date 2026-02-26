import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cep", "street", "number", "neighborhood", "complement", "address", "status"]

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
    if (!this.hasCepTarget) return

    const cep = this.cepTarget.value.replace(/\D/g, "")

    if (cep.length === 0) {
      this.clearStatus()
      return
    }

    if (cep.length !== 8) {
      this.setStatus("CEP inválido. Use 8 dígitos.", true)
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

      if (this.hasStreetTarget) this.streetTarget.value = data.logradouro || ""
      if (this.hasNeighborhoodTarget) this.neighborhoodTarget.value = data.bairro || ""

      this.cepTarget.value = this.formatCep(cep)
      this.compose()
      this.setStatus("Endereço preenchido com sucesso.")
    } catch (_error) {
      this.setStatus("Não foi possível consultar o CEP agora.", true)
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

    if (this.hasAddressTarget) this.addressTarget.value = parts.join(", ")
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

  formatCep(cep) {
    if (cep.length <= 5) return cep
    return `${cep.slice(0, 5)}-${cep.slice(5)}`
  }
}
