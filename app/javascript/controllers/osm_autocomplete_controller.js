import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    endpoint: { type: String, default: "/geo/suggestions" },
    field: String,
    minChars: { type: Number, default: 3 }
  }

  connect() {
    this.abortController = null
    this.debouncedFetch = this.debounce(() => this.fetchSuggestions(), 250)
    this.listElement = this.ensureDatalist()
  }

  disconnect() {
    if (this.abortController) this.abortController.abort()
  }

  search() {
    this.debouncedFetch()
  }

  async fetchSuggestions() {
    if (!this.hasFieldValue) return

    const query = this.element.value.trim()
    if (query.length < this.minCharsValue) {
      this.renderSuggestions([])
      return
    }

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    const url = new URL(this.endpointValue, window.location.origin)
    url.searchParams.set("field", this.fieldValue)
    url.searchParams.set("q", query)

    try {
      const response = await fetch(url.toString(), {
        signal: this.abortController.signal,
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error("request_failed")

      const data = await response.json()
      this.renderSuggestions(data.suggestions || [])
    } catch (error) {
      if (error.name === "AbortError") return
      this.renderSuggestions([])
    }
  }

  renderSuggestions(suggestions) {
    if (!this.listElement) return

    this.listElement.innerHTML = ""
    suggestions.forEach((suggestion) => {
      const option = document.createElement("option")
      option.value = suggestion.value
      if (suggestion.label) option.label = suggestion.label
      this.listElement.appendChild(option)
    })
  }

  ensureDatalist() {
    const field = this.hasFieldValue ? this.fieldValue : "field"
    const randomId = Math.random().toString(36).slice(2, 9)
    const listId = `osm-${field}-list-${randomId}`

    const datalist = document.createElement("datalist")
    datalist.id = listId
    this.element.insertAdjacentElement("afterend", datalist)
    this.element.setAttribute("list", listId)

    return datalist
  }

  debounce(callback, delay) {
    let timer = null
    return (...args) => {
      if (timer) clearTimeout(timer)
      timer = setTimeout(() => callback(...args), delay)
    }
  }
}
