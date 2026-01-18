import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['star', 'input']
  static values = { value: Number }

  connect () {
    this.updateStars()
  }

  select (event) {
    const value = parseInt(event.currentTarget.dataset.value, 10)
    this.valueValue = value
    this.inputTarget.value = value
    this.updateStars()
  }

  updateStars () {
    this.starTargets.forEach((star, index) => {
      const starSpan = star.querySelector('.star')
      const isFilled = index < this.valueValue
      starSpan.classList.toggle('filled', isFilled)
      starSpan.style.color = isFilled ? '#ffc107' : '#ddd'
    })
  }
}
