import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['iconInput', 'iconButton', 'nameInput', 'urlInput']

  pickService (event) {
    event.preventDefault()
    const target = event.currentTarget
    const serviceData = JSON.parse(target.dataset.serviceData)

    this.iconInputTarget.value = target.dataset.icon
    this.disableAllButtons()
    target.classList.add('active')

    this.prefillName(serviceData.name)
    this.setUrlPlaceholder(serviceData.url_placeholder)
    this.urlInputTarget.focus()
  }

  prefillName (name) {
    this.nameInputTarget.value = name
  }

  setUrlPlaceholder (url) {
    this.urlInputTarget.placeholder = url
  }

  disableAllButtons () {
    this.iconButtonTargets.forEach((button) => {
      button.classList.remove('is-active')
      button.classList.remove('is-link')
    })
  }
}
