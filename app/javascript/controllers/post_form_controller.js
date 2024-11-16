import { Controller } from '@hotwired/stimulus'
import EditorJsContentLengthCalculator from 'utils/EditorJsContentLengthCalculator'

const MAX_SHORT_POST_LENGTH = 300

export default class extends Controller {
  static targets = ['titleAndSlug', 'postLength']

  updatePostLength ({ detail: { data } }) {
    const length = this.calculatePostLength(data)
    this.updatePostLengthCounter(length)

    if (this.titleOrSlugPresent()) { return this.unhide() }

    length < MAX_SHORT_POST_LENGTH ? this.hide() : this.unhide()
  }

  calculatePostLength (data) {
    const editorJsContentLengthCalculator = new EditorJsContentLengthCalculator(data.blocks)
    return editorJsContentLengthCalculator.length()
  }

  updatePostLengthCounter (length) {
    this.postLengthTarget.textContent = `${length} / ${MAX_SHORT_POST_LENGTH}`
  }

  titleOrSlugPresent () {
    const inputs = this.titleAndSlugTarget.querySelectorAll('input')
    return Array.from(inputs).some(input => input.value.length > 0)
  }

  hide () {
    this.titleAndSlugTarget.classList.add('is-hidden')
  }

  unhide () {
    this.titleAndSlugTarget.classList.remove('is-hidden')
  }
}
