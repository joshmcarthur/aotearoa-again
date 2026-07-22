import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["colour", "handle", "range"]

  connect() {
    this.setPosition(50)
  }

  slide(event) {
    this.setPosition(Number(event.target.value))
  }

  setPosition(percent) {
    const clamped = Math.min(100, Math.max(0, percent))
    if (this.hasColourTarget) {
      this.colourTarget.style.clipPath = `inset(0 ${100 - clamped}% 0 0)`
    }
    if (this.hasHandleTarget) {
      this.handleTarget.style.left = `${clamped}%`
    }
    if (this.hasRangeTarget) {
      this.rangeTarget.value = clamped
    }
  }
}
