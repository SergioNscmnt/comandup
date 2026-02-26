import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "track"]
  static values = { url: String }

  connect() {
    this.draggingId = null
    this.draggingElement = null
    this.persistTimeout = null
  }

  disconnect() {
    if (this.persistTimeout) {
      clearTimeout(this.persistTimeout)
      this.persistTimeout = null
    }
  }

  dragStart(event) {
    const card = event.currentTarget
    this.draggingId = card.dataset.categoryId
    this.draggingElement = card
    card.classList.add("is-dragging")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", this.draggingId)
    }
  }

  dragOver(event) {
    event.preventDefault()

    const dragging = this.draggingElement
    if (!dragging || !this.hasTrackTarget) return

    const afterElement = this.dragAfterElement(event.clientX)
    if (!afterElement) {
      this.trackTarget.appendChild(dragging)
    } else {
      this.trackTarget.insertBefore(dragging, afterElement)
    }
  }

  drop(event) {
    event.preventDefault()
    this.persistOrder()
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("is-dragging")
    this.persistOrder()
    this.draggingId = null
    this.draggingElement = null
  }

  dragAfterElement(pointerX) {
    const items = this.itemTargets.filter((item) => item !== this.draggingElement)
    if (items.length === 0) return null

    let closest = null
    let closestOffset = Number.NEGATIVE_INFINITY

    items.forEach((item) => {
      const box = item.getBoundingClientRect()
      const offset = pointerX - (box.left + box.width / 2)

      if (offset < 0 && offset > closestOffset) {
        closestOffset = offset
        closest = item
      }
    })

    return closest
  }

  persistOrder() {
    if (!this.hasUrlValue) return

    const categoryIds = this.itemTargets.map((item) => Number.parseInt(item.dataset.categoryId, 10)).filter((id) => Number.isInteger(id))
    if (categoryIds.length === 0) return

    if (this.persistTimeout) clearTimeout(this.persistTimeout)

    this.persistTimeout = setTimeout(() => {
      fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({ category_ids: categoryIds })
      })
    }, 120)
  }

  csrfToken() {
    const token = document.querySelector("meta[name='csrf-token']")
    return token ? token.content : ""
  }
}
