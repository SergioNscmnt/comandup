import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "prevButton", "nextButton"]

  connect() {
    if (!this.hasTrackTarget) return

    this.handleScroll = this.updateControls.bind(this)
    this.handleResize = this.updateControls.bind(this)

    this.trackTarget.addEventListener("scroll", this.handleScroll, { passive: true })
    window.addEventListener("resize", this.handleResize)

    this.updateControls()
  }

  disconnect() {
    if (this.hasTrackTarget && this.handleScroll) {
      this.trackTarget.removeEventListener("scroll", this.handleScroll)
    }
    if (this.handleResize) {
      window.removeEventListener("resize", this.handleResize)
    }
  }

  prev() {
    this.scrollByStep(-1)
  }

  next() {
    this.scrollByStep(1)
  }

  scrollByStep(direction) {
    if (!this.hasTrackTarget) return

    const firstItem = this.trackTarget.firstElementChild
    const itemWidth = firstItem ? firstItem.getBoundingClientRect().width : 120
    const step = Math.max(itemWidth * 3, this.trackTarget.clientWidth * 0.75)

    this.trackTarget.scrollBy({
      left: direction * step,
      behavior: "smooth"
    })
  }

  updateControls() {
    if (!this.hasTrackTarget) return

    const maxScrollLeft = Math.max(0, this.trackTarget.scrollWidth - this.trackTarget.clientWidth)
    const current = this.trackTarget.scrollLeft

    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.disabled = current <= 1
    }

    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = current >= (maxScrollLeft - 1)
    }
  }
}
