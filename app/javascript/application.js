// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails'
import 'controllers'
import 'bootstrap'

window.addEventListener('turbo:before-stream-render', (event) => {
  const fallbackToDefaultActions = event.detail.render

  event.detail.render = function (streamElement) {
    if (streamElement.action === 'redirect') {
      Turbo.visit(streamElement.getAttribute('location'), { action: 'replace' })
    } else {
      fallbackToDefaultActions(streamElement)
    }
  }
})
